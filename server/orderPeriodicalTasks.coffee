Meteor.methods
  setOrderActionsParameters: ->
    console.log "starting setOrderActionsParameters"
    updated = 0
    _.each OrderRules.find().fetch(), (rule) ->
      #console.log "rule:#{rule.stateUuid}"
      _.each Orders.find({stateUuid: rule.stateUuid}).fetch(), (order) ->
        #console.log "order #{order.name}"
        try
          ret = {}
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
          # обновить заказ
          Orders.update {uuid: order.uuid}, {$set:{timeLeft: ret.timeLeft}}
          updated++
          #console.log "updated #{order.name}, timeLeft: #{ret.timeLeft}"
        catch error
          console.log "error:", error
    console.log "updated #{updated} orders"
