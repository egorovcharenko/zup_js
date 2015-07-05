myJobs.allow admin: (userId, method, params) ->
  #if userId? then true else false
  true

processMSJobsWorker = (job, cb) ->
  switch job.type
    when "loadAllDataMoyskladPeriodic"
      Meteor.call 'loadAllEntities'
      job.done()
      return cb()
    when "setEntityStateByUuid"
      job.log "entityType: #{job.data.entityType}, entityUuid:#{job.data.entityUuid}, newStateUuid:#{job.data.newStateUuid}"
      Meteor.call 'setEntityStateByUuid', job.data.entityType, job.data.entityUuid, job.data.newStateUuid, (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "updateEntityMS"
      job.log "entityType: #{job.data.entityType}, entityUuid:#{job.data.entityUuid}, data:#{job.data.data}, attributes: #{job.data.attributes}"
      Meteor.call 'updateEntityMS', job.data.entityType, job.data.entityUuid, job.data.data, job.data.attributes, (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()

processStockJobsWorker = (job, cb) ->
  switch job.type
    when "loadStockFromMS"
      Meteor.call 'loadStockFromMS', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "sendStockToMagento"
      Meteor.call 'sendStockToMagento', job, (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()

Meteor.startup ->
  myJobs.startJobServer()

  # загрузка данных из МС
  job = new Job myJobs, 'loadAllDataMoyskladPeriodic', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 30*1000})
    .repeat({ repeats: myJobs.forever, wait: 10*1000})
    .save({cancelRepeats: true})

  # Загрузка остатков из МС
  job = new Job myJobs, 'loadStockFromMS', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 60*1000})
    .repeat({ repeats: myJobs.forever, wait: 30*1000})
    .save({cancelRepeats: true})

  # Отправка остатков в Мадженто
  job = new Job myJobs, 'sendStockToMagento', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 60*1000})
    .repeat({ repeats: myJobs.forever, wait: 30*1000})
    .save({cancelRepeats: true})

  # Начать обрабатывать задачи
  myJobs.processJobs ['loadAllDataMoyskladPeriodic','setEntityStateByUuid','updateEntityMS'], { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, processMSJobsWorker

  myJobs.processJobs ['loadStockFromMS', 'sendStockToMagento'], { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, processStockJobsWorker


  # cleanups and remove stale jobs
  new Job(myJobs, 'cleanup', {})
    .repeat({ schedule: myJobs.later.parse.text("every 1 minute") })
    .save({cancelRepeats: true})

  new Job(myJobs, 'autofail', {})
    .repeat({ schedule: myJobs.later.parse.text("every 1 minute") })
    .save({cancelRepeats: true})

  q = myJobs.processJobs ['cleanup', 'autofail'], { pollInterval: 100000000 }, (job, cb) ->
    current = new Date()
    switch job.type
      when 'cleanup'
        current.setMinutes(current.getMinutes() - 60)
        ids = myJobs.find({
          status:
            $in: Job.jobStatusRemovable
          updated:
            $lt: current},
          {fields: { _id: 1 }}).map (d) -> d._id
        myJobs.removeJobs(ids) if ids.length > 0
        # console.warn "Removed #{ids.length} old jobs"
        job.done("Removed #{ids.length} old jobs")
        cb()
      when 'autofail'
        c = 0
        current.setMinutes(current.getMinutes() - 10)
        myJobs.find({
          status: 'running'
          updated:
            $lt: current})
          .forEach (j) ->
            c++
            #console.log j
            j.fail "Timed out by autofail"
        # console.warn "Failed #{c} stale running jobs"
        job.done "Failed #{c} stale running jobs"
        cb()
      else
        job.fail "Bad job type in worker"
        cb()

  myJobs.find({ type: { $in: ['cleanup', 'autofail']}, status: 'ready' })
    .observe
      added: () -> q.trigger()
