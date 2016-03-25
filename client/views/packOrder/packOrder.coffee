Template.packOrder.helpers
  isQtyMoreThan1: ->
    @qty > 1
  isAnyPosSelected: ->
    Router.current().params.orderPosSelected?
  isPosSelected: ->
    Router.current().params.orderPosSelected == @uuid
  isAllPacked: ->
    @qty == @packedQty
  goodDetails: ->
    temp = _.find(@customerOrderPositionsModified, (pos) ->
      pos.uuid == Router.current().params.orderPosSelected
    )
    temp
  states: ->
    (state for state in (Workflows.findOne name: "CustomerOrder").state when state.name in ["На сборку", "Заказ собран", "Требуется связаться с клиентом"])

Template.packOrder.events
  'click #goBack': (event, template) ->
    Router.go 'ordersList', orderState: 'На сборку'
    return
  'click #show-more': (event, template) ->
    Router.go 'packOrder',
      orderName: Router.current().params.orderName
      orderPosSelected: @uuid
    return
  'click #plus-qty': (event, template) ->
    Meteor.call 'addPackedQty', Router.current().params.orderName, @uuid, 1
    return
  'click #minus-qty': (event, template) ->
    Meteor.call 'addPackedQty', Router.current().params.orderName, @uuid, -1
    return
  'click #add_marker': (event, template) ->
    marker = template.find('#markerInput').value
    console.log "Маркер: #{marker}"
    patt = new RegExp('^[0-9]{6}$')
    if !patt.test(marker)
      FlashMessages.sendError 'В маркере должно быть 6 цифр'
    else
      attr = [ {
        name: 'Маркер'
        value: marker
      } ]

      orderUuid = Orders.findOne(name: Router.current().params.orderName).uuid

      job = new Job myJobs, 'updateEntityMS', {entityType: 'customerOrder', entityUuid: orderUuid, data: null, attributes: attr, attributeType:'string'}

      job.priority('high')
        .retry({ retries: 5, wait: 1*1000})
        .save()

    return
  'click #out-of-stock': (event, template) ->
    Meteor.call 'outOfStockToggle', this
    return
  'click #setState': (event, template) ->
    newOrderState = template.find("#realStateSelector").value
    orderUuid = Orders.findOne(name: Router.current().params.orderName).uuid
    job = new Job myJobs, 'setEntityStateByUuid', {entityType: 'customerOrder', entityUuid: orderUuid, newStateUuid: newOrderState}
    job.priority('high')
      .retry({ retries: 5, wait: 1*1000})
      .save()
    return
  'click #setOutOfStockField': (event, template) ->
    order = Orders.findOne(name: Router.current().params.orderName);
    oos = "";
    for pos in order.customerOrderPosition
      good = Goods.findOne uuid: pos.goodUuid
      if good?
        if good.outOfStock
          oos += "#{good.productCode}  "
    attr = [ {
      name: 'Нет в наличии'
      value: oos
    } ]
    job = new Job myJobs, 'updateEntityMS', {entityType: 'customerOrder', entityUuid: order.uuid, data: null, attributes: attr, attributeType: 'string'}
    job.priority('high')
      .retry({ retries: 5, wait: 30*1000})
      .save()
    return

  'click #otgruzit': (event, template) ->
    order = Orders.findOne(name: Router.current().params.orderName);
    Meteor.call "otgruzitZakaz", order.uuid, (error, result) ->
      if error?
        console.log "error:", error
        FlashMessages.sendError error
      if result?
        console.log "result:", result
        FlashMessages.sendSuccess result
    # снять резерв
    Meteor.call "setOrderReserve", order.uuid, false, (error, result) ->
      if error
        console.log "error:", error
        FlashMessages.sendError error
      if result
        console.log "result:", result
        FlashMessages.sendSuccess result


Template.packOrder.onRendered = ->
  $('.ui.sticky').sticky content: '#positions-list'
  return

Template.packOrder.rendered = ->
  $('.ui.checkbox').checkbox()
  $('.ui.dropdown').dropdown()
  return
