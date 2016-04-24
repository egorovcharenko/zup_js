# константы
weekToAnalyze = 12
minNumberOfOtgruzhenoQty = 3
minNumberOfOrders = 2
maxPriceToIncNumber = 100
incNumberMinQty = 4
maxQtyToConsider = 5 # не считаем, если в одном заказе больше данного количества товара

Meteor.methods
  calculateDemandPerWeek: () ->
    console.log "starting calculateDemandPerWeek"
    Goods.update {}, {$set: {isComplexGood: false}, $unset: {perWeekQtyNeeded: ""}}, multi: true
    # по каждому товару пройтись
    _.each Goods.find({}).fetch(), (good) ->
      # если количество заказов больше 2х и кол-во отгрузок шт больше 3х, то вычисляем кол-во про запас
      # прогноз на следующий месяц минус доступное кол-во
      if not (good.name.lastIndexOf("Доставка", 0) == 0)
        perWeekQtyNeeded = good.boughtOnLastPeriodsQty / weekToAnalyze
        if perWeekQtyNeeded > 0
          # проверяем на сборность - может это набор?
          plan = ProcessingPlans.findOne({"product.goodUuid":good.uuid, "parentUuid": { $ne: "5283123e-7334-11e4-90a2-8ecb0012dbc6" }})
          # количество обновить в любом случае
          Goods.update {uuid: good.uuid}, {$inc: {perWeekQtyNeeded: perWeekQtyNeeded}}
          if plan?
            Goods.update {uuid: good.uuid}, {$set: {isComplexGood: true}}
            _.each plan.material, (material) ->
              # для каждого составляющего - добавить его в закупку в нужном количестве
              qtyOfMaterialNeeded = (material.quantity / plan.product[0].quantity) * perWeekQtyNeeded
              Goods.update {uuid: material.goodUuid}, {$inc: {perWeekQtyNeeded: qtyOfMaterialNeeded}}
    console.log "ending calculateDemandPerWeek"

  calculateBuyingQty: (dataObject) ->
    console.log "Начинаем подсчитывать товары в закупку"
    Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Начинаем подсчитывать товары в закупку"
    # подсчитать сколько в неделю уходит
    Meteor.call "calculateDemandPerWeek"
    try
      Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "сбросить количества на закупку"
      # сбросить количества на закупку
      Goods.update {}, {$unset: {boughtOnLastPeriodsQty:"", boughtOnLastPeriodsOrders:"", includeInNextStockBuyingQty: "", includeInNextBuyingQty: "", ordersForBuy: ""}}, multi: true
      # подсчитать кол-ва на закупку заново
      _.each OrderStatuses.find({buyGoodsInThisState: true}).fetch(), (state) ->
        orders = Orders.find({stateUuid: state.uuid}).fetch()
        _.each orders, (order) ->
          _.each order.customerOrderPosition, (pos) ->
            good = Goods.findOne {uuid: pos.goodUuid}
            if good?
              if not (good.name is "Наложенный платеж")
                if good.includeInNextBuyingQty?
                  qtyToOrder = good.includeInNextBuyingQty + pos.quantity
                else
                  qtyToOrder = -good.stockQty + pos.quantity
                  Goods.update {uuid: good.uuid}, {$set: {includeInNextBuyingQty: qtyToOrder}, $push: {ordersForBuy: {name: order.name, state: state.name, qty: pos.quantity}}}
      # закупка про запас
      # пройтись по всем отгрузкам за x недель
      date = new Date (moment().subtract(weekToAnalyze, 'weeks').toISOString())
      console.log "date:#{date}"
      _.each Demands.find({created: {$gte: date}, applicable: true}).fetch(), (demand) ->
        _.each demand.shipmentOut, (shipmentOut) ->
          # обновить товары, установить кол-во заказов, кол-во отгрузок
          Goods.update {uuid: shipmentOut.goodUuid}, {$inc: {boughtOnLastPeriodsQty: Math.min(shipmentOut.quantity, maxQtyToConsider), boughtOnLastPeriodsOrders: 1}}
      goodsNum = Goods.find({boughtOnLastPeriodsQty: {$gte: minNumberOfOtgruzhenoQty}, boughtOnLastPeriodsOrders: {$gte: minNumberOfOrders}}).count()
      console.log "goods ready for stock buying: #{goodsNum}"

      # находим статус нужный
      wf = Workflows.findOne {code: "PurchaseOrder"}
      activeStateUuid = _.find(wf.state, (state) -> state.name == "Требуется закупка").uuid

      # пройтись по списку поставщиков
      _.each Companies.find({ tags: $in: [ 'поставщики' ] }).fetch(), (supplier) ->
        Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Обрабатываем поставщика #{supplier.name}, #{supplier.uuid}"
        # найти заказ на закупку в статусе. если нет - создать его
        # activePurchaseOrder1 = PurchaseOrders.findOne {stateUuid: activeStateUuid, sourceAgentUuid: supplier.uuid, applicable: true}
        # if activePurchaseOrder1?
        #   console.log "найден старый заказ на закупку"
        #   Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Нашли старый заказ для него: #{activePurchaseOrder1.name}"
          # удалить старый заказ
          #delResult = HTTP.del('https://online.moysklad.ru/exchange/rest/ms/xml/purchaseOrder/' + activePurchaseOrder1.uuid, {auth:"admin@allshellac:qweasd"} )
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
          "purchaseOrderPosition": [],
          "description": "Автозакупка про запас"
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
            Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Сегодня день закупки про запас: forceBuying:#{dataObject.forceBuying}, сегодня:#{later.schedule(later.parse.text(podZapasString)).isValid(d)}, #{later.schedule(later.parse.text(podZapasString)).next(2)}"
            weekToBuyInAdvanceMetadata = _.find(supplier.attribute, (attr) -> attr.metadataUuid == "c5723e59-f3f7-11e5-7a69-970d0029005d")
            if weekToBuyInAdvanceMetadata?
              weekToBuyInAdvance = weekToBuyInAdvanceMetadata.longValue
            if not weekToBuyInAdvance?
              console.log "У поставщика #{supplier.name} не заполнен период, на сколько закупать"
              return # пропускаем поставщика
            # пройтись по списку товаров этого поставщика в списке на закупку
            _.each Goods.find({isComplexGood:false, perWeekQtyNeeded: {$gt: 0}, supplierUuid: supplier.uuid, boughtOnLastPeriodsQty: {$gte: minNumberOfOtgruzhenoQty}, boughtOnLastPeriodsOrders: {$gte: minNumberOfOrders}}).fetch(), (good) ->
              totalQtyNeeded = (good.perWeekQtyNeeded * weekToBuyInAdvance) - good.realAvailableQty
              if totalQtyNeeded > 0
                console.log "good:#{good.name}, perWeekQtyNeeded:#{good.perWeekQtyNeeded}, good.realAvailableQty: #{good.realAvailableQty}, totalQtyNeeded:#{totalQtyNeeded}"
                # если товар дешевле 100р, то сразу покупаем минимум 5? штук
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
                Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Создание/обновление заказа на закупку завершено"
              catch e
                console.log "ошибка внутри runSync:", e
                Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Ошибка при создании/обновлении заказа на закупку: #{e}"
            else
              console.log "Пропускаем заведение заказа т.к. товаров для поставщика '#{supplier.name}' нет"
              Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Пропускаем заведение заказа т.к. товаров для поставщика '#{supplier.name}' нет"

        # закупка под заказ
        # activePurchaseOrder2 = PurchaseOrders.findOne {stateUuid: activeStateUuid, sourceAgentUuid: supplier.uuid, applicable: true}
        # if activePurchaseOrder2?
        #   console.log "найден старый заказ на закупку"
        #   Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Нашли старый заказ для него 2: #{activePurchaseOrder1.name}"
          # удалить старый заказ
          #delResult = HTTP.del('https://online.moysklad.ru/exchange/rest/ms/xml/purchaseOrder/' + activePurchaseOrder2.uuid, {auth:"admin@allshellac:qweasd"} )
          #console.log "delete result:", delResult
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
          "purchaseOrderPosition": [],
          "description": "Автозакупка под заказ"
        }
        activePurchaseOrder2.created = new Date()
        activePurchaseOrder2.purchaseOrderPosition = []
        podZakazStringMeta = _.find(supplier.attribute, (attr) -> attr.metadataUuid == "c5723a4e-f3f7-11e5-7a69-970d0029005c")
        if podZakazStringMeta?
          podZakazString = podZakazStringMeta.valueString
          if later.schedule(later.parse.text(podZakazString)).isValid(d) or dataObject.forceBuying?
            Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Сегодня день закупки под заказ: forceBuying:#{dataObject.forceBuying}, сегодня:#{later.schedule(later.parse.text(podZakazString)).isValid(d)}, #{later.schedule(later.parse.text(podZakazString)).next(2)}"
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
                Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Создание/обновление заказа на закупку завершено 2"
              catch e
                console.log "ошибка внутри runSync:", e
                Meteor.call "logSystemEvent", "calculateBuyingQty", "5. notice", "Ошибка при создании/обновлении заказа на закупку 2: #{e}"
            else
              console.log "Пропускаем заведение заказа т.к. товаров для поставщика '#{supplier.name}' нет"
    catch error
      console.log "error:", error
