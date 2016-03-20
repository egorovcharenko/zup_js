stateNameByUuid = (value, obj, key) ->
  wf = Workflows.findOne({code: "CustomerOrder"})
  if wf?
    _.each wf.state, (state) ->
      if state.uuid is value
        return state.name
  "-"

Template.statushistory.helpers {
  settings: () ->
    {
      collection: "status_history_special_publish",
      rowsPerPage: 100,
      showFilter: true,
      fields: [
        "orderName",
        {
          key:'date'
          label:"Дата"
          fn: (value, obj, key) ->
            moment.locale('ru');
            moment(new Date(value)).format('DD.MM.YYYY в HH:mm')
        },
        'entityType',
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
              moment.locale('ru');
              if timeSinceLastStatus?
                moment().from(timeSinceLastStatus)
              else
                "-"
            else
              "-"
        }],
      class: "ui celled table",
    }
}
