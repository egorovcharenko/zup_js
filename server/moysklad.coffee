getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then moment(lastTimeLoaded.value).subtract(2, 'seconds') else moment('2014-01-01')

@findMetadataUuidByName = (entityName, attrName) ->
  #console.log("findMetadataUuidByName: entityName:" + entityName + ", attrName: " + attrName);
  embEntityMetadata = EmbeddedEntityMetadata.findOne {name: entityName}
  #console.log("embEntityMetadata: " + objToString(embEntityMetadata));
  result = undefined
  _.every embEntityMetadata.attributeMetadata, (attr) ->
    #console.log("--attributeMetadata: " + objToString(attr));
    if attr.name == attrName
      result = attr.uuid
      return false
    return true
  return result

objToString = (obj) ->
  str = ''
  for p of obj
    if obj.hasOwnProperty(p)
      str += p + '::' + obj[p] + '\n'
  str

logChangesInDescription = (entityFromMS, field, oldv, newv) ->
  return
  if entityFromMS.hasOwnProperty('description')
    entityFromMS.description += "\n-------------\n#{moment().format('DD.MM.YY [в] HH:mm')} через приложение изменено поле '#{field}', со значения '#{(if oldv then oldv else '(пусто)')}' на '#{(if newv then newv else '(пусто)')}'"

