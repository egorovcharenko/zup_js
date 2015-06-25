Meteor.methods({
  loadEntityFromMS: function (entityName, collectionName, fromLastUpdate) {
    console.log("loadEntityFromMS started");
    var collection = CollectionNameMap[collectionName];
    var moyskladPackage = Meteor.npmRequire('moysklad-client');
    console.log('1');
    var response = Async.runSync(function(done) {
      var toReturn = [];
      var countTotal = 0;
      var countAlready = 0;

      var client = moyskladPackage.createClient();
      client.setAuth('admin@allshellac', 'qweasd');

      var maxCountToLoad = 20000;
      var pageSize = 100;
      var entitiesFromMs;

      var query;
      query = moyskladPackage.createQuery({
        updated: {
          $gte: fromLastUpdate
        }
      });

      var total = client.total(entityName, query);
      tempCol.upsert({"name": "countTotal"}, {$set: {"value": total}});
      tempCol.upsert({"name": "isActive"}, {$set: {"value": true}});

      do {
        query.count(pageSize).start(countAlready);
        entitiesFromMs = client.load(entityName, query);
        _.each(entitiesFromMs, function (entity) {
          var savedEntity = collection.findOne({uuid: entity.uuid});
          if (savedEntity) {
            //var tempEntity = entity;
            // for (var property in entity) {
            //   if (entity.hasOwnProperty(property)) {
            //     console.log(property);
            //     collection.update({uuid:entity.uuid}, {$set: {property: entity[property]}});
            //   }
            // }
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
    });
    console.log("loadEntityFromMS ended");
    return response.result;
  },

  toggleChecked: function (entity) {
    Orders.update(entity._id, {$set: {checked: ! entity.checked}});
  },

  resetChecked: function () {
    Orders.update({}, {$set: {checked: false}}, {multi:true});
  },

  setAllChecked: function (stateUuid1) {
    console.log(stateUuid1);
    Orders.update({}, {$set: {checked: false}}, {multi:true});
    Orders.update({stateUuid: stateUuid1}, {$set: {checked: true}}, {multi:true});
  },

  loadUpdatedOrders: function () {
    var lastTimeLoaded = DataTimestamps.findOne({name: "orders"});
    var temp = lastTimeLoaded ? new Date(lastTimeLoaded.value) : '01-01-1900';
    Meteor.call("loadEntityFromMS", "customerOrder", "Orders", temp);
    DataTimestamps.upsert({name: "orders"}, {$set: {value: Date.now()}});
  },

  updateTimestampFlag: function (timestampToSet) {
    DataTimestamps.upsert({name: timestampToSet}, {$set: {value: Date.now()}});
  }
});
