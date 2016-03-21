stateNameByUuid = (value, obj, key) ->
  wf = Workflows.findOne({code: "CustomerOrder"})
  result = "-"
  if wf?
    _.each wf.state, (state) ->
      if state.uuid is value
        result = state.name
        return
  return result

Template.statushistory.helpers {
  settings: () ->
    {
      collection: "status_history_special_publish",
      rowsPerPage: 25,
      showFilter: true,
      fields: [
        "orderName",
        {
          key:'date'
          label:"Дата"
          fn: (value, obj, key) ->
            moment.locale('ru');
            moment(value).format('DD.MM.YYYY в HH:mm:ss')
        },
        {
          key: 'newStateUuid'
          label: 'Новый статус'
          fn: stateNameByUuid
        }, {
          key: 'oldStateUuid'
          label: 'Старый статус'
          fn: stateNameByUuid
        }, {
          key:'timeSinceLastStatus',
          label:"Время с последнего изменения",
          fn: (value, obj, key) ->
            if value?
              (Number(moment(value).utc().format("DDD")) - 1) + " дней, " + moment(value).utc().format("HH:mm:ss")
            else
              "-"
        }],
      class: "ui celled table",
    }
}
