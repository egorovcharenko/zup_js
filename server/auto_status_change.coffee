Meteor.methods
  autoStatusChange: ->
    console.log "Начинаем обработку заказов в статусах Недозвон и Ожид. поступ."
    # недозвоны - больше 7 дней после заказа - в Заморожены
    _.each Orders.find({stateUuid: "7a739cd4-68d0-11e4-7a07-673d00031c1d"}).fetch(), (order) ->
      try
        if moment(order.created).isBefore(moment().subtract(7,'days'))
          console.log "Переводим заказ #{order.name} в заморожены"
          Meteor.call "setEntityStateByUuid", "customerOrder", order.uuid, "6d26d5eb-68d0-11e4-7a07-673d00030c86"
      catch error
        console.log "Ошибка при сбрасывании статуса заказа:", error.message
    # Ожидание поступления - при наличии всех товаров - перевод в "На сборку", а если после последней закупки поставщика товаров до сих пор нет - треб связь
    _.each Orders.find({stateUuid: "86f22ef9-f894-11e4-7a40-e89700160cb9"}).fetch(), (order) ->
      try
        console.log "Начинаем обработку ожидания поступления заказа #{order.name}"
        allAvailable = true
        # найти все недостающие товары в заказе
        _.each order.customerOrderPosition, (pos) ->
          good = Goods.findOne {uuid: pos.goodUuid}
          if good?
            if good.realAvailableQty?
              if (good.realAvailableQty + pos.reserve) <= pos.quantity
                allAvailable = false
                console.log "Товар #{good.name} - не в наличии. доступно #{(good.realAvailableQty + pos.reserve)}, а нужно #{pos.quantity}"
        if allAvailable
          # если самовывоз или достависта - поставить на "Треб связь чтобы сказать клиенту что товар пришел"
          console.log "Все в наличии, Переводим заказ #{order.name} на сборку"
          newState = "ba02cb40-691b-11e4-90a2-8ecb0052ff42" # на сборку
          attrib = _.find(order.attribute, (attr) -> attr.metadataUuid is "50836a82-6912-11e4-90a2-8ecb00526879")
          if attrib?
            if (attrib.entityValueUuid is "07242d1a-691b-11e4-90a2-8ecb0052fa9f") or (attrib.entityValueUuid is "c596ace1-7991-11e4-90a2-8eca00151dc4")
              console.log "Переводим заказ #{order.name} в треб. связь"
              newState = "7c29fdd4-68d0-11e4-7a07-673d00031d3a" # треб связь
          Meteor.call "setEntityStateByUuid", "customerOrder", order.uuid, newState
      catch error
        console.log "Ошибка:", error.message
    console.log "Закончили обработку заказов в статусах Недозвон и Ожид. поступ."
