myJobs.allow admin: (userId, method, params) ->
  if userId? then true else false

worker = (job, cb) ->
  console.log "job done at #{moment().format()}"
  job.done()
  return cb()

Meteor.startup ->
  myJobs.startJobServer()

  # Create a job:
  job = new Job myJobs, 'loadAllDataMoysklad-Periodic', {}
  job.priority('normal')
    .retry({ retries: 1, wait: 15*1000 })
    .repeat({ repeats: myJobs.forever, wait: 30*1000})
    .save()

  # start processing jobs
  workers = myJobs.processJobs 'loadAllDataMoysklad-Periodic', { concurrency: 1, prefetch: 1, pollInterval: 1*1000 }, worker
