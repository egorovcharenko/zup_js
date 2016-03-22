Meteor.methods
  createBuyingRequest: ->
    console.log "starting createBuyingRequest"
    try
      moyskladPackage = Meteor.npmRequire('moysklad-client')
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
        activePurchaseOrder = PurchaseOrders.findOne {stateUuid: activeStateUuid, sourceAgentUuid: supplier.uuid, applicable: true}
        if activePurchaseOrder?
          console.log "найден старый заказ на закупку"
          # удалить старый заказ
          #delResult = HTTP.del('https://online.moysklad.ru/exchange/rest/ms/xml/purchaseOrder/' + activePurchaseOrder.uuid, {auth:"admin@allshellac:qweasd"} )
          #console.log "delete result:", delResult
        else
          activePurchaseOrder = {
            "TYPE_NAME" : "moysklad.purchaseOrder",
            "reservedSum" : 0,
            "stateUuid" : activeStateUuid,
            #"targetAgentUuid" : "8de836c7-65fe-11e4-90a2-8ecb00148411",
            "sourceAgentUuid" : supplier.uuid,
            #"targetStoreUuid" : "8de95654-65fe-11e4-90a2-8ecb00148413",
            "applicable" : true,
            #"moment" : ISODate("2015-07-03T09:43:00Z"),
            "targetAccountUuid" : "8de83912-65fe-11e4-90a2-8ecb00148412",
            #"sourceAccountUuid" : "f7f4439d-b220-11e4-7a40-e897000c3257",
            "payerVat" : true,
            "rate" : 1,
            "vatIncluded" : true,
            #"name" : "00906",
            "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
            "ownerUid" : "admin@allshellac",
            "shared" : false,
            "purchaseOrderPosition": []
          }
        activePurchaseOrder.created = new Date()
        activePurchaseOrder.purchaseOrderPosition = []
        # добавить в него все позиции
        # пройтись по списку товаров этого поставщика в списке на закупку
        _.each Goods.find({includeInNextBuyingQty: {$gt: 0}, supplierUuid: supplier.uuid}).fetch(), (good) ->
          purchaseOrderPosition = {
            "TYPE_NAME" : "moysklad.purchaseOrderPosition",
            #"uuid": uuid.v4(),
            #"discount" : 0,
            "quantity" : good.includeInNextBuyingQty,
            #"consignmentUuid" : "646c468f-bdb5-11e4-90a2-8ecb00694b27",
            "goodUuid" : good.uuid,
            "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
            "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
            "ownerUid" : "admin@allshellac",
            "shared" : false,
            #"reserve" : 0
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
          activePurchaseOrder.purchaseOrderPosition.push purchaseOrderPosition
        #console.log "Товаров к закупке у поставщика:", activePurchaseOrder.purchaseOrderPosition.length
        # сохранить заказ
        if activePurchaseOrder.purchaseOrderPosition.length > 0
          response = Async.runSync (done) ->
            try
              entityFromMS = client.save(activePurchaseOrder)
              #console.log "Создание/обновление заказа на закупку завершено"
              done(null, null);
            catch e
              console.log "ошибка внутри runSync:", e
              done(null, null);
        else
          console.log "Пропускаем заведение заказа т.к. товаров для поставщика '#{supplier.name}' нет"
    catch error
      console.log "error:", error
