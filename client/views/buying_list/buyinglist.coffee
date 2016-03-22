Template.buyinglist.helpers
  settings: () ->
    {
      collection: "goods_special_publish"
      rowsPerPage: 500
      showFilter: true
      fields: [{
          fieldId: "includeInNextBuyingQty"
          key:'includeInNextBuyingQty'
          label:"Сколько будет включено в следующую закупку"
        }, {
          fieldId: "name"
          key:'name'
          label:"Название"
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

Template.buyinglist.events
  "click #calculateBuyingQty": (event, template) ->
    dataObject = {}
    Meteor.call "calculateBuyingQty", dataObject
