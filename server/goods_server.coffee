Meteor.methods
  setNewGoodQty: (dataObject) ->
    try
      #moyskladPackage = Meteor.npmRequire('moysklad-client')
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
        console.log "diff < 0, creating loss"
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
        try
          entityFromMS = client.save(loss)
        catch e
          console.log "ошибка внутри client.save:", e
      else if difference > 0
        console.log "diff > 0, creating enter"
        # получаем пример оприходования
        #temp = HTTP.get('https://online.moysklad.ru/exchange/rest/ms/xml/Enter/6121ff33-f5a7-11e5-7a69-970f00044175', {auth:"admin@allshellac:qweasd"} )
        #console.log "enter:", temp.content
        #Enters.insert temp.content

        Meteor.call "addNewEnter", [{uuid:good.uuid, qty: difference, buyPrice: good.buyPrice}]
      # запомнить на клиенте сразу на всякий случай
      Goods.update {uuid: dataObject.goodUuid}, {$set: {stockQty: dataObject.newQty, realAvailableQty: dataObject.newQty - good.reserveQty}}
    catch error
      console.log "error:", error
  setNewGoodStorage: (dataObject) ->
    try
      #moyskladPackage = Meteor.npmRequire('moysklad-client')
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'

      good = client.load('Good', dataObject.goodUuid)
      good.description = dataObject.description
      # записать и сохранить
      try
        entityFromMS = client.save(good)
      catch e
        console.log "ошибка внутри client.save:", e
    catch error
      console.log "error:", error
  addNewEnter: (goodsToEnter) ->
    newEnter =
    "<?xml version='1.0' encoding='UTF-8'?><enter
      overheadDistribution='BY_PRICE'
      sourceAgentUuid='8de836c7-65fe-11e4-90a2-8ecb00148411'
      targetStoreUuid='8de95654-65fe-11e4-90a2-8ecb00148413'
      applicable='true'
      payerVat='true'
      rate='1.0'
      moment='#{moment().subtract(1,'days').toISOString()}'
      vatIncluded='true'>
        <accountUuid>6e02ccbd-65fe-11e4-7a07-673d00001215</accountUuid>
        <accountId>6e02ccbd-65fe-11e4-7a07-673d00001215</accountId>
        <groupUuid>09951fc6-d269-11e4-90a2-8ecb000588c0</groupUuid>
        <ownerUid>admin@allshellac</ownerUid>
        <shared>false</shared>"
    _.each goodsToEnter, (good) ->
      newEnter +=
        "<enterPosition
          discount='0.0'
          quantity='#{good.qty}'
          goodUuid='#{good.uuid}'
          vat='0'>
            <accountUuid>6e02ccbd-65fe-11e4-7a07-673d00001215</accountUuid>
            <accountId>6e02ccbd-65fe-11e4-7a07-673d00001215</accountId>
            <groupUuid>09951fc6-d269-11e4-90a2-8ecb000588c0</groupUuid>
            <ownerUid>admin@allshellac</ownerUid>
            <shared>false</shared>
            <basePrice sum='#{good.buyPrice}' sumInCurrency='#{good.buyPrice}'/>
            <price sum='#{good.buyPrice}' sumInCurrency='#{good.buyPrice}'/>
            <things/>
            <tags/>
        </enterPosition>"
    newEnter += "</enter>"

    #console.log newEnter
    result = HTTP.put 'https://online.moysklad.ru/exchange/rest/ms/xml/Enter', {auth:"admin@allshellac:qweasd", content: newEnter, headers: {"Content-Type": "application/xml"}}
    #console.log result
