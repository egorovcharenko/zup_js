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

    if not processTemplate?
      console.log "Не нашли процесс #{processName}"
      return

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

    pendingChanges = []

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
                  pendingChanges.push {
                    type: "changeAttributes"
                    value: attr
                  }

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
                  pendingChanges.push {
                    type: "setState"
                    value: orderStatusUuid
                  }

                # TODO
                when "startNewProcess"
                  processName = action.params.processName
                  processParams = action.params.processParams
                  console.log "Запускаем новый процесс: #{processName} с параметрами: #{processParams}"

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
                  pendingChanges.push {
                    type: "setOrderReserve"
                    value: true
                  }

                when "setOrderNeededState"
                  # проходимся по всем товарам
                  orderName = action.params.orderName
                  console.log "нужно в заказе #{orderName} проставить нужный статус в зависимости от наличия";
                  pendingChanges.push {
                    type: "setOrderNeededState"
                  }

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
    if pendingChanges.length > 0
      #console.log "Начинаем применять к заказу изменения"
      order = Orders.findOne(name: dataObject.orderName)
      if order?
        Meteor.call "startProcessingChanges", order.uuid, pendingChanges
