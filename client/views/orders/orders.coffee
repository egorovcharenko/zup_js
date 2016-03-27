#LocalOrders = new Mongo.Collection(null);
# dropdown

Template.ordersList.rendered = ->
  @$('.ui.dropdown').dropdown()
  @$('.ui.checkbox').checkbox()
  Session.setDefault 'StateToLoad', 'Требуется закупка'
  return

deliveryWayArray = {}

Template.ordersList.helpers
  orderHelper: ->
    ret = {}
    ret.sum = @sum.sum / 100
    temp = alasql('SEARCH /WHERE(name="CustomerOrder")//WHERE(uuid="' + @stateUuid + '") FROM ?', [ Workflows ])[0]
    if temp?
      ret.state = temp.name
    try
      aplixStatus = OrderAplixStatuses.findOne(OrderID: @name)
      if aplixStatus?
        ret.aplixState = aplixStatus.Status.Name
    catch ex
      console.log ex
    try
      aplixTrack = OrderTracks.findOne(OrderID: @name)
      if aplixTrack?
        ret.aplixTrack = aplixTrack.Number
    catch ex
      console.log ex
    ret

  orderDeliveryWay: ->
    data = this
    data.sessionVar = "order-" + data.name
    Meteor.call "getMSAttributeValue", data, [{entityName: "CustomerOrder", attrName: "Способ доставки"}], (error, result) ->
      if result
        Session.set(data.sessionVar, result["Способ доставки"].valueString)
    return Session.get(data.sessionVar)

  suppliers: ->
    Companies.find({ tags: $in: [ 'поставщики' ] },
      name: 1
      uuid: 1)
  progress: ->
    toret = {}
    toret.dataPercent = tempCol.findOne('name': 'countAlready').value / tempCol.findOne('name': 'countTotal').value * 100
    toret.countAlready = tempCol.findOne('name': 'countAlready').value
    toret.countTotal = tempCol.findOne('name': 'countTotal').value
    toret
  isActive: ->
    t = tempCol.findOne('name': 'isActive')
    if t
      t.value
    else
      false
  getPathForBuying: ->
    ret = {}
    ret.supplierUuid = Session.get('supplierUuid')
    ret
  selectedCount: ->
    Orders.find(checked: true).count()
Template.ordersList.events
  'click .order-state': (event, template) ->
    Meteor.call 'resetChecked'
    Router.go 'ordersList', orderState: event.target.innerText
    return
  'click .orderSelect': (event, template) ->
    Meteor.call 'toggleChecked', this
    return
  'click .allOrdersSelect': (event, template) ->
    temp = Workflows.findOne(name: 'CustomerOrder')
    if temp
      stateUuid = undefined
      _.every temp.state, (state) ->
        if state?
          if state.name == Router.current().params.orderState
            Meteor.call 'setAllChecked', state.uuid
            return false
        true
    return
  'change #supplierSelector': (event, template) ->
    Router.go 'buyingList', 'supplierUuid': event.target.value
    return
  'click #send-to-aplix': (event, template) ->
    Meteor.call 'sendToAplix'
    return
  'click #packOrder': (event, template) ->
    Router.go 'packOrder', 'orderName': @name
    return
