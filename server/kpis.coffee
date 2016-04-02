calculateSumForLogEntry = (logEntry) ->
  # модерация +50р за модерацию

  # отмена заказа -50р

  # отказ от заказа -250р

  # звонок позже нужного времени - 100р

  # доппродажи

  # модерация с задержкой


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
