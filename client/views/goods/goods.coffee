Template.goods.helpers
  settings: () ->
    {
      collection: "all_goods_special_publish"
      rowsPerPage: 50
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
          fieldId: "lastTimeChecked"
          key:'lastTimeChecked'
          label:"Последний раз проверяли"
          fn: (value, object)->
            if value?
              return moment(value).format("DD.MM.YYYY")
        }, {
          fieldId: "setNewQty"
          key:'stockQty'
          label:"Установить новое кол-во"
          fn: (value, object)->
            if not value?
              value = 0
            return new Spacebars.SafeString("<input good-uuid='#{object.uuid}' name='new_qty' type='text' value='#{value}'/><div class='ui teal button set-new-qty' data-good-uuid='#{object.uuid}'>Установить новое кол-во</div>")
        }, {
          fieldId: "setNewStorage"
          key:'description'
          label:"Место хранения"
          fn: (value, object)->
            if not value?
              value = ""
            return new Spacebars.SafeString("<input good-uuid='#{object.uuid}' name='new_storage' type='text' value='#{value}' placeholder='Ж1-23-4'/><div class='ui teal button set-new-storage' data-good-uuid='#{object.uuid}'>Установить новое место хранения</div>")
        }]
      class: "ui celled table"
    }
  isAnyGoodSelected: ->
    Router.current().params.goodSelected?

Template.goods.rendered = ->
  @$('.ui.modal').modal()
  return

Template.goods.events
  'click .open-good': (event, template) ->
    goodUuid = event.target.dataset.goodUuid
    console.log "goodUuid: #{goodUuid}"
    Router.go 'goods',
      goodSelected: goodUuid
    $('.ui.modal').modal('show')

  'click .set-new-qty': (event, template) ->
    dataObject = {}
    dataObject.goodUuid = event.target.dataset.goodUuid
    dataObject.newQty = $("input[good-uuid='#{dataObject.goodUuid}'][name='new_qty']").val()
    console.log "dataObject:", dataObject
    Meteor.call "setNewGoodQty", dataObject

  'click .set-new-storage': (event, template) ->
    dataObject = {}
    dataObject.goodUuid = event.target.dataset.goodUuid
    dataObject.description = $("input[good-uuid='#{dataObject.goodUuid}'][name='new_storage']").val()
    console.log "dataObject:", dataObject
    Meteor.call "setNewGoodStorage", dataObject
