Template.moderation.events
  'click .option-button': (event, template) ->
    # определить какая кнопка была нажата и какое действие надо выполнить
    optionId = event.target.dataset.optionId
    dataObject = {}
    dataObject.orderName = Router.current().data().order.name
    dataObject.processInsId = Router.current().data().processIns.id
    dataObject.optionId = optionId
    # выполнить действие
    Meteor.call "executeOption", dataObject, (error, result) ->
      if error
        console.log "error", error
      if result
        console.log "ok", error
    return
  'click #set-reserve': (event, template) ->
    Meteor.call "setOrderReserve", Router.current().data().order.uuid, true
  'click #remove-reserve': (event, template) ->
    Meteor.call "setOrderReserve", Router.current().data().order.uuid, false

Template.moderation.helpers
  formatNumber: (num)->
    num.toFixed(2)
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
      ""
  statusHelper: (stateUuid) ->
    wf = Workflows.findOne({code: "CustomerOrder"})
    result = '-'
    if wf?
      _.each wf.state, (state) ->
        if state.uuid is stateUuid
          result = state.name
    return result
  rowSum: () ->
    (Number(@quantity * @price.sum)/100).toFixed(2) + ' р.'
  sumHelper: (sum) ->
    (Number(sum)/100).toFixed(2) + ' р.'
  inStock: ->
    good = Goods.findOne {uuid: @goodUuid}
    if good?
      if good.realAvailableQty?
        good.realAvailableQty >= @quantity
      else
        true
    else
      true
