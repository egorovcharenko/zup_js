calculateSumForLogEntry = (logEntry) ->
  # модерация +50р за модерацию


Meteor.methods
  calculateKpis: ->
    console.log "начинаем подсчет KPI"
    # очистить логи
    Kpis.remove {}
    # пройтись по всем записям логов
    _.each Log.find({}).fetch(), (logEntry) ->
      # вычислить дату записи
      date = moment(logEntry.date).format('DD.MM.YYYY')
      # для каждой записи, проверить приводит ли она к выплате
      sum = calculateSumForLogEntry logEntry
      if sum > 0
        # если да, то занести запись и увеличить итог за эту дату
        if not Kpis.findOne {date: date, user: logEntry.userName}
          Kpis.insert {date: date, user: logEntry.userName}
        # внести запись в таблицу KPI
        Kpis.update {date: date, user: logEntry.userName}, {$inc: {sum: sum}}
    # устанавливаем общее рабочее время
    moment.locale('en',
      workinghours:
        1: ["9", "18"],
        2: ["9", "18"],
        3: ["9", "18"],
        4: ["9", "18"],
        5: ["9", "18"],
        6: null,
        0: null,
    )
    # пройтись по всем заказам?
    _.each Orders.find({}).fetch(), (order) ->
      # Модерация невовремя - штраф 100р
      # проходим по всей истории изменения статусов заказа, находим время поступления в модерацию и время выхода из нее
      startModerationStatus = StatusHistory.findOne {orderName: order.name, $or: [{newStateUuid: "3f201baf-8d32-11e4-7a07-673d00307946"}, {newStateUuid: "33cd998e-3090-11e5-7a07-673d0019b9ed"}]}
      if startModerationStatus?
        #console.log "found:", startModerationStatus
        startModerationTime = startModerationStatus.date
        #console.log "startModerationTime:#{startModerationTime}"
        moderationEndedStatus = StatusHistory.findOne {orderName: order.name, $or: [{oldStateUuid: "3f201baf-8d32-11e4-7a07-673d00307946"}, {oldStateUuid: "33cd998e-3090-11e5-7a07-673d0019b9ed"}]}
        if moderationEndedStatus?
          # учитываем пояс и рабочее время общее
          customer = Companies.findOne {uuid: order.sourceAgentUuid}
          if customer?
            if customer.dadata?
              if customer.dadata.timezone?
                offset = parseInt(customer.dadata.timezone.substring(3)) - 3 # москва
                moment.locale('en',
                workinghours:
                  1: [Math.max(9, 9 + offset).toString(), Math.min(18, 18 + offset).toString()],
                  2: [Math.max(9, 9 + offset).toString(), Math.min(18, 18 + offset).toString()],
                  3: [Math.max(9, 9 + offset).toString(), Math.min(18, 18 + offset).toString()],
                  4: [Math.max(9, 9 + offset).toString(), Math.min(18, 18 + offset).toString()],
                  5: [Math.max(9, 9 + offset).toString(), Math.min(18, 18 + offset).toString()],
                  6: null,
                  0: null,
                  )
          endModerationTime = moderationEndedStatus.date
          shouldBeModerated = moment(startModerationTime).addWorkingTime(15, 'minutes')
          # возращаем старое расписание
          moment.locale('en',
            workinghours:
              1: ["9", "18"],
              2: ["9", "18"],
              3: ["9", "18"],
              4: ["9", "18"],
              5: ["9", "18"],
              6: null,
              0: null,
          )
          #console.log "shouldBeModerated: #{moment(shouldBeModerated).format("YYYY-DD-MM в HH:mm")}"
          # а теперь смотрим, успели или нет
          if moment(endModerationTime).isAfter(shouldBeModerated)
            console.log "Заказ #{order.name} промодерирован с задержкой, должен был #{moment(shouldBeModerated).format("YYYY-DD-MM в HH:mm")}, а был #{moment(endModerationTime).format("YYYY-DD-MM в HH:mm")}"
      # звонок невовремя - штраф 100р


    console.log "закончили подсчет KPI"
