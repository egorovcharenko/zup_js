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

          moment.updateLocale('en',
            workinghours:
              1: ["10", "18"],
              2: ["10", "18"],
              3: ["10", "18"],
              4: ["10", "18"],
              5: ["10", "18"],
              6: null,
              0: null,
          )

          ret.nextActionStartMoment = moment(lastActionTime).addWorkingTime(rule.ruleStartMinutesOffset, 'minutes')
          ret.nextActionEndMoment = moment(lastActionTime).addWorkingTime(rule.ruleDeadlineMinutesOffset, 'minutes')

          ret.nextActionStart = ret.nextActionStartMoment.format ("DD.MM,  HH:mm")
          ret.nextActionEnd = ret.nextActionEndMoment.format ("DD.MM,  HH:mm")

          ret.timeLeft = Math.floor(ret.nextActionEndMoment.workingDiff(moment(), 'minutes'))
          # обновить заказ
          Orders.update {uuid: order.uuid}, {$set:{timeLeft: ret.timeLeft}}
          updated++
          #console.log "updated #{order.name}, timeLeft: #{ret.timeLeft}"
        catch error
          console.log "error:", error
    console.log "updated #{updated} orders"
