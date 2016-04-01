Template.viewlog.helpers {
  settings: () ->
    {
      collection: "log_special_publish",
      rowsPerPage: 25,
      showFilter: true,
      fields: [{
        key:'date'
        label:"Дата"
        fn: (value, obj, key) ->
          moment(value).format('DD.MM.YYYY в HH:mm')
          },
        'orderName',
        'userName',
        "text",
        'type'],
      class: "ui celled table"
    }
}
