Template.systemlog.helpers {
  settings: () ->
    {
      collection: "system_log_special_publish",
      rowsPerPage: 100,
      showFilter: true,
      fields: [{
        key:'date'
        label:"Дата"
        fn: (value, obj, key) ->
          moment.locale('ru');
          moment(new Date(value)).format('DD.MM.YYYY в HH:mm')
          }, 'type', 'message', "severity"],
      class: "ui celled table",
    }
}
