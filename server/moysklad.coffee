getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then new Date(lastTimeLoaded.value) else '01-01-2014'

findMetadataUuidByName = (entityName, attrName) ->
  #console.log("findMetadataUuidByName: entityName:" + entityName + ", attrName: " + attrName);
  embEntityMetadata = EmbeddedEntityMetadata.findOne(name: entityName)
  #console.log("embEntityMetadata: " + objToString(embEntityMetadata));
  result = undefined
  _.every embEntityMetadata.attributeMetadata, (attr) ->
    #console.log("--attributeMetadata: " + objToString(attr));
    if attr.name == attrName
      result = attr.uuid
      return false
    true
  result

objToString = (obj) ->
  str = ''
  for p of obj
    if obj.hasOwnProperty(p)
      str += p + '::' + obj[p] + '\n'
  str

skipGoodStock = (good) ->
  # пропускаем наборы
  if (good.name.lastIndexOf("Набор для шеллака", 0) == 0) or (good.name.lastIndexOf("Набор шеллака", 0) == 0) or (good.name.lastIndexOf("Гель-лак AllShellac Premiere", 0) == 0)
    true
  else
    false

logChangesInDescription = (entityFromMS, field, oldv, newv) ->
  if entityFromMS.hasOwnProperty('description')
    entityFromMS.description += "\n-------------\n#{moment().format('DD.MM.YY [в] HH:mm')} через приложение изменено поле '#{field}', со значения '#{(if oldv then oldv else '(пусто)')}' на '#{(if newv then newv else '(пусто)')}'"

