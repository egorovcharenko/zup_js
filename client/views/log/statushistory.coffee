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
            Workflows.findOne({uuid: value}).name
        },
        {
          key: 'oldStateUuid'
          label: 'Старый статус'
          fn: (value, obj, key) ->
            if value?
              Workflows.findOne({uuid: value}).name
            else
              "-"
        },
        {
          key:'timeSinceLastStatus',
          label:"Время с последнего изменения",
          fn: (value, obj, key) ->
            moment.locale('ru');
            moment().from(timeSinceLastStatus)
        }],
      class: "ui celled table",

    }
}
