Template.nalogi.helpers
  settings: () ->
    {
      collection: "nalogi_special_publish"
      rowsPerPage: 50
      showFilter: true
      fields: [{
          fieldId: "date"
          key:'date'
          label:"Дата"
        },{
          fieldId: "accountUuid"
          key:'accountUuid'
          label:"Компания"
        },{
          fieldId: "sumSoldFromKTBuyPrice"
          key:'sumSoldFromKTBuyPrice'
          label:"sumSoldFromKTBuyPrice"
          fn: (value)->
            if value?
              return (value/100).toFixed(2)
        },{
          fieldId: "sumSoldNotFromKTSalePrice"
          key:'sumSoldNotFromKTSalePrice'
          label:"sumSoldNotFromKTSalePrice"
          fn: (value)->
            if value?
              return (value/100).toFixed(2)
        }]
      class: "ui celled table"
    }
