myJobs.allow admin: (userId, method, params) ->
  if userId? then true else false

loadDataWorker = (job, cb) ->
  Meteor.call 'loadAllEntities'
  job.done()
  return cb()

updateEntityMSWorker = (job, cb) ->
  job.log "entityType: #{job.data.entityType}, entityUuid:#{job.data.entityUuid}, data:#{job.data.data}, attributes: #{job.data.attributes}"
  Meteor.call 'updateEntityMS', job.data.entityType, job.data.entityUuid, job.data.data, job.data.attributes, (error, result) ->
    if not error?
      job.log "успешно, результат: #{result}"
      job.done()
    else
      job.log "ошибка: #{error}"
      job.fail()
  return cb()

setEntityStateByUuidWorker = (job, cb) ->
  job.log "entityType: #{job.data.entityType}, entityUuid:#{job.data.entityUuid}, newStateUuid:#{job.data.newStateUuid}"
  Meteor.call 'setEntityStateByUuid', job.data.entityType, job.data.entityUuid, job.data.newStateUuid, (error, result) ->
    if not error?
      job.log "успешно, результат: #{result}"
      job.done()
    else
      job.log "ошибка: #{error}"
      job.fail()
  return cb()

Meteor.startup ->
  myJobs.startJobServer()

  if (myJobs.find({type: 'loadAllDataMoyskladPeriodic'}).count() == 0)
    # Create a job
    job = new Job myJobs, 'loadAllDataMoyskladPeriodic', {}
    job.priority('normal')
      .repeat({ repeats: myJobs.forever, wait: 10*1000})
      .save()

  # start processing jobs
  myJobs.processJobs 'loadAllDataMoyskladPeriodic', { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, loadDataWorker

  myJobs.processJobs 'setEntityStateByUuid', { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, setEntityStateByUuidWorker

  myJobs.processJobs 'updateEntityMS', { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, updateEntityMSWorker
