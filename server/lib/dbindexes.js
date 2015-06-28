Meteor.startup(function () {
  Orders._ensureIndex({ "uuid": 1});
  Orders._ensureIndex({ "name": 1});
  Companies._ensureIndex({ "uuid": 1});
  Goods._ensureIndex({ "uuid": 1});
});
