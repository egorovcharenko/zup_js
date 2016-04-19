Meteor.methods
  startProcessingChanges: (orderUuid, pendingChanges) ->
    console.log "Ставим в очередь обработку для заказа #{orderUuid} изменения: #{pendingChanges}"
    Orders.update {uuid: orderUuid}, {$push: {pendingChanges: {$each: pendingChanges}}}

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
          console.log "change: #{JSON.stringify(change,null,2)}"
          #console.log "change: #{change.type}, #{change.value}"
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
            when "setOrderNeededState"
              console.log "Вошли в ветку setOrderNeededState"
              freshOrder = client.load('customerOrder', order.uuid)
              console.log "Загрузили свежий заказ"
              needToBuy = false
              if freshOrder.customerOrderPosition?
                _.each freshOrder.customerOrderPosition, (pos) ->
                  good = Goods.findOne {uuid: pos.goodUuid}
                  if good?
                    if good.realAvailableQty < pos.quantity
                      needToBuy = true
              if needToBuy
                # если чего-то нет, то выставляем "Требуется закупка"
                newState = "7f224366-68d0-11e4-7a07-673d0003202a" # "Требуется закупка"
              else
                # если это самовывоз или достависта - выставляем "Пока не собирать"
                attrib = _.find(freshOrder.attribute, (attr) -> attr.metadataUuid is "50836a82-6912-11e4-90a2-8ecb00526879")
                newState = "ba02cb40-691b-11e4-90a2-8ecb0052ff42" # на сборку
                if attrib?
                  if (attrib.entityValueUuid is "07242d1a-691b-11e4-90a2-8ecb0052fa9f") or (attrib.entityValueUuid is "c596ace1-7991-11e4-90a2-8eca00151dc4")
                    newState = "265f289e-ca46-11e5-7a69-971100039a24" # пока не собирать
              console.log "выставляем статус"
              freshOrder.stateUuid = newState
              saveResult = client.save(freshOrder)
              #Meteor.call 'setEntityStateByUuid', 'customerOrder', order.uuid, newState
              console.log "Успешно выставили статус, результат:", saveResult
        # удалить массив и обновить сообщение
        processingResult += "Заказ обработан, собирайте следующий"
      catch error
        console.log "Ошибка при обработке изменений:", error
        processingResult += "Ошибка при обработке заказа, попробуйте заново (?): #{error.toString()}"
      finally
        Orders.update {uuid: order.uuid}, {$unset: {pendingChanges: ""}, $set: {processingResult: processingResult}}
    return
