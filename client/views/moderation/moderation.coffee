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
    # название товара/услуги
    good = Goods.findOne {uuid: @goodUuid}
    if good?
      return good
    else
      return Services.findOne {uuid: @goodUuid}
  booleanYesNo: (val) ->
    if val
      "Да"
    else
      "Нет"
  statusHelper: (stateUuid) ->
    wf = Workflows.findOne({code: "CustomerOrder"})
    result = '-'
    if wf?
      _.each wf.state, (state) ->
        if state.uuid is stateUuid
          result = state.name
    return result
  rowSum: () ->
    Number(@quantity * @price.sum)/100 + ' р.'
  sumHelper: (sum) ->
    Number(sum)/100 + ' р.'
  inStock: ->
    good = Goods.findOne {uuid: @goodUuid}
    if good?
      if good.realAvailableQty?
        good.realAvailableQty >= @quantity
      else
        true
    else
      true
