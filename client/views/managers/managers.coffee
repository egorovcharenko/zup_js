@orderActionHelper = (order)->
  ret = {}
  rule = OrderRules.findOne(stateUuid: order.stateUuid)
  if rule?
    ret.nextAction = rule.ruleAction
    lastActionTime = order.created
    ret.lastActionTime = "-"
    ret.lastAction = "-"
    if order.actions?
      _.each order.actions, (action)->
        if rule.ruleResetTimerAction?
          if action.type is rule.ruleResetTimerAction
            if moment(action.date).isAfter(moment(lastActionTime))
              lastActionTime = action.date
              ret.lastActionTime = moment(lastActionTime).format ("DD.MM,  HH:mm")
              ret.lastAction = rule.ruleResetTimerAction
        if rule.statusChangeAffects?
          if rule.statusChangeAffects
            if action.type is "stateChange"
              if moment(action.date).isAfter(moment(lastActionTime))
                lastActionTime = action.date
                ret.lastActionTime = moment(lastActionTime).format ("DD.MM,  HH:mm")
                ret.lastAction = "Изменение статуса"
    ret.nextActionStart = moment(lastActionTime).add(rule.ruleStartMinutesOffset, 'minutes')
    ret.nextActionEnd = moment(lastActionTime).add(rule.ruleDeadlineMinutesOffset, 'minutes')
    if moment().isAfter(ret.nextActionEnd)
      ret.timeLeft = Math.floor(moment.duration(moment(ret.nextActionEnd).diff(moment())).asMinutes())
    else
      ret.timeLeft = Math.floor(moment.duration(moment(ret.nextActionEnd).diff(moment())).asMinutes())
    ret.nextActionStart = ret.nextActionStart.format ("DD.MM,  HH:mm")
    ret.nextActionEnd = ret.nextActionEnd.format ("DD.MM,  HH:mm")
  ret

@orderHelper = (order) ->
  ret = {}
  ret.sum = order.sum.sum / 100
  temp = alasql('SEARCH /WHERE(name="CustomerOrder")//WHERE(uuid="' + order.stateUuid + '") FROM ?', [ Workflows ])[0]
  if temp?
    ret.state = temp.name
  ret

Template.managers.rendered = ->
  @$('.ui.dropdown').dropdown()
  @$('.ui.checkbox').checkbox()
  return

Template.managers.helpers
  settings: () ->
    {
      collection: "orders_special_publish",
      rowsPerPage: 25,
      showFilter: true,
      fields: [{
          fieldId: "openOrder"
          key:'uuid'
          label:"Действия"
          fn: (value, object, key)->
            #res = orderActionHelper object
            return new Spacebars.SafeString("<div class='ui button' id='openOrder' data-order-name='#{object.name}'>Открыть заказ</div>")
        }, {
          fieldId: "name"
          key:'name'
          label:"Номер"
        }, {
          fieldId: "state"
          key:'uuid'
          label:"Статус"
          fn: (value, object, key)->
            res = orderHelper object
            return res.state
        } , {
          fieldId: "buyGoodsInThisState"
          key:'buyGoodsInThisState'
          label:"Владелец заказа"
          fn: (value, object, key)->
            res = {}
            _.each object.attribute, (attr) ->
              if attr.metadataUuid is "7b7ebcf8-d4db-11e4-ac81-0cc47a0658aa"
                empl = Employees.findOne({uuid: attr.employeeValueUuid})
                return empl
            return '-'
        }, {
          fieldId: "nextAction"
          key:'uuid'
          label:"След. действие"
          fn: (value, object, key)->
            res = orderActionHelper object
            if res?
              if res.nextAction?
                rule = OrderRules.findOne {stateUuid: object.stateUuid}
                processName = null
                gotoScreen = null
                if rule?
                  if rule.processName?
                    processName = rule.processName
                  if rule.gotoScreen?
                    gotoScreen = rule.gotoScreen
                return new Spacebars.SafeString("<div class='ui teal button executeNextAction' data-order-name='#{object.name}' data-process-name='#{processName}' data-goto-screen='#{gotoScreen}'>#{res.nextAction}</a>")
            return '-'
          }, {
            fieldId: "nextActionStart"
            key:'uuid'
            label:"Выполнить с "
            fn: (value, object, key)->
              res = orderActionHelper object
              return res.nextActionStart
          }, {
            fieldId: "nextActionEnd"
            key:'uuid'
            label:"Выполнить по"
            fn: (value, object, key)->
              res = orderActionHelper object
              return res.nextActionEnd
            }, {
              fieldId: "timeLeft"
              key:'timeLeft'
              label:"Осталось времени"
              sortOrder: 1
              sortDirection: 'ascending'
              fn: (value, object, key)->
                return value
                res = orderActionHelper object
                return res.timeLeft
          }, {
            fieldId: "prevAction"
            key:'uuid'
            label:"Пред. действие"
            fn: (value, object, key)->
              res = orderActionHelper object
              return res.lastAction
          }, {
            fieldId: "prevActionTime"
            key:'uuid'
            label:"Время пред. действия"
            fn: (value, object, key)->
              res = orderActionHelper object
              return res.lastActionTime
          }
      ],
      class: "ui celled table"
    }

Template.managers.events
  'click .executeNextAction': (event, template) ->
    orderName = event.target.dataset.orderName
    processName = event.target.dataset.processName
    gotoScreen = event.target.dataset.gotoScreen
    console.log orderName, processName, gotoScreen
    if processName?
      Meteor.call 'startProcess', processName, {"orderNumber": orderName}, (error, result) ->
        if error?
          Meteor.call 'error:', error
        if result
          console.log "result:", result
      if gotoScreen?
        if gotoScreen is "order"
          # открыть страницу заказа
          console.log orderName
          Router.go('moderation', "orderName": orderName)
  'click #openOrder': (event, template) ->
    orderName = event.target.dataset.orderName
    # открыть страницу модерации заказов
    Router.go 'moderation', 'orderName': orderName
    return
