Meteor.methods
  otgruzitZakaz: (orderUuid) ->
    console.log "otgruzitZakaz stated"
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    client = moyskladPackage.createClient()
    tools = moyskladPackage.tools
    client.setAuth 'admin@allshellac', 'qweasd'
    order = Orders.findOne {uuid:orderUuid}

    # проверить чтобы отгрузок не было уже
    existingDemand = Demands.findOne {customerOrderUuid: orderUuid, applicable: true}
    if existingDemand?
      console.log "Отгрузка для данного заказа уже создана:", existingDemand
      throw new Meteor.Error "stock-exists", "Отгрузка для данного заказа уже создана"

    demand = {
      "TYPE_NAME" : "moysklad.demand",
      "customerOrderUuid" : orderUuid,
      "targetAgentUuid" : order.targetAgentUuid,
      "sourceAgentUuid" : order.sourceAgentUuid,
      "sourceStoreUuid" : order.sourceStoreUuid,
      "applicable" : true,
      "moment" : new Date(),
      "targetAccountUuid" : order.targetAccountUuid,
      "sourceAccountUuid" : order.sourceAccountUuid,
      "payerVat" : true,
      "rate" : 1,
      "vatIncluded" : true,
      #"name" : uuid.v4(),
      "accountUuid" : order.accountUuid,
      "accountId" : order.accountId,
      "groupUuid" : order.groupUuid,
      "ownerUid" : order.ownerUid,
      "shared" : false,
      "shipmentOut": []
    }
    # проверяем, есть ли уже отгрузка. Если есть - не делаем, ошибку возвращаем
    # Проверяем все ли товары в наличии (без учета резерва)
    _.each order.customerOrderPosition, (pos) ->
      console.log " pos:", pos.uuid
      good = Goods.findOne {uuid: pos.goodUuid}
      if good?
        if good.name is "Наложенный платеж"
          ;#skip
        else
          console.log "  good found: #{good.name}, good.stockQty: #{good.stockQty}, pos.quantity:#{pos.quantity}"
          if pos.quantity > good.stockQty
            # Для тех которые не в наличии - найти техкарту
            solved = false
            "start searching ProcessingPlans"
            _.each (ProcessingPlans.find({"product.goodUuid":good.uuid, "parentUuid": { $ne: "5283123e-7334-11e4-90a2-8ecb0012dbc6" }})).fetch(), (plan) ->
              qtyNeeded = pos.quantity - good.stockQty
              qtyMultiplier = Math.ceil(qtyNeeded / plan.product[0].quantity)
              console.log "   plan found: #{plan.name}, qtyNeeded:#{qtyNeeded}, qtyMultiplier:#{qtyMultiplier}"
              processing = {
                "TYPE_NAME" : "moysklad.processing",
                "planUuid" : plan.uuid,
                "quantity" : qtyMultiplier,
                "sourceAgentUuid" : "8de836c7-65fe-11e4-90a2-8ecb00148411",
                "targetStoreUuid" : "8de95654-65fe-11e4-90a2-8ecb00148413",
                "sourceStoreUuid" : "8de95654-65fe-11e4-90a2-8ecb00148413",
                "applicable" : true,
                "moment" : moment().subtract(5, 'minutes').toDate(),
                "payerVat" : true,
                "rate" : 1,
                "vatIncluded" : true,
                #"name" : uuid.v4(),
                "accountUuid" : order.accountUuid,
                "accountId" : order.accountId,
                "groupUuid" : order.groupUuid,
                "ownerUid" : order.ownerUid,
                "shared" : false,
                "results": [],
                "material": []
              }
              # все ли товары из тех-карты в наличии в нужном кол-ве?
              _.each plan.material, (material) ->
                console.log "    material: #{material.goodUuid}"
                materialGood = Goods.findOne {uuid: material.goodUuid}
                if materialGood?
                  qtyOfMaterialNeeded = qtyNeeded * material.quantity
                  console.log "    materialGood: #{materialGood.name}, qtyOfMaterialNeeded:#{qtyOfMaterialNeeded}"
                  if materialGood.stockQtiy < qtyNeeded
                    throw new Meteor.Error "stock-insufficient", "При отгрузке через техкарту произошла ошибка - не достаточно товара #{materialGood.name}, нужно #{qtyOfMaterialNeeded}, а в наличии только #{materialGood.stockQty}"
                  else
                    processing.material.push {
                      "TYPE_NAME" : "moysklad.processingPositionResult",
                      "discount" : 0,
                      "quantity" : material.quantity * qtyMultiplier,
                      "goodUuid" : material.goodUuid,
                      "accountUuid" : order.accountUuid,
                      "accountId" : order.accountId,
                      "groupUuid" : order.groupUuid,
                      "ownerUid" : "alina@allshellac",
                      "shared" : false,
                      "basePrice" : {
                        "TYPE_NAME" : "moysklad.moneyAmount",
                        "sum" : materialGood.buyPrice,
                        "sumInCurrency" : materialGood.buyPrice
                          },
                      "price" : {
                        "TYPE_NAME" : "moysklad.moneyAmount",
                        "sum" : materialGood.buyPrice,
                        "sumInCurrency" : materialGood.buyPrice
                      }
                    }
                else
                  console.log "     материал не найден: #{material.goodUuid}"
              # добавляем в техкарту все результаты
              _.each plan.product, (product) ->
                productGood = Goods.findOne {uuid: product.goodUuid}
                processing.results.push {
                  "TYPE_NAME" : "moysklad.product",
                  "goodUuid" : product.goodUuid,
                  "planUuid" : plan.uuid,
                  "quantity" : qtyNeeded * product.quantity,
                  "accountUuid" : order.accountUuid,
                  "accountId" : order.accountId,
                  "groupUuid" : order.groupUuid,
                  "ownerUid" : "admin@allshellac",
                  "shared" : true
                }
              # если да - создать новую тех. операцию
              response = Async.runSync (done) ->
                result = client.save(processing)
                console.log "     client.save(processing): #{result}"
                done null, "Тех операция создана"
              solved = true
            if not solved
              # ошибка - не хватает товара в наличии
              throw new Meteor.Error "stock-insufficient", "При отгрузке произошла ошибка - не достаточно товара #{good.name}, нужно #{pos.quantity}, а в наличии только #{good.stockQty}"
          demand.shipmentOut.push {
            "TYPE_NAME" : "moysklad.shipmentOut",
            "discount" : pos.discount,
            "quantity" : pos.quantity,
            "goodUuid" : good.uuid,
            "vat" : 0,
            "accountUuid" : order.accountUuid,
            "accountId" : order.accountId,
            "groupUuid" : order.groupUuid,
            "ownerUid" : "admin@allshellac",
            "shared" : false,
            "basePrice" : pos.basePrice,
            "price" : pos.price
          }
      else
        service = Services.findOne {uuid: pos.goodUuid}
        console.log "   service:#{service.name}"
        if service?
          if service.name is "Доставка заказа"
            deliveryPriceActual = pos.price.sum + 50*100 + order.sum.sum * 0.02 # инкассация - 2%
            deliveryPriceRounded = ((Math.ceil(deliveryPriceActual / (50*100)) * 50*100)/100).toFixed(0)
            deliveryName = "Доставка #{deliveryPriceRounded}"
            console.log "deliveryName:#{deliveryName}"
            deliveryGood = Goods.findOne({name: deliveryName})
            if deliveryGood?
              demand.shipmentOut.push {
                "TYPE_NAME" : "moysklad.shipmentOut",
                "discount" : 0,
                "quantity" : 1,
                "goodUuid" : deliveryGood.uuid,
                "vat" : 0,
                "accountUuid" : order.accountUuid,
                "accountId" :  order.accountId,
                "groupUuid" : order.groupUuid,
                "ownerUid" : "admin@allshellac",
                "shared" : false,
                "basePrice" : 0,
                "price" : 0
              }
            else
              throw new Meteor.Error "stock-insufficient", "Нужно завести и оприходовать доставку с названием #{deliveryName}"
            if deliveryGood.stockQty < 1
              throw new Meteor.Error "stock-insufficient", "Не достаточное количество доставки с именем: #{deliveryName}"
              # создать приемку для нужной доставки
              supply = {
                "TYPE_NAME" : "moysklad.supply",
                "incomingNumber" : "",
                "overheadDistribution" : "BY_PRICE",
                "targetAgentUuid" : "8de836c7-65fe-11e4-90a2-8ecb00148411",
                "sourceAgentUuid" : "86b78895-b208-11e4-7a40-e897000b2f2f",
                "targetStoreUuid" : "8de95654-65fe-11e4-90a2-8ecb00148413",
                "applicable" : true,
                "moment" : ISODate("2015-04-08T09:16:00Z"),
                "targetAccountUuid" : "8de83912-65fe-11e4-90a2-8ecb00148412",
                "sourceAccountUuid" : "86b78b40-b208-11e4-7a40-e897000b2f30",
                "payerVat" : true,
                "rate" : 1,
                "vatIncluded" : true,
                "created" : ISODate("2015-04-08T09:16:53.485Z"),
                "createdBy" : "kirill@allshellac",
                "name" : "00298",
                "updated" : ISODate("2015-04-08T09:16:53.474Z"),
                "updatedBy" : "kirill@allshellac",
                "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
                "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
                "uuid" : "00518cf5-ddd0-11e4-90a2-8ecb00054086",
                "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
                "ownerUid" : "kirill@allshellac",
                "shared" : false,
                "externalcode" : "eswXkAh4hob6uiUuS3kru2",
                "sum" : {
                  "TYPE_NAME" : "moysklad.moneyAmount",
                  "sum" : 680000,
                  "sumInCurrency" : 680000
                },
                "overhead" : {
                  "TYPE_NAME" : "moysklad.moneyAmount",
                  "sum" : 0,
                  "sumInCurrency" : 0
                },
                "shipmentIn" : []
              }
    response = Async.runSync (done) ->
      result = client.save(demand)
      done null, result
    console.log "demand saved, response: #{response}"
    return "Успешно отгрузили заказ"
