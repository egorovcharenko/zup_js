Meteor.methods
  startProcess: (processName, params) ->
    console.log "processName: ", processName

    # считать файлы
    processesJson = JSON.parse(Assets.getText("processes.json"));

    # найти процесс
    processTemplate = processesJson.processes.filter((x) -> x.name == processName)[0]
    console.log "processTemplate: ", processTemplate

    # создать процесс
    newProcessIns = processTemplate
    newProcessIns.createdDate = Date.now()
    newProcessIns.createdByUser = Meteor.user()
    newProcessIns.id = uuid.v4()
    newProcessIns.params = params
    newProcessIns.status = "active"
    console.log "newProcessIns: ", newProcessIns

    _.each newProcessIns.steps, (step) ->
      if not step.id?
        step.id = uuid.v4()
      _.each step.options, (option) ->
        if not option.id?
          option.id = uuid.v4()

    console.log "newProcessIns: ", newProcessIns

    # записать новый экземплятр процесса в БД
    ProcessesIns.insert newProcessIns

    return

  executeOption: (dataObject) ->
    console.log "executeOption dataObject ", dataObject

    # пройтись по очереди все действия
    processIns = ProcessesIns.findOne {id: dataObject.processInsId}
    #console.log "processIns ", processIns

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
              console.log "action ", action
              # выполнить действие
              switch action.name
                when "finishProcess"
                  console.log "Завершаем процесс с id=#{dataObject.processInsId}, название=#{processIns.name}"
                  ProcessesIns.update {
                    id: dataObject.processInsId
                  }, {$set: {
                    status: "finished"
                  }}

                # TODO
                when "setOrderField"
                  orderName = dataObject.orderName
                  fieldName = action.params.fieldName
                  fieldValue = action.params.fieldValue
                  fieldType = action.params.fieldType
                  console.log "Устанавливаем у заказа #{orderName} параметр #{fieldName} в значение #{fieldValue}"

                  attr = [ {
                    name: fieldName
                    value: fieldValue
                  } ]

                  orderUuid = Orders.findOne(name: orderName).uuid

                  job = new Job myJobs, 'updateEntityMS', {entityType: 'customerOrder', entityUuid: orderUuid, data: null, attributes: attr, attributeType: fieldType}

                  job.priority('high')
                    .retry({ retries: 5, wait: 1*1000})
                    .save()

                # TODO
                when "startNewProcess"
                  processName = action.params.processName
                  processParams = action.params.processParams
                  console.log "Запускаем новый процесс: #{processName} с параметрами: #{processParams}"

                # TODO
                when "log"
                  console.log "Пишем в лог"

                # TODO
                when "reserveOrder"
                  orderName = action.params.orderName
                  console.log "нужно у заказа #{orderName} зарезервировать товар";

                # TODO
                when "addSkuToOrder"
                  orderName = action.params.orderName
                  sku = action.params.sku
                  console.log "нужно в заказе #{orderName} добавить товар #{sku}";

                # TODO
                when "setOrderStatus"
                  orderName = action.params.orderName
                  orderStatus = action.params.newStatus
                  console.log "нужно у заказа #{orderName} заменить статус на #{orderStatus}";

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
