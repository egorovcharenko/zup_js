Meteor.methods({
  loadOrdersFromMS: function (stateToLoad) {
    check(arguments, [Match.Any]);
    var moyskladPackage = Meteor.npmRequire('moysklad-client');
    // var output;
    // for (var property in moyskladPackage) {
    //   output += property + ': ' + moyskladPackage[property]+'; ';
    // }
    // Meteor._debug("moyskladPackage: " + output);

    var response = Async.runSync(function(done) {
      var toReturn = [];
      var countTotal = 0;
      var countAlready = 0;

      var client = moyskladPackage.createClient();
      client.setAuth('admin@allshellac', 'qweasd');

      var query = moyskladPackage.createQuery();

      var maxCountToLoad = 50;
      var pageSize = 5;
      var ordersFromMs;

      var totalQuery = moyskladPackage.createQuery().select(stateToLoad);
      var totalOrders = client.total('customerOrder', totalQuery);
      tempCol.upsert({"name": "countTotal"}, {$set: {"value": totalOrders}});
      tempCol.upsert({"name": "isActive"}, {$set: {"value": true}});

      do {
        query.select(stateToLoad).count(pageSize).start(countAlready);
        ordersFromMs = client.load('customerOrder', query);
        _.each(ordersFromMs, function (order) {
          order.sum.sum /= 100;
          // Создание ленивого загрузчика
          var lazyLoader = client.createLazyLoader();
          // Привязка ленивого загрузчика к заказу
          lazyLoader.attach(order);

          order._state = order.state.name;
          //toReturn.push(order);

          if (orders.find({name: order.name}).count() > 0) {
            orders.remove({name: order.name});
          }
          orders.insert(order);

          });

        countAlready += ordersFromMs.length;

        tempCol.upsert({"name": "countAlready"}, {$set: {"value": countAlready}});
      } while ((countAlready < maxCountToLoad) && (ordersFromMs.length > 0))

      tempCol.upsert({"name": "countTotal"}, {$set: {"value": 10}});
      tempCol.upsert({"name": "countAlready"}, {$set: {"value": 0}});
      tempCol.upsert({"name": "isActive"}, {$set: {"value": false}});
      //console.log(toReturn);
      done(null, toReturn);

      //return toReturn;

    });
    //console.log(response.result);
    return response.result;
  }
});
