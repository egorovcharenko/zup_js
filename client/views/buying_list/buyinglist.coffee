Template.buyinglist.helpers
  settings: () ->
    {
      collection: "goods_special_publish"
      rowsPerPage: 50
      showFilter: true
      fields: [{
          fieldId: "name"
          key:'name'
          label:"Название"
        },{
          fieldId: "stockQty"
          key:'stockQty'
          label:"Остаток"
        },{
          fieldId: "reserveQty"
          key:'reserveQty'
          label:"Резерв"
        },{
          fieldId: "realAvailableQty"
          key:'realAvailableQty'
          label:"Доступно"
        },{
          fieldId: "includeInNextBuyingQty"
          key:'includeInNextBuyingQty'
          label:"Сколько будет включено в следующую закупку под заказ"
        },{
          fieldId: "boughtOnLastPeriodsQty"
          key:'boughtOnLastPeriodsQty'
          label:"Закуплено в пред период"
        }, {
          fieldId: "boughtOnLastPeriodsOrders"
          key:'boughtOnLastPeriodsOrders'
          label:"Заказов за пред период"
        }, {
          fieldId: "perWeekQtyNeeded"
          key:'perWeekQtyNeeded'
          label:"Расход в неделю"
        },{
          fieldId: "includeInNextBuyingStockQty"
          key:'includeInNextBuyingStockQty'
          label:"Сколько будет включено в следующую закупку про запас"
        }, {
          fieldId: "supplier"
          key:'supplierUuid'
          label: "Поставщик"
          fn: (value)->
            Companies.findOne({uuid: value}).name
        }, {
          fieldId: "ordersForBuy"
          key:'ordersForBuy'
          label: "Заказы для этой закупки"
          fn: (value)->
            result = ""
            _.each value, (ordr) ->
              result += "#{ordr.qty}шт - #{ordr.state} - #{ordr.name}<br/>"
            return new Spacebars.SafeString(result)
          }]
      class: "ui celled table"
    }
  supplierHelper: (supplierUuid) ->
    Companies.findOne {uuid: supplierUuid}
