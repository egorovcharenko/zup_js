Template.goods.helpers
  settings: () ->
    {
      collection: "all_goods_special_publish"
      rowsPerPage: 20
      showFilter: true
      fields: [{
          fieldId: "code"
          key:'code'
          label:"Артикул"
        }, {
          fieldId: "name"
          key:'name'
          label:"Название"
        }, {
          fieldId: "supplier"
          key:'supplierUuid'
          label: "Поставщик"
          fn: (value)->
            comp = Companies.findOne({uuid: value})
            if comp?
              return comp.name
        }, {
          fieldId: "description"
          key:'description'
          label:"Место хранения"
        }, {
          fieldId: "stockQty"
          key:'stockQty'
          label:"Остаток"
        }, {
          fieldId: "reserveQty"
          key:'reserveQty'
          label:"Резерв"
        }, {
          fieldId: "quantityQty"
          key:'quantityQty'
          label:"Доступно"
        }, {
          fieldId: "includeInNextBuyingQty"
          key:'includeInNextBuyingQty'
          label:"Сколько будет включено в следующую закупку"
        }, {
          fieldId: "buttons"
          key:'uuid'
          label:"Открыть"
          fn: (value, object)->
            return new Spacebars.SafeString("<div class='ui teal button open-good' data-good-uuid='#{object.uuid}'>Действия с товаром</a>")
        }]
      class: "ui celled table"
    }

Template.goods.rendered = ->
  @$('.ui.modal').modal()
  return

Template.goods.events
  'click .open-good': (event, template) ->
    goodUuid = event.target.dataset.goodUuid
    $('.ui.modal').modal('show')
