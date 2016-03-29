Meteor.methods
  setNewGoodQty: (dataObject) ->
    try
      moyskladPackage = Meteor.npmRequire('moysklad-client')
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'

      # установить последнее время проверки
      Goods.update {uuid: dataObject.goodUuid}, {$set: {lastTimeChecked: new Date()}}

      good = Goods.findOne {uuid: dataObject.goodUuid}
      # сверить разницу - добавлять или отнимать?
      difference = dataObject.newQty - good.stockQty
      console.log "diff: #{difference}"
      if difference < 0
        # если отнимать - создать новое списание
        # дата - вчерашний день
        # цена списания - цена закупки
        loss = {
          "TYPE_NAME" : "moysklad.loss",
          "sourceAgentUuid" : "8de836c7-65fe-11e4-90a2-8ecb00148411",
          "sourceStoreUuid" : "8de95654-65fe-11e4-90a2-8ecb00148413",
          "applicable" : true,
          "moment" : moment().toDate(),
          "payerVat" : true,
          "rate" : 1,
          "vatIncluded" : true,
          "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
          "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
          "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
          "shared" : false,
          "lossPosition" : [
            {
              "TYPE_NAME" : "moysklad.lossPosition",
              "discount" : 0,
              "quantity" : -difference,
              "goodUuid" : good.uuid,
              "vat" : 0,
              "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
              "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
              "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
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
          ]
        }
        # записать и сохранить
        response = Async.runSync (done) ->
          try
            entityFromMS = client.save(loss)
            done(null, "Отгрузка сохранена");
          catch e
            console.log "ошибка внутри runSync:", e
            done(e, null);
      else if difference > 0
        # создать оприходование
        newEnter = {
          "TYPE_NAME" : "moysklad.enter",
          "sourceAgentUuid" : "8de836c7-65fe-11e4-90a2-8ecb00148411",
          "targetStoreUuid" : "8de95654-65fe-11e4-90a2-8ecb00148413",
          "applicable" : true,
          "moment" : moment().subtract(1, 'days').toDate(),
          "payerVat" : true,
          "rate" : 1,
          "vatIncluded" : true,
          "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
          "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
          "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
          "shared" : false,
          "enterPosition" : [
            {
              "TYPE_NAME" : "moysklad.enterPosition",
              "discount" : 0,
              "quantity" : difference,
              "goodUuid" : good.uuid,
              "vat" : 0,
              "accountUuid" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
              "accountId" : "6e02ccbd-65fe-11e4-7a07-673d00001215",
              "groupUuid" : "09951fc6-d269-11e4-90a2-8ecb000588c0",
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
          ]
        }
        # записать и сохранить
        response = Async.runSync (done) ->
          try
            entityFromMS = client.save(newEnter)
            done(null, "Приемка сохранена");
          catch e
            console.log "ошибка внутри runSync:", e
            done(e, null);
    catch error
      console.log "error:", error
  setNewGoodStorage: (dataObject) ->
    try
      moyskladPackage = Meteor.npmRequire('moysklad-client')
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'

      good = client.load('Good', dataObject.goodUuid)
      good.description = dataObject.description
      # записать и сохранить
      response = Async.runSync (done) ->
        try
          entityFromMS = client.save(good)
          done(null, "Отгрузка сохранена");
        catch e
          console.log "ошибка внутри runSync:", e
          done(e, null);
    catch error
      console.log "error:", error
