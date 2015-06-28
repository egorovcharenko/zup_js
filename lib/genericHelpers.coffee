getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then new Date(lastTimeLoaded.value) else '01-01-2014'
