Meteor.startup(function () {
  Orders._ensureIndex({ "uuid": 1});
  Orders._ensureIndex({ "name": 1});
  Companies._ensureIndex({ "uuid": 1});
  Goods._ensureIndex({ "uuid": 1});

  var basicAuth = new HttpBasicAuth("alex", "qweasd");
  basicAuth.protect();

  // создать коллекцию настроек если ее нет
  settingsCount = Settings.find({}).count();
  if (settingsCount == 0) {
    Settings.insert({name: "empty", value: "0"});
  }
});
