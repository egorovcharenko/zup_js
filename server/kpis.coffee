makeKpiRecord = (date, userName, sum, reason) ->
  if not Kpis.findOne {date: date, user: userName}
    Kpis.insert {date: date, user: userName, reasons: []}
  # внести запись в таблицу KPI
  Kpis.update {date: date, user: userName}, {$inc: {sum: sum}, $push: {reasons: reason}}

Meteor.methods
  calculateKpis: ->
    console.log "начинаем подсчет KPI"
    # очистить логи
    Kpis.remove {}
    ModerationTimes.remove {}
    # пройтись по всем записям логов
    _.each Log.find({}).fetch(), (logEntry) ->
      # вычислить дату записи
      date = moment(logEntry.date).format('DD.MM.YYYY')
      # для каждой записи, проверить приводит ли она к выплате
      sum = 0
      reason = ""
      if sum > 0
        # если да, то занести запись и увеличить итог за эту дату
        makeKpiRecord date, logEntry.userName, sum, reason
    # устанавливаем общее рабочее время
    moment.updateLocale('en',
      workinghours:
        1: ["10", "18"],
        2: ["10", "18"],
        3: ["10", "18"],
        4: ["10", "18"],
        5: ["10", "18"],
        6: null,
        0: null,
    )
    # пройтись по всем заказам?
    _.each Orders.find({created: {$gt: moment().subtract(3, 'days').toDate()}}).fetch(), (order) ->
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
                moment.updateLocale('en',
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
          shouldBeModerated = moment(startModerationTime).addWorkingTime(30, 'minutes')
          # возращаем старое расписание
          moment.updateLocale('en',
            workinghours:
              1: ["10", "18"],
              2: ["10", "18"],
              3: ["10", "18"],
              4: ["10", "18"],
              5: ["10", "18"],
              6: null,
              0: null,
          )
          #console.log "shouldBeModerated: #{moment(shouldBeModerated).format("YYYY-DD-MM в HH:mm")}"
          # а теперь смотрим, успели или нет
          if moment(endModerationTime).isAfter(shouldBeModerated)
            reason = "Штраф 100р: Заказ #{order.name} промодерирован с задержкой, должен был #{moment(shouldBeModerated).format("YYYY-DD-MM в HH:mm:ss")}, а был #{moment(endModerationTime).format("YYYY-DD-MM в HH:mm")}"
            console.log reason
            makeKpiRecord moment(startModerationTime).format('DD.MM.YYYY'), "все", -100, reason
          # записать время модерации заказа
          ModerationTimes.insert({orderName: order.name, moderationTime: moment(startModerationTime).workingDiff(moment(endModerationTime), "minutes")})

      _.each OrderRules.find({}).fetch(), (rule) ->
        # находим каждый этот статус
        _.each StatusHistory.find({orderName: order.name, newStateUuid: rule.stateUuid}).fetch(), (inStatus) ->
          if rule.statusChangeAffects
            # находим какой был ближайший другой статус
            nextActionStatus = StatusHistory.findOne({orderName: order.name, date: {$gt: inStatus.date}}, {$sort:{date:1}})
            if nextActionStatus?
              nextActionDate = nextActionStatus.date
          if order.actions?
            ruleActionTime = moment()
            # ближайшее нужное действие
            _.each order.actions, (act) ->
              if act.type is rule.ruleResetTimerAction
                if ruleActionTime.isAfter(moment(act.date))
                  ruleActionTime = moment(act.date)
          if moment(nextActionDate).isAfter(ruleActionTime)
            nextActionDate = ruleActionTime
          nextActionDate = moment(nextActionDate)
          #lowerBoundMoment = moment(inStatus.date).addWorkingTime(rule.ruleStartMinutesOffset, 'minutes')
          upperBoundMoment = moment(inStatus.date).addWorkingTime(rule.ruleDeadlineMinutesOffset, 'minutes')
          # собственно проверка
          if (nextActionDate.isAfter(upperBoundMoment))
            punish = true
            if rule.statusChangeAffects
              actionName = "перевод в другой статус из статуса " + OrderStatuses.findOne({uuid: inStatus.newStateUuid}).name
            else
              actionName = rule.ruleResetTimerAction
            reason = "Штраф 100р: Заказ #{order.name} - действие '#{actionName}' должно было быть совершено до #{upperBoundMoment.format("YYYY-DD-MM HH:mm")}, а по факту совершено в #{nextActionDate.format("YYYY-DD-MM HH:mm")}"
            console.log reason
            if rule.punishAll
              whomToPunish = "все"
            else
              emplUuid = _.find(order.attribute, (attr) -> attr.metadataUuid is "7b7ebcf8-d4db-11e4-ac81-0cc47a0658aa")
              if emplUuid?
                whomToPunish = Employees.findOne({uuid: emplUuid.employeeValueUuid}).name
              else
                whomToPunish = "не понятно"
            makeKpiRecord moment(inStatus.date).format('DD.MM.YYYY'), whomToPunish, -100, reason
    console.log "закончили подсчет KPI"
