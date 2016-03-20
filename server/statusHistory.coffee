Meteor.methods
  logStatusChangeEvent: (date, orderName, entityType, entityUuid, newStateUuid, oldStateUuid)->
    lastStatusChangeRecord = StatusHistory.find({entityUuid: entityUuid}, {sort: {date: -1}, limit: 1}).fetch()[0]
    if lastStatusChangeRecord?
      timeSinceLastStatus = date - lastStatusChangeRecord.date
    else
      timeSinceLastStatus = "-"
    StatusHistory.insert {date: date, orderName: orderName, entityType:entityType, newStateUuid:newStateUuid, oldStateUuid:oldStateUuid, timeSinceLastStatus: timeSinceLastStatus}
