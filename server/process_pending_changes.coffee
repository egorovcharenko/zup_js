Meteor.methods
  startProcessingChanges: (orderUuid, pendingChanges) ->
    Orders.update {uuid: orderUuid}, {$set: {pendingChanges: pendingChanges}}

  processPendingChanges: ->
    # найти все заказы с необработанными изменениями
    _.each Orders.find({pendingChanges: {$exists: true}}).fetch(), (order) ->
      try
        console.log "Заказ с необработанными изменениями: #{order.name}"
        # сбросить сообщение
        Orders.update {uuid: order.uuid}, {$set: {processingResult: "Обрабатывается..."}}
        processingResult = ""
        error = false
        # пройтись по всем изменениям
        _.each order.pendingChanges, (change) ->
          console.log "change: #{change.type}, #{change.value}"
          Meteor._sleepForMs(300); # delay
          # выполнить действие
          switch change.type
            when "changeAttributes"
              result = Meteor.call 'updateEntityMS', 'customerOrder', order.uuid, null, change.value
            when "setState"
              result = Meteor.call 'setEntityStateByUuid', 'customerOrder', order.uuid, change.value
            when "otgruzitZakaz"
              try
                result = Meteor.call 'otgruzitZakaz', order.uuid
              catch error
                processingResult +=  "Ошибка в отгрузке, требуется отгрузить вручную: " + error.message + "<br/>"
            when "setOrderReserve"
              result = Meteor.call 'setOrderReserve', order.uuid, change.value
        # удалить массив и обновить сообщение
        processingResult += "Заказ обработан, собирайте следующий"
        Orders.update {uuid: order.uuid}, {$unset: {pendingChanges: ""}, $set: {processingResult: processingResult}}
      catch error
        console.log "Ошибка при обработке изменений:", error
        processingResult += "Ошибка при обработке заказа, попробуйте заново (?): #{error.toString()}"
        Orders.update {uuid: order.uuid}, {$unset: {pendingChanges: ""}, $set: {processingResult: processingResult}}
    return
