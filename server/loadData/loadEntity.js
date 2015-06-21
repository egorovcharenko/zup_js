Meteor.methods({
  loadEntityFromMS: function (stateToLoad, entityName, collectionName, operationOnEachEntity) {
    //console.log(arguments);
    //check(arguments, [Match.Any]);
    var collection = CollectionNameMap[collectionName];
    var moyskladPackage = Meteor.npmRequire('moysklad-client');

    var response = Async.runSync(function(done) {
      var toReturn = [];
      var countTotal = 0;
      var countAlready = 0;

      var client = moyskladPackage.createClient();
      client.setAuth('admin@allshellac', 'qweasd');

      var query = moyskladPackage.createQuery();

      var maxCountToLoad = 10000;
      var pageSize = 200;
      var entitiesFromMs;

      var totalQuery = moyskladPackage.createQuery();
      if (stateToLoad) {
        totalQuery.select(stateToLoad);
      }
      var total = client.total(entityName, totalQuery);
      tempCol.upsert({"name": "countTotal"}, {$set: {"value": total}});
      tempCol.upsert({"name": "isActive"}, {$set: {"value": true}});

      do {
        query.count(pageSize).start(countAlready);
        if (stateToLoad) {
          query.select(stateToLoad);
        }
        entitiesFromMs = client.load(entityName, query);
        _.each(entitiesFromMs, function (entity) {
          if (collection.find({uuid: entity.uuid}).count() > 0) {
            collection.remove({uuid: entity.uuid});
          }
          collection.insert(entity);

          });

        countAlready += entitiesFromMs.length;

        tempCol.upsert({"name": "countAlready"}, {$set: {"value": countAlready}});
      } while ((countAlready < maxCountToLoad) && (entitiesFromMs.length > 0))

      // end
      tempCol.upsert({"name": "countTotal"}, {$set: {"value": 10}});
      tempCol.upsert({"name": "countAlready"}, {$set: {"value": 0}});
      tempCol.upsert({"name": "isActive"}, {$set: {"value": false}});
      //console.log(toReturn);
      done(null, toReturn);

      //return toReturn;

    });
    //console.log(response.result);
    return response.result;
  },

  toggleChecked: function (entity) {
    orders.update(entity._id, {$set: {checked: ! entity.checked}});
  },

  resetChecked: function () {
    orders.update({}, {$set: {checked: false}}, {multi:true});
  },

  setAllChecked: function (stateUuid1) {
    console.log(stateUuid1);
    orders.update({}, {$set: {checked: false}}, {multi:true});
    orders.update({stateUuid: stateUuid1}, {$set: {checked: true}}, {multi:true});
  }
});
