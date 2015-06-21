Meteor.startup(function () {
  orders._ensureIndex({ "uuid": 1});
  Companies._ensureIndex({ "uuid": 1});
  Goods._ensureIndex({ "uuid": 1});
});
