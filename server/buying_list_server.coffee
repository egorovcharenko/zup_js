Meteor.methods
  calculateBuyingQty: (dataObject) ->
    console.log "Начинаем подсчитывать товары в закупку"
    try
      # сбросить количества на закупку
      Goods.update {}, {$unset: {perWeekQtyNeeded: "", boughtOnLastPeriodsQty:"", boughtOnLastPeriodsOrders:"", includeInNextStockBuyingQty: "", includeInNextBuyingQty: "", ordersForBuy: ""}}, multi: true
      # подсчитать кол-ва на закупку заново
      _.each OrderStatuses.find({buyGoodsInThisState: true}).fetch(), (state) ->
        #console.log "start processing state: ", state.name
        orders = Orders.find({stateUuid: state.uuid}).fetch()
        #console.log "found orders:", orders.length
        _.each orders, (order) ->
          #console.log "start processing order: ", order.name
          _.each order.customerOrderPosition, (pos) ->
            #console.log "start processing pos: ", pos.goodUuid
            good = Goods.findOne {uuid: pos.goodUuid}
            if good?
              if not (good.name is "Наложенный платеж")
                if good.includeInNextBuyingQty?
                  oldInclQty = good.includeInNextBuyingQty
                else
                  if good.realAvailableQty?
                    oldInclQty = -good.realAvailableQty
                qtyToOrder = pos.quantity + oldInclQty
                Goods.update {uuid: good.uuid}, {$set: {includeInNextBuyingQty: qtyToOrder}, $push: {ordersForBuy: {name: order.name, state: state.name, qty: pos.quantity}}}
      # закупка про запас
      # пройтись по всем отгрузкам за x недель
      weekToAnalyze = 12
      minNumberOfOtgruzhenoQty = 3
      minNumberOfOrders = 2
      maxPriceToIncNumber = 100
      incNumberMinQty = 4
      maxQtyToConsider = 5 # не считаем, если в одном заказе больше данного количества товара
      date = new Date (moment().subtract(weekToAnalyze, 'weeks').toISOString())
      console.log "date:#{date}"
      _.each Demands.find({created: {$gte: date}, applicable: true}).fetch(), (demand) ->
        _.each demand.shipmentOut, (shipmentOut) ->
          # обновить товары, установить кол-во заказов, кол-во отгрузок
          Goods.update {uuid: shipmentOut.goodUuid}, {$inc: {boughtOnLastPeriodsQty: Math.min(shipmentOut.quantity, maxQtyToConsider), boughtOnLastPeriodsOrders: 1}}
      goodsNum = Goods.find({boughtOnLastPeriodsQty: {$gte: minNumberOfOtgruzhenoQty}, boughtOnLastPeriodsOrders: {$gte: minNumberOfOrders}}).count()
      console.log "goods ready for stock buying: #{goodsNum}"
      # по каждому товару пройтись
      _.each Goods.find({boughtOnLastPeriodsQty: {$gte: minNumberOfOtgruzhenoQty}, boughtOnLastPeriodsOrders: {$gte: minNumberOfOrders}}).fetch(), (good) ->
        # если количество заказов больше 2х и кол-во отгрузок шт больше 3х, то вычисляем кол-во про запас
        # прогноз на следующий месяц минус доступное кол-во
        if not (good.name.lastIndexOf("Доставка", 0) == 0)
          perWeekQtyNeeded = good.boughtOnLastPeriodsQty / weekToAnalyze
          if perWeekQtyNeeded > 0
            # проверяем на сборность - может это набор?
            plan = ProcessingPlans.findOne({"product.goodUuid":good.uuid, "parentUuid": { $ne: "5283123e-7334-11e4-90a2-8ecb0012dbc6" }})
            if plan?
              _.each plan.material, (material) ->
                # для каждого составляющего - добавить его в закупку в нужном количестве
                qtyOfMaterialNeeded = (material.quantity / plan.product[0].quantity) * perWeekQtyNeeded
                #materialGood = Goods.findOne {uuid: material.goodUuid}
                Goods.update {uuid: material.goodUuid}, {$inc: {perWeekQtyNeeded: qtyOfMaterialNeeded}}
            else
              Goods.update {uuid: good.uuid}, {$inc: {perWeekQtyNeeded: perWeekQtyNeeded}}
      #moyskladPackage = Meteor.npmRequire('moysklad-client')
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'

      # находим статус нужный
      wf = Workflows.findOne {code: "PurchaseOrder"}
      activeStateUuid = _.find(wf.state, (state) -> state.name == "Требуется закупка").uuid

      # пройтись по списку поставщиков
      _.each Companies.find({ tags: $in: [ 'поставщики' ] }).fetch(), (supplier) ->
        #console.log "Обрабатываем поставщика #{supplier.name}.."
        # найти заказ на закупку в статусе. если нет - создать его
        #console.log "stateUuid:#{activeStateUuid}, supplier.uuid:#{supplier.uuid}"
        activePurchaseOrder1 = PurchaseOrders.findOne {stateUuid: activeStateUuid, sourceAgentUuid: supplier.uuid, applicable: true}
        if activePurchaseOrder1?
          console.log "найден старый заказ на закупку"
          # удалить старый заказ
          #delResult = HTTP.del('https://online.moysklad.ru/exchange/rest/ms/xml/purchaseOrder/' + activePurchaseOrder1.uuid, {auth:"admin@allshellac:qweasd"} )
          #console.log "delete result:", delResult
        else
          activePurchaseOrder1 = {
            "TYPE_NAME" : "moysklad.purchaseOrder",
            "reservedSum" : 0,
            "stateUuid" : activeStateUuid,
            "sourceAgentUuid" : supplier.uuid,
            "applicable" : true,
            "targetAccountUuid" : "8de83912-65fe-11e4-90a2-8ecb00148412",
            "payerVat" : true,
            "rate" : 1,
            "vatIncluded" : true,
            "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
            "ownerUid" : "admin@allshellac",
            "shared" : false,
            "purchaseOrderPosition": []
          }
        activePurchaseOrder1.created = new Date()
        activePurchaseOrder1.purchaseOrderPosition = []
        d = new Date()
        # закупка про запас
        podZapasMetadata = _.find(supplier.attribute, (attr) -> attr.metadataUuid == "2f32d58a-f3f9-11e5-7a69-97150029d009")
        if podZapasMetadata?
          podZapasString = podZapasMetadata.valueString
          #console.log "podZapasString:#{podZapasString}, d:#{d}"
          #console.log "test: #{later.schedule(later.parse.text(podZapasString)).next(5)}"
          if later.schedule(later.parse.text(podZapasString)).isValid(d) or dataObject.forceBuying?
            console.log "today is the day!"
            weekToBuyInAdvanceMetadata = _.find(supplier.attribute, (attr) -> attr.metadataUuid == "c5723e59-f3f7-11e5-7a69-970d0029005d")
            if weekToBuyInAdvanceMetadata?
              weekToBuyInAdvance = weekToBuyInAdvanceMetadata.longValue
            if not weekToBuyInAdvance?
              console.log "У поставщика #{supplier.name} не заполнен период, на сколько закупать"
              return # пропускаем поставщика
            # пройтись по списку товаров этого поставщика в списке на закупку
            _.each Goods.find({perWeekQtyNeeded: {$gt: 0}, supplierUuid: supplier.uuid}).fetch(), (good) ->
              totalQtyNeeded = (good.perWeekQtyNeeded * weekToBuyInAdvance) - good.realAvailableQty
              if totalQtyNeeded > 0
                console.log "good:#{good.name}, perWeekQtyNeeded:#{good.perWeekQtyNeeded}, good.realAvailableQty: #{good.realAvailableQty}, totalQtyNeeded:#{totalQtyNeeded}"
                # если товар дешевле 100р, то сразу покупаем минимум 5 штук
                if good.buyPrice < maxPriceToIncNumber * 100 # копейки
                  totalQtyNeeded = Math.max(totalQtyNeeded, incNumberMinQty)
                if (good.name.lastIndexOf("Гель-лак Bluesky Shellac", 0) == 0)
                  totalQtyNeeded = Math.ceil(totalQtyNeeded / 8) * 8
                else if (good.name.lastIndexOf("Гель-лак TNL", 0) == 0)
                  totalQtyNeeded = Math.ceil(totalQtyNeeded / 4) * 4
                else if (good.name.lastIndexOf("Пилка", 0) == 0)
                  totalQtyNeeded = Math.ceil(totalQtyNeeded / 10) * 10

                purchaseOrderPosition = {
                  "TYPE_NAME" : "moysklad.purchaseOrderPosition",
                  "quantity" : Math.ceil(totalQtyNeeded),
                  "goodUuid" : good.uuid,
                  "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
                  "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
                  "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
                  "ownerUid" : "admin@allshellac",
                  "shared" : false,
                  "basePrice" : {
                    "TYPE_NAME" : "moysklad.moneyAmount",
                    "sum" : good.buyPrice,
                    "sumInCurrency" : good.buyPrice
                    },
                  "price" : {
                    "TYPE_NAME" : "moysklad.moneyAmount",
                    "sum" : good.buyPrice,
                    "sumInCurrency" : good.buyPrice
                    }
                }

                activePurchaseOrder1.purchaseOrderPosition.push purchaseOrderPosition
                # debug
                Goods.update {uuid: good.uuid}, {$set: {includeInNextBuyingStockQty: totalQtyNeeded}}
            #console.log "Товаров к закупке у поставщика:", activePurchaseOrder1.purchaseOrderPosition.length
            # сохранить заказ
            if activePurchaseOrder1.purchaseOrderPosition.length > 0
              try
                entityFromMS = client.save(activePurchaseOrder1)
                #console.log "Создание/обновление заказа на закупку завершено"
              catch e
                console.log "ошибка внутри runSync:", e
            else
              console.log "Пропускаем заведение заказа т.к. товаров для поставщика '#{supplier.name}' нет"

        # закупка под заказ
        activePurchaseOrder2 = PurchaseOrders.findOne {stateUuid: activeStateUuid, sourceAgentUuid: supplier.uuid, applicable: true}
        if activePurchaseOrder2?
          console.log "найден старый заказ на закупку"
          # удалить старый заказ
          #delResult = HTTP.del('https://online.moysklad.ru/exchange/rest/ms/xml/purchaseOrder/' + activePurchaseOrder2.uuid, {auth:"admin@allshellac:qweasd"} )
          #console.log "delete result:", delResult
        else
          activePurchaseOrder2 = {
            "TYPE_NAME" : "moysklad.purchaseOrder",
            "reservedSum" : 0,
            "stateUuid" : activeStateUuid,
            "sourceAgentUuid" : supplier.uuid,
            "applicable" : true,
            "targetAccountUuid" : "8de83912-65fe-11e4-90a2-8ecb00148412",
            "payerVat" : true,
            "rate" : 1,
            "vatIncluded" : true,
            "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
            "ownerUid" : "admin@allshellac",
            "shared" : false,
            "purchaseOrderPosition": []
          }
        activePurchaseOrder2.created = new Date()
        activePurchaseOrder2.purchaseOrderPosition = []
        podZakazStringMeta = _.find(supplier.attribute, (attr) -> attr.metadataUuid == "c5723a4e-f3f7-11e5-7a69-970d0029005c")
        if podZakazStringMeta?
          podZakazString = podZakazStringMeta.valueString
          if later.schedule(later.parse.text(podZakazString)).isValid(d) or dataObject.forceBuying?
            console.log "today is the day 2!"
            # пройтись по списку товаров этого поставщика в списке на закупку
            _.each Goods.find({includeInNextBuyingQty: {$gt: 0}, supplierUuid: supplier.uuid}).fetch(), (good) ->
              purchaseOrderPosition = {
                "TYPE_NAME" : "moysklad.purchaseOrderPosition",
                "quantity" : good.includeInNextBuyingQty,
                "goodUuid" : good.uuid,
                "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
                "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
                "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
                "ownerUid" : "admin@allshellac",
                "shared" : false,
                "basePrice" : {
                  "TYPE_NAME" : "moysklad.moneyAmount",
                  "sum" : good.buyPrice,
                  "sumInCurrency" : good.buyPrice
                  },
                "price" : {
                  "TYPE_NAME" : "moysklad.moneyAmount",
                  "sum" : good.buyPrice,
                  "sumInCurrency" : good.buyPrice
                  }
              }
              activePurchaseOrder2.purchaseOrderPosition.push purchaseOrderPosition
            #console.log "Товаров к закупке у поставщика:", activePurchaseOrder2.purchaseOrderPosition.length
            # сохранить заказ
            if activePurchaseOrder2.purchaseOrderPosition.length > 0
              try
                entityFromMS = client.save(activePurchaseOrder2)
                #console.log "Создание/обновление заказа на закупку завершено"
              catch e
                console.log "ошибка внутри runSync:", e
            else
              console.log "Пропускаем заведение заказа т.к. товаров для поставщика '#{supplier.name}' нет"
    catch error
      console.log "error:", error