Meteor.methods
  updateEntityMS: (entityType, entityUuid, data, attributes) ->
    console.log 'updateEntityMS started, paremeters:' + arguments
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'
      console.log 'entityType: ' + entityType + ', entityUuid: ' + entityUuid
      entityFromMS = client.load(entityType, entityUuid)
      console.log 'entityFromMS: ' + entityFromMS
      console.log 'data:' + data
      if data?
        for prop of data
          if data.hasOwnProperty(prop)
            console.log '-property ' + prop
            entityFromMS[prop] = data[prop]
      console.log entityFromMSAfter1: entityFromMS
      # update attribs
      _.each attributes, (attrib) ->
        # {name: value}
        console.log '-attrib: ' + attrib
        metadataUuid = findMetadataUuidByName('CustomerOrder', attrib.name)
        console.log 'metadataUuid: ' + metadataUuid
        console.log entityFromMSBeforeGettingAttrib: entityFromMS.attribute.length
        test = tools.getAttr(entityFromMS, metadataUuid)
        console.log 'test: ' + test
        console.log entityFromMSAfterGettingAttrib: entityFromMS.attribute.length
        oldValue = test.valueString
        test.valueString = attrib.value
        console.log entityFromMSAfterSettingAttrib: entityFromMS.attribute.length
        console.log 'new value: ' + tools.getAttrValue(entityFromMS, metadataUuid)
        logChangesInDescription entityFromMS, attrib.name, oldValue, attrib.value
        return
      console.log entityFromMSAfter2: entityFromMS
      newEntity = client.save(entityFromMS)
      console.log 'newEntity: ', newEntity
      done null, "Заменено"
    )
    console.log 'updateEntityMS ended'
    response.result

  setEntityStateByUuid: (entityType, entityUuid, newStateUuid) ->
    #console.log "setEntityState started, newState: #{newStateUuid}"
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      try
        client = moyskladPackage.createClient()
        client.setAuth 'admin@allshellac', 'qweasd'
        entityFromMS = client.load(entityType, entityUuid)
        #console.log "entityFromMS before: #{objToString entityFromMS}"
        stateWorkflow = Workflows.findOne name:"CustomerOrder"

        oldStateName = (_.find stateWorkflow.state, (state) -> state.uuid is entityFromMS.stateUuid).name
        newStateName = (_.find stateWorkflow.state, (state) -> state.uuid is newStateUuid).name
        #console.log "newStateUuid: #{newStateUuid}"

        entityFromMS.stateUuid = newStateUuid
        logChangesInDescription entityFromMS, "Статус", oldStateName, newStateName
        #console.log "entityFromMS after: #{objToString entityFromMS}"

        client.save(entityFromMS)

        #fake on the client
        if entityType is "customerOrder"
          Orders.update({uuid: entityUuid}, {$set:{stateUuid: newStateUuid}})

        done null, oldStateName + "->" + newStateName
      catch error
        done error, null
    )
    if response.error?
      throw error
    else
      response.result

  loadEntityGenericMethod: (entityMSName, collectionName) ->
    console.log "loadEntityGenericMethod, entityMSName: #{entityMSName}"
    Meteor.call 'loadEntityFromMS', entityMSName, collectionName, getLastTimeRun(entityMSName), (error, result) ->
      if not error?
        Meteor.call 'updateTimestampFlag', entityMSName
      else
        console.log "Error in loading entities: #{error}"

  loadStockFromMS: () ->
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      try
        client = moyskladPackage.createClient()
        client.setAuth 'admin@allshellac', 'qweasd'

        options = {
          #stockMode: ALL_STOCK,
          showConsignments: false
        };

        stock = client.stock(options);
        if stock?
          console.log "Получено с сервера #{stock.length} остатков"
          for oneStock in stock
            if oneStock.goodRef?
              good = Goods.findOne uuid:oneStock.goodRef.uuid
              if good?
                # пропускаем товары
                if (skipGoodStock good)
                  # do nothing
                else
                  if good.stockQty?
                    if good.stockQty != oneStock.stock
                      Goods.update({uuid: oneStock.goodRef.uuid}, {$set: {stockQty: oneStock.stock, dirty: true}})
                  else
                    Goods.update({uuid: oneStock.goodRef.uuid}, {$set: {stockQty: oneStock.stock, dirty: true}})
                  #console.log "Установлен остаток для товара #{oneStock.goodRef.name} - #{good.stockQty} штук"
              else
                console.log "При загрузке остатков не нашли товар: #{oneStock.goodRef.name}"
            else
              console.log "В остатках нет информации о товаре"
          done null, "Остатки загружены успешно, количество: #{stock.length}"
        else
          done "Не получены остатки с сервера", null
      catch error
        done error, null
    )
    if response.error?
      console.log error
      throw error
    else
      response.result
  sendStockToMagento: (job) ->
    # moysklad
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    tools = moyskladPackage.tools
    metadataUuid = findMetadataUuidByName('GoodFolder', "Отсутствует у поставщика")

    # magento
    liveParams = {
      user: 'zup_user',
      pass: 'zup_user',
      url: 'http://allshellac.ru/index.php/api/V2_soap?wsdl=1'
    }
    paramsToUse = liveParams;
    client = Soap.createClient(paramsToUse.url);
    client.setSecurity(new Soap.BasicAuthSecurity(paramsToUse.user, paramsToUse.pass));
    result = client.login({username: paramsToUse.user, apiKey:paramsToUse.pass});
    session = result.loginReturn.$value;
    if not result.loginReturn.$value?
      throw new Error "Не получилось залогиниться в Magento"

    allDirtyGoods = Goods.find({dirty: true})
    console.log "Найдено #{allDirtyGoods.count()} остатков для отправки, начинаем отправку"

    for good in allDirtyGoods.fetch()
      if good.stockQty?
        if good.stockQty > 0
          inStockStatus = "В наличии, отправим сегодня"
          shipmentStatus = "Товар в наличии на нашем складе, отправим сегодня или завтра утром"
          isInStock = 1
          stockQty = 9999 #good.stockQty
      if (not good.stockQty? or good.stockQty <= 0)
        outOfStockInSupplier = tools.getAttrValue(good, metadataUuid)
        #console.log "Отсутствует у поставщика: #{outOfStockInSupplier}"
        if outOfStockInSupplier?
          inStockStatus = "Временно нет в продаже"
          shipmentStatus = "Отправка возможна после появления в продаже. Когда товар появится - пока не известно."
          isInStock = 0
          stockQty = 0
        else
          inStockStatus = "В наличии, отправим в течение 1-3 дней"
          shipmentStatus = "Товар в наличии, находится на складе поставщика, отправим в течение 1-3х рабочих дней"
          isInStock = 1
          stockQty = 999

      if skipGoodStock good
        stockQty = 9999
        isInStock = 1
        inStockStatus = "В наличии, отправим сегодня"
        shipmentStatus = "Товар в наличии на нашем складе, отправим сегодня или завтра утром"

      console.log "Товар: #{good.productCode}, кол-во #{good.stockQty} наличие: #{inStockStatus}, отгрузка: #{shipmentStatus}"

      # send to magento
      request = {}
      request.sessionId = session
      request.storeView = "smmarket"
      request.identifierType = "sku"
      request.product = good.productCode
      request.productData = {
        additional_attributes: {
          single_data: {
            associativeEntity: [
              { key: "instock_desc", value: inStockStatus}
              { key: "shipment_desc", value: shipmentStatus}
            ]
          }
        }
        stock_data: {
          qty: stockQty
          is_in_stock: isInStock
        }
      }

      Goods.update({uuid: good.uuid}, {$set: {dirty: false}})

      #console.log "Request: #{objToString request}, #{objToString request.productData}"
      response = client.catalogProductUpdate request
      #console.log "Response: #{objToString response}"
      #console.log "Response: #{client.lastRequest}"

    client.endSession session
    return "Остатки отправлены в Мадженто: #{allDirtyGoods.count()} всего"
  loadAllEntities: () ->
    console.log "loadAllEntities started"
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'good', 'Goods'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'company', 'Companies'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customerOrder', 'Orders'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'workflow', 'Workflows'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customEntityMetadata', 'CustomEntityMetadata'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customEntity', 'CustomEntity'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'embeddedEntityMetadata', 'EmbeddedEntityMetadata'
    # Meteor.call 'loadTracksFromAplix', getLastTimeRun 'aplix_tracks', (error, result) ->
    #   if not error?
    #     Meteor.call 'updateTimestampFlag', 'aplix_tracks'
    console.log "loadAllEntities ended"
