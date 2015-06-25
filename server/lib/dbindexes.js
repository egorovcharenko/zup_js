Meteor.startup(function () {
  Orders._ensureIndex({ "uuid": 1});
  Companies._ensureIndex({ "uuid": 1});
  Goods._ensureIndex({ "uuid": 1});
});
