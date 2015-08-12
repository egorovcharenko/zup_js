Meteor.methods
  loadEntityFromMS: (entityName, collectionName, fromLastUpdate) ->
    console.log 'loadEntityFromMS started'
    collection = CollectionNameMap[collectionName]
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    tools = moyskladPackage.tools
    response = Async.runSync((done) ->
      toReturn = []
      countTotal = countAlready = 0
      client = moyskladPackage.createClient()
      client.setAuth 'admin@allshellac', 'qweasd'
      maxCountToLoad = 20000
      pageSize = 100
      query = moyskladPackage.createQuery(updated: $gte: fromLastUpdate)
      total = client.total(entityName, query)
      tempCol.upsert { 'name': 'countTotal' }, $set: 'value': total
      tempCol.upsert { 'name': 'isActive' }, $set: 'value': true
      if total > 0
        loop
          query.count(pageSize).start countAlready
          entitiesFromMs = client.load(entityName, query)
          if entitiesFromMs?
            _.each entitiesFromMs, (entity) ->
              savedEntity = collection.findOne(uuid: entity.uuid)
              if savedEntity?
                if entityName is "customerOrder"

                  #checked
                  entity.checked = savedEntity.checked

                  #pos.packedQty
                  if savedEntity.customerOrderPosition?
                    for cOP in savedEntity.customerOrderPosition
                      if cOP.packedQty?
                        correspondingNewCOP = _.find entity.customerOrderPosition, (newCOP) -> newCOP.uuid == cOP.uuid
                        if correspondingNewCOP?
                          correspondingNewCOP.packedQty = cOP.packedQty
                          console.log "packedQty saved for order: #{entity.name}, packedQty = #{cOP.packedQty}"
                else if entityName is "good"

                  #outOfStock
                  if savedEntity.outOfStock?
                    entity.outOfStock = savedEntity.outOfStock
                    console.log "outOfStock saved for good: #{entity.name}, outOfStock = #{savedEntity.outOfStock}"

                  # stockQty
                  if savedEntity.stockQty?
                    entity.stockQty = savedEntity.stockQty

                  # dirty
                  if savedEntity.dirty?
                    entity.dirty = savedEntity.dirty

                  # при изменении флажка "Отсутствует у поставщика - сбрасываем флажок"
                  # пока сбрасываем у всех измененных товаров
                  metadataUuid = findMetadataUuidByName('GoodFolder', "Отсутствует у поставщика")
                  outOfStockInSupplier = tools.getAttrValue(entity, metadataUuid)
                  entity.outOfStockInSupplier = outOfStockInSupplier
                  entity.dirty = true
                  console.log "Updating good's '#{entity.name}' stock, uuid:#{entity.uuid},  outOfStockInSupplier:#{entity.outOfStockInSupplier}"

                collection.remove uuid: entity.uuid
              collection.insert entity
              return
            countAlready += entitiesFromMs.length
            tempCol.upsert { 'name': 'countAlready' }, $set: 'value': countAlready
          unless countAlready < maxCountToLoad and entitiesFromMs.length > 0
            break
      tempCol.upsert { 'name': 'countTotal' }, $set: 'value': 10
      tempCol.upsert { 'name': 'countAlready' }, $set: 'value': 0
      tempCol.upsert { 'name': 'isActive' }, $set: 'value': false
      #console.log(toReturn);
      done null, toReturn
      return
    )
    console.log 'loadEntityFromMS ended'
    response.result
  toggleChecked: (entity) ->
    Orders.update entity._id, $set: checked: !entity.checked
    return
  resetChecked: ->
    Orders.update {}, { $set: checked: false }, multi: true
    return
  setAllChecked: (stateUuid1) ->
    console.log stateUuid1
    Orders.update {}, { $set: checked: false }, multi: true
    Orders.update { stateUuid: stateUuid1 }, { $set: checked: true }, multi: true
    return
  loadUpdatedOrders: ->
    lastTimeLoaded = DataTimestamps.findOne(name: 'orders')
    temp = if lastTimeLoaded then new Date(lastTimeLoaded.value) else '01-01-1900'
    Meteor.call 'loadEntityFromMS', 'customerOrder', 'Orders', temp
    DataTimestamps.upsert { name: 'orders' }, $set: value: Date.now()
    return
  updateTimestampFlag: (timestampToSet) ->
    DataTimestamps.upsert { name: timestampToSet }, $set: value: Date.now()
