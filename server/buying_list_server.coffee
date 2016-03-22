Meteor.methods
  calculateBuyingQty: (dataObject) ->
    console.log "Начинаем подсчитывать товары в закупку"
    try
      # сбросить количества на закупку
      Goods.update {}, {$set: {includeInNextBuyingQty: null, ordersForBuy: []}}, multi: true
      # подсчитать кол-ва на закупку заново
      _.each OrderStatuses.find({buyGoodsInThisState: true}).fetch(), (state) ->
        #console.log "start processing state: ", state.name
        orders = Orders.find({stateUuid: state.uuid}).fetch()
        #console.log "found orders:", orders.length
        _.each orders, (order) ->
          #console.log "start processing order: ", order.name
          _.each order.customerOrderPosition, (pos) ->
            #console.log "start processing pos: ", pos.goodUuid
            good = Goods.findOne {uuid: pos.goodUuid}
            if good?
              if not (good.name is "Наложенный платеж")
                if good.includeInNextBuyingQty?
                  oldInclQty = good.includeInNextBuyingQty
                else
                  if good.realAvailableQty?
                    oldInclQty = -good.realAvailableQty
                qtyToOrder = pos.quantity + oldInclQty
                Goods.update {uuid: good.uuid}, {$set: {includeInNextBuyingQty: qtyToOrder}, $push: {ordersForBuy: {name: order.name, state: state.name, qty: pos.quantity}}}
    catch error
      console.log "error:", error
