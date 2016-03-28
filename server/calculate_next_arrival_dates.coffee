Meteor.methods
  calculateNextArrivalDates: ->
    console.log "calculateNextArrivalDates started"
    # находим статус нужный
    wf = Workflows.findOne {code: "PurchaseOrder"}
    activeStateUuid = _.find(wf.state, (state) -> state.name == "Закупка в процессе").uuid

    # пройтись по всем поставщикам
    _.each Companies.find({ tags: $in: [ 'поставщики' ] }).fetch(), (supplier) ->
      try
        # вычислить дату следующего планового прихода
        sendOrderDateObj = _.find(supplier.attribute, (attr) -> attr.metadataUuid=="c5723a4e-f3f7-11e5-7a69-970d0029005c")
        leadTimeObj = _.find(supplier.attribute, (attr) -> attr.metadataUuid=="26dc14e6-f4f1-11e5-7a69-9715004759f2")
        if leadTimeObj?
          leadTime = parseInt(leadTimeObj.longValue)
        else
          leadTime = 5
        if sendOrderDateObj?
          #console.log "---"
          sendOrderDate = sendOrderDateObj.valueString
          #console.log "sendOrderDate", sendOrderDate
          sched = later.parse.text(sendOrderDate)
          #console.log sched
          start = moment().add(1, 'days').toDate()
          #console.log "start:", start
          #console.log later.schedule(sched).next(5)
          nextOrderDate = later.schedule(sched).next(5, start)[0]
          #console.log "nextOrderDate:#{nextOrderDate}"
          nextPlannedDate = moment(nextOrderDate).add(leadTime, 'days').toDate()
          #console.log "next date for #{supplier.name}: #{nextPlannedDate}"
          # обновить ее у всех товаров
          Goods.update {supplierUuid: supplier.uuid}, {$set:{nextPlannedRecieveDate: nextPlannedDate, nextDate: nextPlannedDate}}, multi: true
          # вычислить дату следующего фактического прихода
          _.each PurchaseOrders.find({sourceAgentUuid: supplier.uuid, stateUuid: activeStateUuid, applicable:true}, {$sort: {created: 1}}).fetch(), (order) ->
            #console.log "#{order.name}"
            nextFactDate = order.deliveryPlannedMoment
            if nextFactDate?
              _.each order.purchaseOrderPosition, (pos) ->
                #console.log pos.goodUuid
                Goods.update {uuid: pos.goodUuid}, {$set: {nextFactRecieveDate: nextFactDate, nextDate: nextFactDate}}
      catch error
        console.log "error:", error
