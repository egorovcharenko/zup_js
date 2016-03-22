Template.workflows.helpers {
  settings: () ->
    {
      collection: "order_statuses_special_publish",
      rowsPerPage: 50,
      showFilter: true,
      fields: [{
          fieldId: "uuid"
          key:'uuid'
          label:"uuid"
        }, {
          fieldId: "name"
          key:'name'
          label:"Название"
        }, {
          fieldId: "buyGoodsInThisState"
          key:'buyGoodsInThisState'
          label:"Товары в этом статусе ставить в закупку?"
        }, {
          fieldId: "daysToDropReserve"
          key:'daysToDropReserve'
          label: "Через сколько дней снимать резерв"
          fn: (value, object, key)->
            if value?
              return new Spacebars.SafeString("<a data-val='#{value}' data-uuid='#{object.uuid}' class='decrease' href='#'>-</a><span>#{value}</span><a data-val='#{value}' data-uuid='#{object.uuid}' class='increase' href='#'>+</a>")
            else
              return new Spacebars.SafeString("<a data-val='-1' data-uuid='#{object.uuid}' class='decrease' href='#'>-</a><span>#{value}</span><a data-val='-1' data-uuid='#{object.uuid}' class='increase' href='#'>+</a>")
        }, {
          fieldId: "buttons"
          key:'uuid'
          label: "Действия"
          fn: (value)->
            return new Spacebars.SafeString("<a data-uuid="+value+" class='toggleBuyingState' href='#'>Переключить покупку</a>")
        }],
      class: "ui celled table",
    }
}

Template.workflows.events
  "click .toggleBuyingState": (event, template) ->
    dataObject = {}
    dataObject.stateUuid = event.target.dataset.uuid
    Meteor.call "toggleBuyingState", dataObject
  "click .decrease": (event, template) ->
    dataObject = {}
    dataObject.stateUuid = event.target.dataset.uuid
    dataObject.newVal = Number(event.target.dataset.val) - 1
    Meteor.call "setDaysToDropReserve", dataObject
  "click .increase": (event, template) ->
    dataObject = {}
    dataObject.stateUuid = event.target.dataset.uuid
    dataObject.newVal = Number(event.target.dataset.val) + 1
    Meteor.call "setDaysToDropReserve", dataObject
