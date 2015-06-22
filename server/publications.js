Meteor.publish('allOrders', function() {
  return orders.find({});
});

Meteor.publish('checkedOrders', function() {
  return orders.find({checked:true});
});

Meteor.publish('allGoods', function() {
  return Goods.find({});
});

Meteor.publish('allSuppliersSub', function() {
  return Companies.find({tags: {$in: ["поставщики"]}}, {fields: {uuid:1, name:1, tags:1}});
});

Meteor.publish('tempCol', function() {
  return tempCol.find();
});

Meteor.publish('workflows', function() {
  return Workflows.find({}, {name:1, state:1});
});

// Server
Meteor.publishComposite('buyingListPub', {
    find: function() {
        return orders.find({checked:true});
    },
    children: [
        {
            find: function(order) {
              var temp = [];
              _.each(order.customerOrderPosition, function (pos) {
                temp.push(pos.goodUuid);
              })
              return Goods.find({uuid: {$in: temp}});
            },
            children: [
                {
                    find: function(good, order) {
                        return Companies.find(
                            { uuid: good.supplierUuid });
                    }
                }
            ]
        }
    ]
});
// Server
/*
Meteor.publishComposite('ordersWPosWGoodsWSuppliers', {
    find: function() {
        return orders.find({}, { sort: { created: -1 }});
    },
    children: [
        {
            find: function(order) {
                // Find post author. Even though we only want to return
                // one record here, we use "find" instead of "findOne"
                // since this function should return a cursor.
                return order.customerOrderPosition.find();
            },
            children: [
              {
                find: function (position, order) {
                  return Goods.find({uuid: position.goodUuid});
                },
                children: [
                  {
                    find: function (good, position, order) {
                      return Companies.find({uuid: good.supplierUuid})
                    }
                  }
                ]
              }
            ]
        }
    ]
});
*/
