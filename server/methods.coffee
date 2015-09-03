Meteor.methods
  "resetTimestamps": ->
    DataTimestamps.remove({})
