#LocalOrders = new Mongo.Collection(null);
# dropdown

Template.managers.rendered = ->
  @$('.ui.dropdown').dropdown()
  @$('.ui.checkbox').checkbox()
  Session.setDefault 'StateToLoad', 'Требуется закупка'
  return

deliveryWayArray = {}

Template.managers.helpers
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
    # тайминг
    startTime = @created
    now = reactiveDate.now()
    if startTime?
      minutesElapsed = Math.floor((now - startTime) / (1000*60))
    ret.timeInModeration = minutesElapsed + " минут"
    ret
Template.managers.events
  'click #moderateOrder': (event, template) ->
    # запустить процесс модерации
    Meteor.call 'startProcess', "Модерация", {"orderNumber": @name}

    # открыть страницу модерации заказов
    Router.go 'moderation', 'orderName': @name
    return
  'click #openOrder': (event, template) ->
    # открыть страницу модерации заказов
    Router.go 'moderation', 'orderName': @name
    return
