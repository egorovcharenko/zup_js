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
          fn: (value, obj, key) ->
              wf = Workflows.findOne({uuid: value})
              #console.log "wf:", wf
              if wf?
                wf.name
              else
                "-"
        },{
          key: 'oldStateUuid'
          label: 'Старый статус'
          fn: (value, obj, key) ->
            if value?
              wf = Workflows.findOne({uuid: value})
              #console.log "wf:", wf
              if wf?
                wf.name
              else
                "-"
            else
              "-"
        },{
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
