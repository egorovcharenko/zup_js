# Meteor.publish "wholeLog", (args) ->
#   return Log.find {}
ReactiveTable.publish("all_goods_special_publish", Goods);

ReactiveTable.publish("log_special_publish", Log);

ReactiveTable.publish("order_statuses_special_publish", OrderStatuses);

ReactiveTable.publish("goods_special_publish", Goods, {$or: [{includeInNextBuyingQty: {$gt: 0}}, {perWeekQtyNeeded: {$gt: 0}}]});

ReactiveTable.publish("system_log_special_publish", SystemLog);

ReactiveTable.publish("orders_special_publish", Orders, $or:
  [
    {stateUuid: '3f201baf-8d32-11e4-7a07-673d00307946'},
    {stateUuid: '33cd998e-3090-11e5-7a07-673d0019b9ed'},
    {stateUuid: '5753d0b0-a6fb-11e4-90a2-8ecb0011be7f'},
    {stateUuid: '731abfcd-aa2d-11e4-7a07-673d001484ff'},
    {stateUuid: '7a739cd4-68d0-11e4-7a07-673d00031c1d'},
    {stateUuid: '7c29fdd4-68d0-11e4-7a07-673d00031d3a'},
    {stateUuid: 'abcf2f44-73c6-11e4-90a2-8ecb001ed0f3'},
    {stateUuid: 'b189a90a-304f-11e5-7a07-673d00256353'},
    {stateUuid: 'e7d700fd-4a8e-11e5-7a40-e8970020ae51'}
    ]);

ReactiveTable.publish("status_history_special_publish", StatusHistory);

Meteor.publish "orderRules", () ->
  return OrderRules.find {}

Meteor.publish "employees", () ->
  return Employees.find {}

Meteor.publish "ordersForModeration", () ->
  return [
    Orders.find {name: 'С10791'}
  ]
  return [
    Orders.find {$or: [{stateUuid: '3f201baf-8d32-11e4-7a07-673d00307946'}, {stateUuid: '33cd998e-3090-11e5-7a07-673d0019b9ed'}]}
  ]
Meteor.publish "moderation", (orderName) ->
  return [
    Orders.find {name: orderName}
    ProcessesIns.find({"params.orderNumber": orderName, status: "active"})
  ]
Meteor.publishComposite "orderWithGoodsAndCompany", (orderName) ->
  {
    find: ->
      Orders.find(name: orderName)
    children:
      [
        {
          find: (order) ->
            temp = []
            _.each order.customerOrderPosition, (pos) ->
              temp.push pos.goodUuid
              return
            Services.find uuid: $in: temp
        }, {
          find: (order) ->
            temp = []
            _.each order.customerOrderPosition, (pos) ->
              temp.push pos.goodUuid
              return
            Goods.find uuid: $in: temp
        }, {
          find: (order) ->
            Companies.find {uuid: order.sourceAgentUuid}
        }
      ]
  }

Meteor.publish 'allOrders', ->
  Orders.find {}
Meteor.publish 'checkedOrders', ->
  Orders.find checked: true
Meteor.publish 'allGoods', ->
  Goods.find {}
Meteor.publish 'dataTimestamps', ->
  DataTimestamps.find {}
Meteor.publish 'allSuppliersSub', ->
  Companies.find { tags: $in: [ 'поставщики' ] }, fields:
    uuid: 1
    name: 1
    tags: 1
Meteor.publish 'tempCol', ->
  tempCol.find()
Meteor.publish 'workflows', ->
  Workflows.find {},
    name: 1
    state: 1
Meteor.publish 'ordersWithState', (orderState) ->
  temp = Workflows.findOne(name: 'CustomerOrder')
  if temp
    result = undefined
    _.every temp.state, (state) ->
      if state.name == orderState
        result = Orders.find(stateUuid: state.uuid)
        return false
      true
  result
Meteor.publishComposite 'ordersWithStateAndAplix', (orderState) ->
  {
    find: ->
      orderStateUuid = alasql('SEARCH /WHERE(name="CustomerOrder")//WHERE(name="' + orderState + '") FROM ?', [ Workflows ])[0].uuid
      Orders.find(stateUuid: orderStateUuid, {customerOrderPosition: false})
    children:
      [
        # {
        #   find: (order) ->
        #     OrderAplixStatuses.find OrderID: order.name
        # }
        # {
        #   find: (order) ->
        #     OrderTracks.find OrderID: order.name
        # }
        # {
        #   find:(order) ->
        #     Companies.find uuid: order.sourceAgentUuid
        # }
      ]
  }
Meteor.publishComposite 'buyingListPub',
  find: ->
    Orders.find checked: true
  children: [ {
    find: (order) ->
      temp = []
      _.each order.customerOrderPosition, (pos) ->
        temp.push pos.goodUuid
        return
      Goods.find uuid: $in: temp
    children: [ { find: (good, order) ->
      Companies.find uuid: good.supplierUuid
 } ]
  } ]
Meteor.publishComposite 'packOrderPub', (orderName) ->
  {
    find: ->
      Orders.find name: orderName
    children:
      [
        {
          find: (order) ->
            temp = []
            _.each order.customerOrderPosition, (pos) ->
              temp.push pos.goodUuid
              return
            Goods.find uuid: $in: temp
          children:
            [
              {
                find: (good, order) ->
                  GoodsImages.find sku: good.productCode
              }
            ]
        }
      ]
  }

Meteor.publish 'allJobs', ->
  myJobs.find {}

Meteor.publish 'notCompletedJobs', ->
  myJobs.find {status: {$ne: "completed"}}

Meteor.publish 'last200jobs', ->
  myJobs.find({}, {sort:{updated:-1}, limit: 250})
