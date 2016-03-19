Template.statushistory.helpers {
  settings: () ->
    {
      collection: "status_history_special_publish",
      rowsPerPage: 100,
      showFilter: true,
      fields: [
        {
          key:'date'
          label:"Дата"
          fn: (value, obj, key) ->
            moment.locale('ru');
            moment(new Date(value)).format('DD.MM.YYYY в HH:mm')
        },
        'entityType',
        'newStateUuid',
        "oldStateUuid",
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
