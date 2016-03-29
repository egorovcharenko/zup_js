Meteor.methods
  loadEntityFromMS: (entityName, collectionName, fromLastUpdate) ->
    #console.log "loadEntityFromMS started, collectionName:#{collectionName}, fromLastUpdate:", moment(fromLastUpdate).format("YYYYMMDDHHmmss")
    collection = CollectionNameMap[collectionName]
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    tools = moyskladPackage.tools
    response = Async.runSync((done) ->
      toReturn = []
      countTotal = countAlready = 0
      client = moyskladPackage.createClient()
      client.setAuth 'admin@allshellac', 'qweasd'
      maxCountToLoad = 50000
      pageSize = 100
      query = moyskladPackage.createQuery(updated: $gte: moment(fromLastUpdate).format("YYYYMMDDHHmmss"))
      total = client.total(entityName, query)
      if total > 0
        try
          loop
            query.count(pageSize).start countAlready
            entitiesFromMs = client.load(entityName, query)
            if entitiesFromMs?
              _.each entitiesFromMs, (entity) ->
                savedEntity = collection.findOne(uuid: entity.uuid)
                if savedEntity?
                  if entityName is "customerOrder"
                    if savedEntity.processingResult?
                      entity.processingResult = savedEntity.processingResult
                    if savedEntity.pendingChanges?
                      entity.pendingChanges = savedEntity.pendingChanges
                    if savedEntity.timeLeft?
                      entity.timeLeft = savedEntity.timeLeft
                    if savedEntity.actions?
                      entity.actions = savedEntity.actions
                    #checked
                    entity.checked = savedEntity.checked
                    #pos.packedQty
                    if savedEntity.customerOrderPosition?
                      for cOP in savedEntity.customerOrderPosition
                        if cOP.packedQty?
                          correspondingNewCOP = _.find entity.customerOrderPosition, (newCOP) -> newCOP.uuid == cOP.uuid
                          if correspondingNewCOP?
                            correspondingNewCOP.packedQty = cOP.packedQty
                            #console.log "packedQty saved for order: #{entity.name}, packedQty = #{cOP.packedQty}"
                    # statusHistory
                    if savedEntity.stateUuid != entity.stateUuid
                      Meteor.call "logStatusChangeEvent", entity.updated, entity.name, entityName, entity.uuid, entity.stateUuid, savedEntity.stateUuid
                      if entity.actions?
                        entity.actions.push {type:"stateChange", date: new Date()}
                      else
                        entity.actions = [{type:"stateChange", date: new Date()}]
                  else if entityName is "good"
                    if savedEntity.lastTimeChecked?
                      entity.lastTimeChecked = savedEntity.lastTimeChecked
                    if savedEntity.perWeekQtyNeeded?
                      entity.perWeekQtyNeeded = savedEntity.perWeekQtyNeeded
                    if savedEntity.includeInNextBuyingStockQty?
                      entity.includeInNextBuyingStockQty = savedEntity.includeInNextBuyingStockQty
                    if savedEntity.boughtOnLastPeriodsQty?
                      entity.boughtOnLastPeriodsQty = savedEntity.boughtOnLastPeriodsQty
                    if savedEntity.boughtOnLastPeriodsOrders?
                      entity.boughtOnLastPeriodsOrders = savedEntity.boughtOnLastPeriodsOrders
                    if savedEntity.includeInNextStockBuyingQty?
                      entity.includeInNextStockBuyingQty = savedEntity.includeInNextStockBuyingQty
                    if savedEntity.outOfStock?
                      entity.outOfStock = savedEntity.outOfStock
                    if savedEntity.stockQty?
                      entity.stockQty = savedEntity.stockQty
                    if savedEntity.reserveQty?
                      entity.reserveQty = savedEntity.reserveQty
                    if savedEntity.quantityQty?
                      entity.quantityQty = savedEntity.quantityQty
                    if savedEntity.reserveForSelectedAgentQty?
                      entity.reserveForSelectedAgentQty = savedEntity.reserveForSelectedAgentQty
                    if savedEntity.realAvailableQty?
                      entity.realAvailableQty = savedEntity.realAvailableQty
                    if savedEntity.dirty?
                      entity.dirty = savedEntity.dirty
                    if savedEntity.includeInNextBuyingQty?
                      entity.includeInNextBuyingQty = savedEntity.includeInNextBuyingQty
                    if savedEntity.nextPlannedRecieveDate?
                      entity.nextPlannedRecieveDate = savedEntity.nextPlannedRecieveDate
                    if savedEntity.nextFactRecieveDate?
                      entity.nextFactRecieveDate = savedEntity.nextFactRecieveDate
                    # пока сбрасываем у всех измененных товаров
                    metadataUuid = findMetadataUuidByName('GoodFolder', "Отсутствует у поставщика")
                    outOfStockInSupplier = tools.getAttrValue(entity, metadataUuid)
                    entity.outOfStockInSupplier = outOfStockInSupplier
                    entity.dirty = true
                    #console.log "Updating good's '#{entity.name}' stock, uuid:#{entity.uuid},  outOfStockInSupplier:#{entity.outOfStockInSupplier}"
                  else if entityName is "workflow"
                    ;
                  collection.remove uuid: entity.uuid
                else
                  if entityName is "customerOrder"
                    # statusHistory - создать первую запись
                    Meteor.call "logStatusChangeEvent", entity.updated, entity.name, entityName, entity.uuid, entity.stateUuid, null
                    if entity.actions?
                      entity.actions.push {type:"stateChange", date: new Date()}
                    else
                      entity.actions = [{type:"stateChange", date: new Date()}]
                collection.insert entity
                # workflow
                if entityName is "workflow"
                  if entity.code is "CustomerOrder"
                    _.each entity.state, (orderStateFromMs) ->
                      savedOrderState = OrderStatuses.findOne {uuid: orderStateFromMs.uuid}
                      if savedOrderState?
                        if savedOrderState.buyGoodsInThisState?
                          orderStateFromMs.buyGoodsInThisState = savedOrderState.buyGoodsInThisState
                        if savedOrderState.daysToDropReserve?
                          orderStateFromMs.daysToDropReserve = savedOrderState.daysToDropReserve
                        OrderStatuses.remove {uuid: savedOrderState.uuid}
                      OrderStatuses.insert orderStateFromMs
                return
              countAlready += entitiesFromMs.length
              #tempCol.upsert { 'name': 'countAlready' }, $set: 'value': countAlready
            unless countAlready < maxCountToLoad and entitiesFromMs.length > 0
              break
        catch error
          console.log "error:", error
          done error, null
      done null, toReturn
    )
    if response.error?
      throw new Meteor.Error "MS-query-problem", "Ошибка при загрузке данных: #{response.error}"
    else
      return response.result
  toggleChecked: (entity) ->
    Orders.update entity._id, $set: checked: !entity.checked
    return
  resetChecked: ->
    Orders.update {}, { $set: checked: false }, multi: true
    return
  setAllChecked: (stateUuid1) ->
    #console.log stateUuid1
    Orders.update {}, { $set: checked: false }, multi: true
    Orders.update { stateUuid: stateUuid1 }, { $set: checked: true }, multi: true
    return
  loadUpdatedOrders: ->
    lastTimeLoaded = DataTimestamps.findOne(name: 'orders')
    temp = if lastTimeLoaded then new moment(lastTimeLoaded.value) else '01-01-1900'
    Meteor.call 'loadEntityFromMS', 'customerOrder', 'Orders', temp
    #console.log "*** lastUpdatedTimestamp:", temp
    DataTimestamps.upsert { name: 'orders' }, $set: value: moment()
    return
  updateTimestampFlag: (timestampToSet, timeToSet) ->
    #console.log "*** lastUpdatedTimestamp timeToSet:", timeToSet
    DataTimestamps.upsert { name: timestampToSet }, $set: value: (timeToSet)
