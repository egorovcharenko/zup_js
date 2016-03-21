Meteor.methods
  logStatusChangeEvent: (date, orderName, entityType, entityUuid, newStateUuid, oldStateUuid)->
    lastStatusChangeRecord = StatusHistory.find({orderName: orderName}, {sort: {date: -1}, limit: 1}).fetch()[0]
    #console.log "lastStatusChangeRecord:", lastStatusChangeRecord
    if lastStatusChangeRecord?
      timeSinceLastStatus = date - lastStatusChangeRecord.date
    else
      timeSinceLastStatus = null
    StatusHistory.insert {date: date, orderName: orderName, entityType:entityType, newStateUuid:newStateUuid, oldStateUuid:oldStateUuid, timeSinceLastStatus: timeSinceLastStatus}
