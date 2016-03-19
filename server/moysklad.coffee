getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then new Date(lastTimeLoaded.value) else '01-01-2014'

@findMetadataUuidByName = (entityName, attrName) ->
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
  getMSAttributeValue: (object, attribs) ->
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    tools = moyskladPackage.tools
    res = {}
    for attr in attribs
      metadataUuid = findMetadataUuidByName(attr.entityName, attr.attrName)
      res[attr.attrName] = tools.getAttr(object, metadataUuid)
    return res

  updateEntityMS: (entityType, entityUuid, data, attributes, attributeType) ->
    #console.log 'updateEntityMS started, parameters:' + arguments
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'
      #console.log 'entityType: ' + entityType + ', entityUuid: ' + entityUuid
      entityFromMS = client.load(entityType, entityUuid)
      #console.log 'entityFromMS: ' + entityFromMS
      #console.log 'data:' + data
      if data?
        for prop of data
          if data.hasOwnProperty(prop)
            #console.log '-property ' + prop
            entityFromMS[prop] = data[prop]
      #console.log entityFromMSAfter1: entityFromMS
      # update attribs
      _.each attributes, (attrib) ->
        # {name: value}
        #console.log 'attrib: ', JSON.stringify(attrib, null, 4)
        metadataUuid = findMetadataUuidByName('CustomerOrder', attrib.name)
        #console.log 'metadataUuid: ' + metadataUuid
        #console.log 'entityFromMSBeforeGettingAttrib:', entityFromMS.attribute.length
        test = tools.getAttr(entityFromMS, metadataUuid)
        #console.log 'test: ', JSON.stringify(test, null, 4)
        #console.log 'entityFromMSAfterGettingAttrib:', entityFromMS.attribute.length
        switch attributeType
          when 'string'
            oldValue = test.valueString
            test.valueString = attrib.value
          when 'employee'
            oldValue = test.employeeValueUuid
            test.employeeValueUuid = attrib.value
        #console.log 'entityFromMSAfterSettingAttrib:', entityFromMS.attribute.length
        #console.log 'new value: ' + tools.getAttrValue(entityFromMS, metadataUuid)
        logChangesInDescription entityFromMS, attrib.name, oldValue, attrib.value
        return
      #console.log entityFromMSAfter2: entityFromMS
      newEntity = client.save(entityFromMS)
      #console.log 'newEntity: ', newEntity
      done null, "Заменено"
    )
    #console.log 'updateEntityMS ended'
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
    currentTime = Date.now()
    Meteor.call "logSystemEvent", "loadEntityGeneric", "5. notice", "Вызов загрузки сущностей: entityMSName: #{entityMSName}"
    Meteor.call 'loadEntityFromMS', entityMSName, collectionName, getLastTimeRun(entityMSName), (error, result) ->
      if not error?
        Meteor.call 'updateTimestampFlag', entityMSName, currentTime
      else
        Meteor.call "logSystemEvent", "loadEntityGeneric", "2. error", "Ошибка: #{error}"

  loadStockFromMS: () ->
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      try
        Meteor.call "logSystemEvent", "loadStock", "5. notice", "Начинаем получение с сервера всех остатков"

        client = moyskladPackage.createClient()
        client.setAuth 'admin@allshellac', 'qweasd'
        options = {
          #stockMode: ALL_STOCK,
          showConsignments: false
        };

        stock = client.stock(options);
        if stock?
          Meteor.call "logSystemEvent", "loadStock", "5. notice", "Получено с сервера #{stock.length} остатков"
          for oneStock in stock
            Meteor.call "logSystemEvent", "loadStock", "5. notice", "Остаток: #{oneStock}"
            if oneStock.goodRef?
              good = Goods.findOne uuid:oneStock.goodRef.uuid
              if good?
                # пропускаем товары
                if (skipGoodStock good)
                  # do nothing
                else
                  needsUpdate = false
                  if good.stockQty?
                    if good.stockQty != oneStock.stock
                      needsUpdate = true
                  else if good.reserveQty?
                    if good.reserveQty != oneStock.reserve
                      needsUpdate = true
                  else if good.quantityQty?
                    if good.quantityQty != oneStock.quantity
                      needsUpdate = true
                  else if good.reserveForSelectedAgentQty?
                    if good.reserveForSelectedAgentQty != oneStock.reserveForSelectedAgent
                      needsUpdate = true
                  else
                    needsUpdate = true
                  if needsUpdate
                    Goods.update({uuid: oneStock.goodRef.uuid}, {$set: {stockQty: oneStock.stock, reserveQty: oneStock.reserve, quantityQty: oneStock.quantity, reserveForSelectedAgentQty:oneStock.reserveForSelectedAgent, dirty: true}})
                  #console.log "Установлен остаток для товара #{oneStock.goodRef.name} - #{good.stockQty} штук"
              else
                Meteor.call "logSystemEvent", "loadStock", "5. notice", "При загрузке остатков не нашли товар: #{oneStock.goodRef.name}"
            else
              Meteor.call "logSystemEvent", "loadStock", "5. notice", "В остатках нет информации о товаре"
          done null, "Остатки загружены успешно, количество: #{stock.length}"
        else
          done "Не получены остатки с сервера", null
      catch error
        done error, null
    )
    if response.error?
      Meteor.call "logSystemEvent", "loadStock", "2. error", "Ошибка: #{error}"
      throw error
    else
      response.result
  sendStockToMagento: (job) ->
    # moysklad
    #moyskladPackage = Meteor.npmRequire('moysklad-client')
    #tools = moyskladPackage.tools
    #metadataUuid = findMetadataUuidByName('GoodFolder', "Отсутствует у поставщика")

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
        outOfStockInSupplier = good.outOfStockInSupplier #tools.getAttrValue(good, metadataUuid)
        if outOfStockInSupplier
          console.log "Флаг 'отсутствует у поставщика' у товара '#{good.name}': #{outOfStockInSupplier}"
          inStockStatus = "Временно нет в продаже"
          shipmentStatus = "Отправка возможна после появления в продаже. Когда товар появится - пока не известно."
          isInStock = 0
          stockQty = 0
        else
          inStockStatus = "В наличии, отправим за 4 дня"
          shipmentStatus = "Товар в наличии, находится на складе поставщика, отправим в течение 4х рабочих дней"
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

  loadNotPrimaryEntities: () ->
    Meteor.call 'loadEntityGenericMethod', 'customEntityMetadata', 'CustomEntityMetadata'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customEntity', 'CustomEntity'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'good', 'Goods'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'workflow', 'Workflows'
    Meteor._sleepForMs(1000);

  loadAllEntities: () ->
    #console.log "loadAllEntities started"
    #Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'company', 'Companies'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customerOrder', 'Orders'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'embeddedEntityMetadata', 'EmbeddedEntityMetadata'
    Meteor._sleepForMs(1000);
    # Meteor.call 'loadTracksFromAplix', getLastTimeRun 'aplix_tracks', (error, result) ->
    #   if not error?
    #     Meteor.call 'updateTimestampFlag', 'aplix_tracks'
    console.log "loadAllEntities ended"
  closeOrdersInMS: () ->
    console.log "closeOrdersInMS начата"
    # ищем все заказы в статусе "Доставлен"
    i = 0
    CompletedOrderIDs = OrderAplixStatuses.find({"Status.Name": "Доставлен"}).fetch()

    # подготовка переменных
    stateWorkflow = Workflows.findOne name:"CustomerOrder"
    newStateUuid = (_.find stateWorkflow.state, (state) -> state.name is "Выполнен").uuid
    newStateUuid = (_.find stateWorkflow.state, (state) -> state.name is "Выполнен").uuid
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    client = moyskladPackage.createClient()
    tools = moyskladPackage.tools
    client.setAuth 'admin@allshellac', 'qweasd'

    for completedOrderID in CompletedOrderIDs
      #if i > 50
      #  break
      i++
      try
        # Передавали его в МС?
        order = Orders.findOne({name: completedOrderID.OrderID})
        if not order?
          throw new Meteor.Error 500, "Не найден заказ с id:#{completedOrderID.OrderID}"
        console.log "Найден заказ:", order.name
        # если нет, проверить, какой у него статус в МС
        msState = null
        temp = alasql('SEARCH /WHERE(name="CustomerOrder")//WHERE(uuid="' + order.stateUuid + '") FROM ?', [ Workflows ])[0]
        if temp?
          msState = temp.name
        if not msState
          throw new Meteor.Error 500, "Не найден статус заказа с id:#{completedOrderID.OrderID}"
        #console.log "msState:", msState
        # если не Выполнен, то
        if msState != "Выполнен"
          # вычислить сумму входящего платежа, вычтя сумму за обработку Апликсом, и указать ее в комментарии к заказу?
          sum = 0
          desc = "\n=== Информация об оплате за доставку Апликсу ниже"
          billingForThisOrder = OrderAplixBilling.find({ExtNumber: order.name}).fetch()
          if billingForThisOrder.length?
            for billing in billingForThisOrder
              sum += parseInt(billing.Amount)
              desc += "\nПлата Апликс: #{billing.Amount}р за #{billing.Service}"
          desc += "\n=== Итого: #{sum}р"

          if sum > 0
            console.log "Вычислены параметры, сумма: #{sum}"

            # создать входящий платеж
            newPaymentIn = {
              customerOrderUuid: order.uuid
              incomingNumber: ""
              vatSum: 0.0
              targetAgentUuid: order.targetAgentUuid
              sourceAgentUuid: order.sourceAgentUuid
              applicable: true
              moment: completedOrderID.Date
              targetAccountUuid: order.targetAccountUuid
              sourceAccountUuid: order.sourceAccountUuid
              #payerVat: "true"
              rate: 1.0
              #vatIncluded: "true"
              #name: "0504"
              accountUuid: order.accountUuid
              accountId: order.accountId
              groupUuid: order.groupUuid
              sum: {
                sum: order.sum.sum - sum * 100
                sumInCurrency: order.sum.sum - sum * 100
              }
            }

            response = Async.runSync((done) ->
              try
                # отправить входящий платеж в МС
                entityFromMS = client.save("paymentIn", newPaymentIn)

                # изменить статус заказа и его описание в МC
                order.stateUuid = newStateUuid
                if order.description?
                  order.description += desc
                else
                  order.description = desc
                resp = client.save("customerOrder", order)
                console.log "Создание платежа и обновление заказа завершено"
                done(null, null);
              catch e
                console.log "ошибка внутри runSync:", e
                done(null, null);
            )
      catch error
        console.log "Ошибка:", error
    console.log "closeOrdersInMS завершена"
