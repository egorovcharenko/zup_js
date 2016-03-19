Meteor.methods
  logSystemEvent: (type, severity, message)->
    SystemLog.insert {date: Date.now(), type:type, severity:severity, message:message}
