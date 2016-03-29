Meteor.methods
  "resetTimestamps": ->
    DataTimestamps.remove({})
    Goods.update {}, {$set: {dirty: true}}, {multi: true}
