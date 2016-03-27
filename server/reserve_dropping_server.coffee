Meteor.methods
  setDaysToDropReserve: (dataObject)->
    if dataObject.newVal >= 0
      OrderStatuses.update({uuid: dataObject.stateUuid}, {$set:{daysToDropReserve: dataObject.newVal}})
    else
      OrderStatuses.update({uuid: dataObject.stateUuid}, {$set:{daysToDropReserve: null}})
  periodicalDropReserve: ->
    try
      console.log "starting periodicalDropReserve"
      # пройтись по всем статусам
      _.each OrderStatuses.find({}).fetch(), (state) ->
        daysToDropReserve = parseInt(state.daysToDropReserve)
        console.log "#{state.name} \t\t #{daysToDropReserve}"
        if not isNaN(daysToDropReserve)
          # нужно в этом статусе сбрасывать резерв?
          if daysToDropReserve >= 0
            # пройтись по всем заказам
            _.each Orders.find({stateUuid: state.uuid}).fetch(), (order) ->
              # сколько времени прошло с последнего статуса?
              _.each StatusHistory.find({orderName: order.name, newStateUuid: state.uuid}).fetch(), (historyRecord) ->
                # прошло больше времени чем нужно?
                testResult = (moment().add(daysToDropReserve, 'days')).isAfter(moment().add(historyRecord.date))
                #console.log "order: #{order.name}, daysToDropReserve:#{daysToDropReserve}, lastChangeDate:#{moment(historyRecord.date).format()}, testResult:", testResult
                if testResult or daysToDropReserve == 0
                  # снять резерв
                  dataObject = {}
                  dataObject.orderName = order.name
                  Meteor.call "setOrderReserve", order.uuid, false, (error, result) ->
                    if error
                      console.log "error:", error
                    if result
                      ;
                else console.log "заказ слишком свежий: #{order.name}"
    catch error
      console.log "error:", error

  setOrderReserve: (entityUuid, setReserve) ->
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'
      order = client.load('customerOrder', entityUuid) #Orders.findOne({uuid: entityUuid})
      changed = false
      _.each order.customerOrderPosition, (position) ->
        if setReserve
          good = Goods.findOne({uuid: position.goodUuid})
          if good?
            resQty = Math.max(Math.min(position.quantity, good.realAvailableQty), 0)
            console.log "#{position.quantity}, #{good.realAvailableQty}, #{resQty}"
          else
            resQty = position.quantity
          if position.reserve != resQty
            position.reserve = resQty
            changed = true
        else
          if position.reserve != 0
            position.reserve = 0
            changed = true
        #console.log "position.reserve:", position.reserve
      if changed
        newEntity = client.save(order)
        console.log "new reserve sent to MS for order #{order.name}"
      done null, "Резерв изменен"
    )
    response.result
