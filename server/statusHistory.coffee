Meteor.methods
  logStatusChangeEvent: (date, entityType, entityUuid, newStateUuid, oldStateUuid)->
    lastStatusChangeRecord = StatusHistory.find({entityUuid: entityUuid}, {sort: {date: -1}, limit: 1}).fetch()[0]
    if lastStatusChangeRecord?
      timeSinceLastStatus = date - lastStatusChangeRecord.date
    else
      timeSinceLastStatus = null
    StatusHistory.insert {date: date, entityType:entityType, newStateUuid:newStateUuid, oldStateUuid:oldStateUuid, timeSinceLastStatus: timeSinceLastStatus}
