extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

Meteor.methods
  startProcess: (processName, params) ->
    console.log "Запускаем новый процесс: ", processName

    # считать файлы
    processesJson = JSON.parse(Assets.getText("processes.json"));

    # найти процесс
    processTemplate = processesJson.processes.filter((x) -> x.name == processName)[0]
    #console.log "processTemplate: ", processTemplate

    # создать процесс
    newProcessIns = processTemplate
    newProcessIns.createdDate = Date.now()
    newProcessIns.createdByUser = Meteor.user()
    newProcessIns.id = uuid.v4()
    newProcessIns.params = params
    newProcessIns.status = "active"
    #console.log "newProcessIns: ", newProcessIns

    _.each newProcessIns.steps, (step) ->
      if not step.id?
        step.id = uuid.v4()
      _.each step.options, (option) ->
        if not option.id?
          option.id = uuid.v4()

    #console.log "newProcessIns: ", newProcessIns

    # записать новый экземплятр процесса в БД
    ProcessesIns.insert newProcessIns

    return

  executeOption: (dataObject) ->
    #console.log "executeOption dataObject ", dataObject

    # пройтись по очереди все действия
    processIns = ProcessesIns.findOne {id: dataObject.processInsId}
    #console.log "processIns ", processIns

    dataObject.msUserId =  Meteor.user().profile.msUserId
    dataObject.userName = Meteor.user().profile.userName

    if processIns?
      _.each processIns.steps, (step) ->
        _.each step.options, (option) ->
          if option.id == dataObject.optionId
            # выполнить каждое действие
            _.each option.actions, (action) ->
              # заменить параметры на то что есть
              for k2,v2 of dataObject
                for k,v of action.params
                  #console.log "k:", k, " ,v:", v, ", k2:", k2, ", v2:", v2, ", replace result: ", v.replace("%#{k2}%", v2)
                  action.params[k] = v.replace "%#{k2}%", v2
              #console.log "action ", action
              # выполнить действие
              switch action.name
                when "finishProcess"
                  console.log "Завершаем процесс с id=#{dataObject.processInsId}, название=#{processIns.name}"
                  ProcessesIns.update {
                    id: dataObject.processInsId
                  }, {$set: {
                    status: "finished"
                  }}

                # DONE
                when "setOrderField"
                  orderName = dataObject.orderName
                  fieldName = action.params.fieldName
                  fieldValue = action.params.fieldValue
                  fieldType = action.params.fieldType
                  console.log "Устанавливаем у заказа #{orderName} параметр #{fieldName} в значение #{fieldValue}"
                  attr = [ {
                    name: fieldName
                    value: fieldValue
                    type: fieldType
                  } ]
                  orderUuid = Orders.findOne(name: orderName).uuid
                  Meteor.call "updateEntityMS", 'customerOrder', orderUuid, null, attr

                when "log"
                  logEntry = {
                    "date": Date.now()
                    "userName": dataObject.userName
                  }
                  logEntry = extend logEntry, action.params
                  #console.log "Пишем в лог: ", logEntry
                  Log.insert logEntry

                when "setAction"
                  try
                    orderName = dataObject.orderName
                    actionType = action.params.type
                    console.log "Начинаем добавлять действие в заказ #{orderName}"
                    Orders.update {name: orderName}, {$push: {actions:{date: new Date(), type: actionType}}}
                  catch error
                    console.log "error:", error

                when "setOrderStatus"
                  orderName = action.params.orderName
                  orderStatusUuid = action.params.newOrderStatusUuid
                  console.log "нужно у заказа #{orderName} заменить статус на #{orderStatusUuid}"
                  orderUuid = Orders.findOne(name: orderName).uuid
                  #console.log "orderUuid: #{orderUuid}"
                  job = new Job myJobs, 'setEntityStateByUuid', {entityType: 'customerOrder', entityUuid: orderUuid, newStateUuid: orderStatusUuid}
                  job.priority('high')
                    .retry({ retries: 5, wait: 1*1000})
                    .save()

                # TODO
                when "startNewProcess"
                  processName = action.params.processName
                  processParams = action.params.processParams
                  console.log "Запускаем новый процесс: #{processName} с параметрами: #{processParams}"

                # TODO
                when "reserveOrder"
                  orderName = action.params.orderName
                  console.log "нужно у заказа #{orderName} зарезервировать товар";

                # TODO
                when "addSkuToOrder"
                  orderName = action.params.orderName
                  sku = action.params.sku
                  console.log "нужно в заказе #{orderName} добавить товар #{sku}";

                when "addNalogenPayment"
                  orderName = action.params.orderName
                  console.log "Добавляем к #{orderName} наложенный платеж"
                  Meteor.call "addNalogenPaymentMethod", orderName, (error, result) ->
                    if error
                      console.log "error", error
                    if result
                      ;

                when "setReserve"
                  orderName = action.params.orderName
                  console.log "нужно в заказе #{orderName} поставить весь товар в резерв";
                  order = Orders.findOne(name: orderName)
                  Meteor.call "setOrderReserve", order.uuid, true, (error, result) ->
                    if error
                      console.log "error", error
                    if result
                      ;

                when "setOrderNeededState"
                  # проходимся по всем товарам
                  orderName = action.params.orderName
                  console.log "нужно в заказе #{orderName} проставить нужный статус в зависимости от наличия";
                  # загружаем так чтобы точно уж получить нормальные последние данные

                  order = client.load('customerOrder', Orders.findOne(name: orderName).uuid)

                  #console.log "Нашли заказ: #{order}"
                  needToBuy = false
                  _.each order.customerOrderPosition, (pos) ->
                    good = Goods.findOne {uuid: pos.goodUuid}
                    if good?
                      if good.realAvailableQty < pos.quantity
                        needToBuy = true
                  if needToBuy
                    # если чего-то нет, то выставляем "Требуется закупка"
                    console.log "Выставляем статус Требуется закупка"
                    result = Meteor.call "setEntityStateByUuid", "customerOrder", order.uuid, "7f224366-68d0-11e4-7a07-673d0003202a"
                  else
                    # если это самовывоз или достависта - выставляем "Пока не собирать"
                    attrib = _.find(order.attribute, (attr) -> attr.metadataUuid is "50836a82-6912-11e4-90a2-8ecb00526879")
                    newState = "ba02cb40-691b-11e4-90a2-8ecb0052ff42" # на сборку
                    if attrib?
                      #console.log "attrib:", attrib
                      if (attrib.entityValueUuid is "07242d1a-691b-11e4-90a2-8ecb0052fa9f") or (attrib.entityValueUuid is "c596ace1-7991-11e4-90a2-8eca00151dc4")
                        newState = "265f289e-ca46-11e5-7a69-971100039a24" # пока не собирать
                    console.log "Устанавливаем статус:#{newState}"
                    result = Meteor.call "setEntityStateByUuid", "customerOrder", order.uuid, newState
                  #console.log "result:", result

                when "setNextStep"
                  # найти следующий шаг
                  console.log "Переходим к действию #{action.params.nextStepId}"
                  _.each processIns.steps, (step2) ->
                    #console.log "#{step2.id}", "#{action.params.nextStepId}"
                    if "#{step2.id}" == "#{action.params.nextStepId}"
                      ProcessesIns.update {
                        id: dataObject.processInsId,
                        "steps.id": step2.id
                      }, {$set: {
                        "steps.$.status": "active"
                      }}
                      ProcessesIns.update {
                        id: dataObject.processInsId,
                        "steps.id": step.id
                      }, {$set: {
                        "steps.$.status": "passed"
                      }}
                      #console.log "done!"
