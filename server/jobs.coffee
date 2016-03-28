myJobs.allow admin: (userId, method, params) ->
  #if userId? then true else false
  true

processMSJobsWorker = (job, cb) ->
  switch job.type
    when "processPendingChanges"
      Meteor.call 'processPendingChanges', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "setOrderActionsParameters"
      Meteor.call 'setOrderActionsParameters', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "loadAllDataMoyskladPeriodic"
      Meteor.call 'loadAllEntities', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
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
    when "resetTimestamps"
      Meteor.call 'resetTimestamps', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "loadNotPrimaryEntities"
      Meteor.call 'loadNotPrimaryEntities', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "calculateBuyingQty"
      Meteor.call 'calculateBuyingQty', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "calculateNextArrivalDates"
      Meteor.call 'calculateNextArrivalDates', (error, result) ->
        if not error?
          job.log "успешно, результат: #{result}"
          job.done()
        else
          job.log "ошибка: #{error}"
          job.fail()
      return cb()
    when "periodicalDropReserve"
      console.log "periodicalDropReserve started"
      Meteor.call 'periodicalDropReserve', (error, result) ->
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

  # обновлять данные по заказам
  job = new Job myJobs, 'processPendingChanges', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 1*1000}) # 1 * 1000
    .repeat({ repeats: myJobs.forever, wait: 0})
    .save({cancelRepeats: true})

  # перодически обновлять в заказах сколько осталось времени до следующей задачи
  job = new Job myJobs, 'setOrderActionsParameters', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 15*1000}) # 1 * 1000
    .repeat({schedule: myJobs.later.parse.text('every 15 seconds')})
    .save({cancelRepeats: true})

  # автоматический сброс резервов
  job = new Job myJobs, 'periodicalDropReserve', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 15*1000}) # 1 * 1000
    .repeat({schedule: myJobs.later.parse.text('at 9:00 pm')})
    .save({cancelRepeats: true})

  # расчет дат поступления товаров
  job = new Job myJobs, 'calculateNextArrivalDates', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 15*1000}) # 1 * 1000
    .repeat({schedule: myJobs.later.parse.text('every 1 minute')})
    .save({cancelRepeats: true})

  # расчет списка на закупку
  job = new Job myJobs, 'calculateBuyingQty', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 15*1000}) # 1 * 1000
    .repeat({schedule: myJobs.later.parse.text('at 4:00 am')})
    .save({cancelRepeats: true})

  # загрузка данных из МС
  job = new Job myJobs, 'loadAllDataMoyskladPeriodic', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 1*1000}) # 1 * 1000
    .repeat({ repeats: myJobs.forever, wait: 0})
    .save({cancelRepeats: true})

  # Загрузка остатков из МС
  job = new Job myJobs, 'loadStockFromMS', {}
  job.priority('normal')
    .retry({retries: myJobs.forever, wait: 60*1000}) # 60 * 1000
    .repeat({ repeats: myJobs.forever, wait: 30*1000})
    .save({cancelRepeats: true})

  sendStock = Settings.findOne {name: "sendStock"}
  sendStockFlag = false
  if sendStock?
    if sendStock.value = "1"
      # Отправка остатков в Мадженто
      sendStockFlag = true

  if sendStockFlag
    job = new Job myJobs, 'sendStockToMagento', {}
    job.priority('normal')
      .retry({retries: myJobs.forever, wait: 5*1000})
      .repeat({ repeats: myJobs.forever, wait: 5*1000})
      .save({cancelRepeats: true})

  # Сброс флагов в 3 ночи
  job = new Job myJobs, 'resetTimestamps', {}
  job.priority('normal')
    .retry({retries: 5, wait: 60*1000})
    .repeat({schedule: myJobs.later.parse.text('at 01:00 am')})
    .save({cancelRepeats: true})

  # Загрузка не главных сущностей раз в 5 минут
  job = new Job myJobs, 'loadNotPrimaryEntities', {}
  job.priority('normal')
    .retry({retries: 5, wait: 1*1000})
    .repeat({schedule: myJobs.later.parse.text('every 1 minutes')}) # every 5 minutes
    .save({cancelRepeats: true})

  # Начать обрабатывать задачи
  myJobs.processJobs ['setOrderActionsParameters', 'periodicalDropReserve', 'calculateNextArrivalDates', 'calculateBuyingQty', 'loadAllDataMoyskladPeriodic','setEntityStateByUuid', 'updateEntityMS', 'resetTimestamps', 'loadNotPrimaryEntities', 'processPendingChanges'], { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, processMSJobsWorker

  if sendStockFlag
    myJobs.processJobs ['loadStockFromMS', 'sendStockToMagento'], { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, processStockJobsWorker
  else
    myJobs.processJobs ['loadStockFromMS'], { concurrency: 1, prefetch: 0, pollInterval: 1*1000 }, processStockJobsWorker

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
