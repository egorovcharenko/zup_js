Meteor.methods
  loadEntityFromMS: (entityName, collectionName, fromLastUpdate) ->
    #console.log "loadEntityFromMS started, collectionName:#{collectionName}, fromLastUpdate:", moment(fromLastUpdate).format("YYYYMMDDHHmmss")
    collection = CollectionNameMap[collectionName]
    toReturn = []
    countTotal = countAlready = 0
    maxCountToLoad = 50000
    pageSize = 100
    query = moyskladPackage.createQuery(updated: $gte: moment(fromLastUpdate).format("YYYYMMDDHHmmss"))
    total = client.total(entityName, query)
    if total > 0
      console.log "Найдено #{total} сущностей типа #{entityName} на загрузку, начинаем загружать..."
      try
        loop
          query.count(pageSize).start countAlready
          entitiesFromMs = client.load(entityName, query)
          if entitiesFromMs?
            _.each entitiesFromMs, (entity) ->
              savedEntity = collection.findOne(uuid: entity.uuid)
              if savedEntity?
                if entityName is "customerOrder"
                  if savedEntity.atDeliveryPlace?
                    entity.atDeliveryPlace = savedEntity.atDeliveryPlace
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
                  if savedEntity.ordersForBuy?
                    entity.ordersForBuy = savedEntity.ordersForBuy
                  if savedEntity.forAutoSale?
                    entity.forAutoSale = savedEntity.forAutoSale
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
                else if entityName is "company"
                  if savedEntity.dadata?
                    entity.dadata = savedEntity.dadata
                  try
                    load = false
                    if entity.requisite?
                      if entity.requisite.actualAddress?
                        if not entity.requisite.actualAddress is ""
                          if not (savedEntity.dadata?)
                            load = true
                          else if savedEntity.requisite?
                            if not (savedEntity.requisite.actualAddress is entity.requisite.actualAddress)
                              load = true
                    if load
                      console.log "Пытаемся стандартизировать адрес #{entity.requisite.actualAddress}"
                      request = [entity.requisite.actualAddress]
                      # получить часовой пояс
                      result = HTTP.post 'https://dadata.ru/api/v2/clean/address', data: request , headers: {"X-Secret": "4989bbb6a8d72f742f041c8b5716f889f83722ad", "Authorization": "Token 8dcd0d1af4c068d94bcfb8fc69df34f5e25462bd", "Content-Type": "application/json", "Accept": "application/json"}
                      entity.dadata = result.data[0]
                      console.log "Успешно стандартизировали адрес"
                  catch error
                    console.log "Ошибка при стандартизации адреса:", error.message
                    entity.dadata = ""
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
  updateTimestampFlag: (timestampToSet, timeToSet) ->
    #console.log "*** lastUpdatedTimestamp timeToSet:", timeToSet
    DataTimestamps.upsert { name: timestampToSet }, $set: value: (timeToSet)
