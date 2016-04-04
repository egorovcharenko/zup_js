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
  customerCurrentTime: ()->
    reactiveDate = new ReactiveVar(new Date())
    #console.log "this:", this
    if this.company?
      if this.company.dadata?
        if this.company.dadata.timezone?
          console.log "#{this.company.dadata.timezone.substring(3)}"
          return moment(reactiveDate.get()).utcOffset(parseInt(this.company.dadata.timezone.substring(3))).format('HH:mm')
    return moment(reactiveDate.get()).format('HH:mm')
  nextArrivalDate: ()->
    good = Goods.findOne {uuid: @goodUuid}
    if good?
      if good.outOfStockInSupplier?
        if good.outOfStockInSupplier
          return "Отсутствует у поставщика"
      return moment(good.nextDate).format("DD.MM.YYYY")
    else
      return "-"
  formatNumber: (num)->
    num.toFixed(2)
  orderPosHelper: ->
    # название товара/услуги
    good = Goods.findOne {uuid: @goodUuid}
    if good?
      good.realAvailableQtyPlusReserve = good.realAvailableQty + @reserve
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
        good.realAvailableQty + @reserve >= @quantity
      else
        true
    else
      true
