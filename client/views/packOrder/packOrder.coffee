Template.packOrder.helpers
  absent: ->
    @qty > @stockQty
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
  orderDeliveryWay: ->
    #console.log "orderDeliveryWay"
    data = {}
    data.sessionVar = "order-" + Router.current().params.orderName
    Meteor.call "getMSAttributeValue", Orders.findOne({name: Router.current().params.orderName}), [{entityName: "CustomerOrder", attrName: "Способ доставки"}], (error, result) ->
      if result
        #console.log "result:", result
        temp = result["Способ доставки"]
        if temp?
          Session.set(data.sessionVar,temp.valueString)
      if error
        console.log "error:", error
    return Session.get(data.sessionVar)

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
  'click #orderFinished': (event, template) ->
    try
      console.log "orderFinished"
      attr = [ {
        name: 'Кто собрал'
        value: Meteor.user().profile.msUserId
        type: 'employee'
      }]
      marker = template.find('#markerInput').value
      if marker isnt ""
        console.log "marker isnt empty"
        patt = new RegExp('^[0-9]{6}$')
        if !patt.test(marker)
          FlashMessages.sendError 'В маркере должно быть 6 цифр'
          return
        attr.push {
          name: 'Маркер'
          value: marker
          type: 'string'
        }
      orderUuid = Orders.findOne(name: Router.current().params.orderName).uuid
      # изменить маркер и сборщика
      job = new Job myJobs, 'updateEntityMS', {entityType: 'customerOrder', entityUuid: orderUuid, data: null, attributes: attr}
      job.priority('high')
        .retry({ retries: 2, wait: 1*1000})
        .save()

      # изменить статус на "Заказ собран"
      job = new Job myJobs, 'setEntityStateByUuid', {entityType: 'customerOrder', entityUuid: orderUuid, newStateUuid: "7a657fee-68d0-11e4-7a07-673d00031c07"}
      job.priority('high')
        .retry({ retries: 2, wait: 1*1000})
        .save()

      # отгрузить заказ
      Meteor.call "otgruzitZakaz", orderUuid, (error, result) ->
        if error?
          FlashMessages.sendError "Заказ не отгружен, ошибка: #{error.message}"
          console.log "error:", error
        if result?
          FlashMessages.sendSuccess "Заказ успешно отгружен, результат: #{result.message}"
          console.log "result:", result

      # снять резерв
      Meteor.call "setOrderReserve", orderUuid, false, (error, result) ->
        if error
          FlashMessages.sendError "С заказа не снят резерв, ошибка: #{error.message}"
          console.log "error:", error
        if result
          FlashMessages.sendSuccess "С заказа успешно снят резерв, результат: #{result.message}"
          console.log "result:", result

      Router.go 'ordersList', orderState: 'На сборку'
      console.log "orderFinished finished"
    catch error
      console.log "error:", error
    return
  'click #out-of-stock': (event, template) ->
    Meteor.call 'outOfStockToggle', this
    return
  'click #orderNotFinished': (event, template) ->
    # установить статус "Требуется связаться с клиентом"
    orderUuid = Orders.findOne(name: Router.current().params.orderName).uuid
    job = new Job myJobs, 'setEntityStateByUuid', {entityType: 'customerOrder', entityUuid: orderUuid, newStateUuid: "7c29fdd4-68d0-11e4-7a07-673d00031d3a"}
    job.priority('high')
      .retry({ retries: 5, wait: 1*1000})
      .save()
    # установить отсутствующие товары
    # oos = "";
    # for pos in order.customerOrderPosition
    #   good = Goods.findOne uuid: pos.goodUuid
    #   if good?
    #     if good.outOfStock
    #       oos += "#{good.productCode}  "
    # attr = [ {
    #   name: 'Нет в наличии'
    #   value: oos
    #   type: "string"
    # } ]
    # job = new Job myJobs, 'updateEntityMS', {entityType: 'customerOrder', entityUuid: order.uuid, data: null, attributes: attr}
    # job.priority('high')
    #   .retry({ retries: 5, wait: 30*1000})
    #   .save()
    Router.go 'ordersList', orderState: 'На сборку'
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
