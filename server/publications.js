Meteor.publish('orders', function() {
  return orders.find();
});

Meteor.publish('goods', function() {
  return Goods.find();
});

Meteor.publish('companies', function() {
  return Companies.find();
});

Meteor.publish('tempCol', function() {
  return tempCol.find();
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
