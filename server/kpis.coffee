calculateSumForLogEntry = (logEntry) ->
  # модерация

  # отмена заказа

  # отказ от заказа

  # звонок не в нужное время

  #

  #

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
    console.log "закончили подсчет KPI"
