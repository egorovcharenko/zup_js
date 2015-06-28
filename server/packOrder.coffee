Meteor.methods
  addPackedQty: (orderName, posUuid, qty) ->
    #var position = alasql('SEARCH /WHERE(name = "' + orderName + '")//WHERE(uuid="' + posUuid + '") FROM ?', [Orders]);
    #var position = alasql('SELECT * FROM ? WHERE name = "100000852"', [Orders, posUuid]);
    positions = Orders.findOne(
      name: orderName
      'customerOrderPosition.uuid': posUuid).customerOrderPosition
    packedQtyCurrent = _.find(positions, (position) ->
      position.uuid == posUuid
    ).packedQty
    newQty = undefined
    if packedQtyCurrent
      newQty = Math.max(0, packedQtyCurrent + qty)
    else
      newQty = Math.max(0, qty)
    Orders.update {
      name: orderName
      'customerOrderPosition.uuid': posUuid
    }, $set: 'customerOrderPosition.$.packedQty': newQty
    return
  outOfStockToggle: (pos) ->
    Goods.update {uuid:pos.goodUuid}, {$set: {outOfStock: !pos.outOfStock}}
    return