Meteor.methods
  getMSAttributeValue: (object, attribs) ->
    res = {}
    for attr in attribs
      metadataUuid = findMetadataUuidByName(attr.entityName, attr.attrName)
      res[attr.attrName] = tools.getAttr(object, metadataUuid)
    return res

  addNalogenPaymentMethod: (orderName) ->
    entityFromMS = client.load("customerOrder", Orders.findOne(name:orderName).uuid)

    nalogPlatUuid = '82c43187-4743-11e5-90a2-8ecb001a04c5'
    nalogPlatPercent = 0.04;
    nalogPlatPrice = (Math.ceil (entityFromMS.sum.sum * nalogPlatPercent / 100)) * 100

    entityFromMS.customerOrderPosition.push {
      "TYPE_NAME" : "moysklad.customerOrderPosition",
      "discount" : 0,
      "quantity" : 1,
      "goodUuid" : nalogPlatUuid,
      "vat" : 0,
      "groupUuid" : entityFromMS.groupUuid,
      "ownerUid" : "admin@allshellac",
      "shared" : false,
      "basePrice" : {
        "TYPE_NAME" : "moysklad.moneyAmount",
        "sum" : nalogPlatPrice,
        "sumInCurrency" : nalogPlatPrice
      },
      "price" : {
        "TYPE_NAME" : "moysklad.moneyAmount",
        "sum" : nalogPlatPrice,
        "sumInCurrency" : nalogPlatPrice
      },
      "reserve" : 0
    }
    newEntity = client.save(entityFromMS)

  updateEntityMS: (entityType, entityUuid, data, attributes) ->
    #console.log 'updateEntityMS started, parameters:' + arguments
    entityFromMS = client.load(entityType, entityUuid)
    if data?
      for prop of data
        if data.hasOwnProperty(prop)
          entityFromMS[prop] = data[prop]
    # update attribs
    _.each attributes, (attrib) ->
      metadataUuid = findMetadataUuidByName('CustomerOrder', attrib.name)
      if not metadataUuid?
        throw new Meteor.Error "Не нашли нужный атрибут", "attrib-not-found"
      #console.log "metadataUuid: #{metadataUuid}"
      test = tools.getAttr(entityFromMS, metadataUuid)
      switch attrib.type
        when 'string'
          oldValue = test.valueString
          test.valueString = attrib.value
        when 'employee'
          oldValue = test.employeeValueUuid
          test.employeeValueUuid = attrib.value
        when 'picklist'
          oldValue = test.metadataUuid
          test.entityValueUuid = attrib.value
      #console.log "test:", test
      #logChangesInDescription entityFromMS, attrib.name, oldValue, attrib.value
      return
    #console.log "entity:", entityFromMS
    newEntity = client.save(entityFromMS)

  setEntityStateByUuid: (entityType, entityUuid, newStateUuid) ->
    if entityType is "customerOrder"
      # добавить действие по переводу в др. статус
      Orders.update {uuid: entityUuid}, {$push: {actions: {type:"stateChange", date: new Date()}}}
      entityFromMS = client.load(entityType, entityUuid)
      stateWorkflow = Workflows.findOne name:"CustomerOrder"
      if stateWorkflow
        oldStateName = (_.find stateWorkflow.state, (state) -> state.uuid is entityFromMS.stateUuid).name
        newStateName = (_.find stateWorkflow.state, (state) -> state.uuid is newStateUuid).name
        entityFromMS.stateUuid = newStateUuid
        result = client.save(entityFromMS)

  loadEntityGenericMethod: (entityMSName, collectionName) ->
    currentTime = Date.now()
    #Meteor.call "logSystemEvent", "loadEntityGeneric", "5. notice", "Вызов загрузки сущностей: entityMSName: #{entityMSName}"
    Meteor.call 'loadEntityFromMS', entityMSName, collectionName, getLastTimeRun(entityMSName), (error, result) ->
      if not error?
        Meteor.call 'updateTimestampFlag', entityMSName, currentTime
      else
        console.log "ошибка в loadEntityGenericMethod:", error
        #Meteor.call "logSystemEvent", "loadEntityGeneric", "2. error", "Ошибка: #{error.reason}"

  loadStockFromMS: () ->
    # очищаем список составных товаров
    #CompoundGoods.remove({})
    console.log "Начинаем загружать отстатки с сервера"

    options = {
      stockMode: ALL_STOCK,
      storeId: '8de95654-65fe-11e4-90a2-8ecb00148413',
      showConsignments: false
    }
    try
      stock = client.stock(options);
    catch error
      console.log "Ошибка при загрузке остатков с сервера:", error
    console.log "Получили остатки: #{JSON.stringify(stock,null,1)}", 

    countUpdated = 0
    if stock?
      console.log "Получено с сервера #{stock.length} остатков"
      _.each stock, (oneStock) ->
        try
          if oneStock.goodRef?
            good = Goods.findOne uuid:oneStock.goodRef.uuid
            if good?
              # устанавливаем реальное наличие наличия
              if (good.name.lastIndexOf("Доставка", 0) == 0) or (good.name.lastIndexOf("Наложенный платеж", 0) == 0)
                if good.outOfStockInSupplier?
                  if good.outOfStockInSupplier
                    realAvailableQty = oneStock.quantity
                  else
                    realAvailableQty = 100
                else
                  realAvailableQty = 100
              else
                realAvailableQty = oneStock.quantity
              # если товар составной - то определить его доступное количество как минимальное из всех составных частей
              plan = ProcessingPlans.findOne({"product.goodUuid":good.uuid, "parentUuid": { $ne: "5283123e-7334-11e4-90a2-8ecb0012dbc6" }})
              if plan?
                materials = ""
                #console.log "--#{plan.name}"
                minMaterialQty = 99999
                _.each plan.material, (material) ->
                  materialGood = Goods.findOne {uuid: material.goodUuid}
                  if materialGood?
                    # для каждого составляющего - добавить его в закупку в нужном количестве
                    materials += "#{materialGood.name}: #{materialGood.realAvailableQty}<br/>"
                    minMaterialQty = Math.min(minMaterialQty, materialGood.realAvailableQty / material.quantity / plan.product[0].quantity)
                realAvailableQty += Math.max(minMaterialQty, 0)
                CompoundGoods.upsert {name: good.name, plan: plan.name}, {$set: {materials: materials, minQty: minMaterialQty}}
              if good.realAvailableQty is realAvailableQty
                needsUpdate = false
              else
                needsUpdate = true
              Goods.update({uuid: oneStock.goodRef.uuid}, {$set: {stockQty: oneStock.stock, reserveQty: oneStock.reserve, quantityQty: oneStock.quantity, reserveForSelectedAgentQty: oneStock.reserveForSelectedAgent, realAvailableQty: realAvailableQty, dirty: needsUpdate}})
            else
              ;#Meteor.call "logSystemEvent", "loadStock", "5. notice", "При загрузке остатков не нашли товар: #{oneStock.goodRef.name}"
          else
            ;#Meteor.call "logSystemEvent", "loadStock", "5. notice", "В остатках нет информации о товаре"
        catch error
          console.log "error:", error
      #Meteor.call "logSystemEvent", "loadStock", "5. notice", "Остатки загружены успешно, количество: #{stock.length}, обновлено: #{countUpdated}"

  loadNotPrimaryEntities: () ->
    try
      Meteor.call 'loadEntityGenericMethod', 'customEntityMetadata', 'CustomEntityMetadata'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'customEntity', 'CustomEntity'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'service', 'Services'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'good', 'Goods'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'workflow', 'Workflows'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'embeddedEntityMetadata', 'EmbeddedEntityMetadata'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'PurchaseOrder', 'PurchaseOrders'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'Employee', 'Employees'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'ProcessingPlan', 'ProcessingPlans'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'Processing', 'Processings'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'Demand', 'Demands'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'Supply', 'Supplies'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'Loss', 'Losses'
      Meteor._sleepForMs(300);
      Meteor.call 'loadEntityGenericMethod', 'Enter', 'Enters'
      Meteor._sleepForMs(300);
    catch error
      console.log "error in loadNotPrimaryEntities:", error

  loadAllEntities: () ->
    #console.log "loadAllEntities started"
    Meteor.call 'loadEntityGenericMethod', 'company', 'Companies'
    Meteor._sleepForMs(300);
    Meteor.call 'loadEntityGenericMethod', 'customerOrder', 'Orders'
    Meteor._sleepForMs(300);
    #console.log "loadAllEntities ended"
  closeOrdersInMS: () ->
    console.log "closeOrdersInMS начата"
    # ищем все заказы в статусе "Доставлен"
    i = 0
    CompletedOrderIDs = OrderAplixStatuses.find({"Status.Name": "Доставлен"}).fetch()

    # подготовка переменных
    stateWorkflow = Workflows.findOne name:"CustomerOrder"
    newStateUuid = (_.find stateWorkflow.state, (state) -> state.name is "Выполнен").uuid

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
      catch error
        console.log "Ошибка:", error
    console.log "closeOrdersInMS завершена"
