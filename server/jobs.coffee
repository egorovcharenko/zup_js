myJobs.allow admin: (userId, method, params) ->
  if userId? then true else false

worker = (job, cb) ->
  console.log "update data job started, job:#{job._id}"
  Meteor.call 'loadAllEntities'
  job.done()
  console.log "update data job #{job._id} finished at #{moment().format()}"
  return cb()

Meteor.startup ->
  myJobs.startJobServer()

  # Create a job:
  job = new Job myJobs, 'loadAllDataMoysklad-Periodic', {}
  job.priority('normal')
    .retry({ retries: 0, wait: 60*1000 })
    .repeat({ repeats: myJobs.forever, wait: 60*1000})
    .save()

  # start processing jobs
  workers = myJobs.processJobs 'loadAllDataMoysklad-Periodic', { concurrency: 1, prefetch: 1, pollInterval: 1*1000 }, worker
