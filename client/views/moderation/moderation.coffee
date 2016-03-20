Template.moderation.events
  'click .option-button': (event, template) ->
    # определить какая кнопка была нажата и какое действие надо выполнить
    optionId = event.target.dataset.optionId

    #console.log "optionId ", optionId
    #console.log "data ", Router.current().data()
    dataObject = {}
    dataObject.orderName = Router.current().data().order.name
    dataObject.processInsId = Router.current().data().processIns.id
    dataObject.optionId = optionId

    #console.log "dataObject ", dataObject

    # выполнить действие
    #dataObject.orderName =
    Meteor.call "executeOption", dataObject, (error, result) ->
      if error
        console.log "error", error
      if result
        console.log "ok", error

    return
Template.moderation.helpers
  orderPosHelper: ->
    # название товара
    good = Goods.findOne {uuid: @goodUuid}
    good
    #JSON.stringify(good, null, 4)
  sumHelper: (sum) ->
    Number(sum)/100 + ' р.'
  inStock: ->
    good = Goods.findOne {uuid: @goodUuid}
    if good?
      if good.quantityQty?
        console.log "inStock: ", good.quantityQty, @quantity
        good.quantityQty >= @quantity
      else
        true
    else
      true
