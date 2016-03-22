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
        laterStringObject = _.find(supplier.attribute, (attr) -> attr.metadataUuid=="17dcaaf2-f04c-11e5-7a69-970d00616c6c")
        if laterStringObject?
          laterString = laterStringObject.valueString
          #console.log laterString
          sched = later.parse.text(laterString)
          #console.log sched
          nextPlannedDate = (later.schedule(sched).next(5, new Date()))[0]
          console.log "next date for #{supplier.name}: #{nextPlannedDate}"
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
