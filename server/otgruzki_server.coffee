Meteor.methods
  otgruzitZakaz: (orderUuid) ->
    order = Orders.findOne {uuid:orderUuid}
    console.log "Начали отгружать заказ #{order.name}"

    # проверить чтобы отгрузок не было уже
    existingDemand = Demands.findOne {customerOrderUuid: orderUuid, applicable: true}
    if existingDemand?
      console.log "Отгрузка для данного заказа уже создана:", existingDemand.name
      throw new Meteor.Error "stock-exists", "Отгрузка для данного заказа уже создана"

    demand = {
      "TYPE_NAME" : "moysklad.demand",
      "customerOrderUuid" : orderUuid,
      "targetAgentUuid" : order.sourceAgentUuid,
      "sourceAgentUuid" : order.targetAgentUuid,
      "sourceStoreUuid" : order.sourceStoreUuid,
      "applicable" : true,
      "moment" : new Date(),
      "targetAccountUuid" : order.sourceAccountUuid,
      "sourceAccountUuid" : order.targetAccountUuid,
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
      #console.log " pos:", pos.uuid
      good = Goods.findOne {uuid: pos.goodUuid}
      if good?
        if good.name is "Наложенный платеж"
          ;#skip
        else
          #console.log "  good found: #{good.name}, good.stockQty: #{good.stockQty}, pos.quantity:#{pos.quantity}"
          if pos.quantity > good.stockQty
            # Для тех которые не в наличии - найти техкарту
            solved = false
            "start searching ProcessingPlans"
            _.each (ProcessingPlans.find({"product.goodUuid":good.uuid, "parentUuid": { $ne: "5283123e-7334-11e4-90a2-8ecb0012dbc6" }})).fetch(), (plan) ->
              qtyNeeded = pos.quantity - good.stockQty
              qtyMultiplier = Math.ceil(qtyNeeded / plan.product[0].quantity)
              #console.log "   plan found: #{plan.name}, qtyNeeded:#{qtyNeeded}, qtyMultiplier:#{qtyMultiplier}"
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
                #console.log "    material: #{material.goodUuid}"
                materialGood = Goods.findOne {uuid: material.goodUuid}
                if materialGood?
                  qtyOfMaterialNeeded = qtyNeeded * material.quantity
                  #console.log "    materialGood: #{materialGood.name}, qtyOfMaterialNeeded:#{qtyOfMaterialNeeded}"
                  if materialGood.stockQtiy < qtyNeeded
                    throw new Meteor.Error "stock-insufficient", "При отгрузке через техкарту произошла ошибка - не достаточно товара #{materialGood.name}, нужно #{qtyOfMaterialNeeded}, а в наличии только #{materialGood.stockQty}"
                  else
                    #console.log "processing.material:", processing.material
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
                #console.log "processing.results:", processing.results
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
              result = client.save(processing)
              #console.log "     client.save(processing): #{result}"
              solved = true
            if not solved
              # ошибка - не хватает товара в наличии
              #throw new Meteor.Error "stock-insufficient", "При отгрузке произошла ошибка - не достаточно товара #{good.name}, нужно #{pos.quantity}, а в наличии только #{good.stockQty}"
              # оприходовать нужное количество товара
              Meteor.call "addNewEnter", [{uuid:good.uuid, qty: pos.quantity - good.stockQty, buyPrice: good.buyPrice}]

          #console.log "demand.shipmentOut:", demand.shipmentOut
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
        #console.log "   service:#{service.name}"
        if service?
          if service.name is "Доставка заказа"
            deliveryPriceActual = pos.price.sum + 50*100 + order.sum.sum * 0.02 # инкассация - 2%
            deliveryPriceRounded = ((Math.ceil(deliveryPriceActual / (50*100)) * 50*100)/100).toFixed(0)
            deliveryName = "Доставка #{deliveryPriceRounded}"
            #console.log "deliveryName:#{deliveryName}"
            deliveryGood = Goods.findOne({name: deliveryName})
            if deliveryGood?
              #console.log "demand.shipmentOut:", demand.shipmentOut
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
              # создать приемку для нужной доставки
              Meteor.call "addNewEnter", [{uuid:deliveryGood.uuid, qty: 1, buyPrice: deliveryPriceRounded * 100}]
              #throw new Meteor.Error "stock-insufficient", "Не достаточное количество доставки с именем: #{deliveryName}"
    result = client.save(demand)
    console.log "Успешно отгрузили заказ"
    return "Успешно отгрузили заказ"
