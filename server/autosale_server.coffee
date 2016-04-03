Meteor.methods
  setAutosalePrices: ->
    weeksLowerBound = 4
    weeksHighBound = 12
    numberOfAutosaleStages = 3
    durationOfAutosaleStageWeeks = 2

    msclient = moyskladPackage.createClient()
    tools = moyskladPackage.tools
    msclient.setAuth 'admin@allshellac', 'qweasd'
    # подсчитать сколько в неделю уходит
    Meteor.call "calculateDemandPerWeek"

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
    try
      if not result.loginReturn.$value?
        throw new Error "Не получилось залогиниться в Magento"
      # сбросить флаг
      Goods.update {}, {$set: {forAutoSale: false}}, multi: true
      # пройтись по всем товарам
      _.each Goods.find({realAvailableQty: {$gt: 0}}).fetch(), (good) ->
        try
          weeksHighBoundForThisGood = weeksHighBound
          weeksLowerBoundForThisGood = weeksLowerBound
          # пропускаем ненужные
          if (good.name.lastIndexOf("Доставка", 0) == 0) or (good.name.lastIndexOf("Сырье", 0) == 0) or (good.name.lastIndexOf("Наклейка AllShellac", 0) == 0) or (good.name.lastIndexOf("Наложенный", 0) == 0) or (good.name.lastIndexOf("Верхние наклейки", 0) == 0) or (good.name.lastIndexOf("Наклейки IRISK Quick Design", 0) == 0)
            return
          if good.salePrice < 1
            return
          # товар-исключение
          isExceptionAttr = tools.getAttr(good, "80eb001d-e84a-11e5-7a69-97110001559d")
          if isExceptionAttr.booleanValue?
            isException = isExceptionAttr.booleanValue
          else
            isException = false
          # стадия автораспродажи
          autosaleStageAttr = tools.getAttr(good, "80eb0474-e84a-11e5-7a69-97110001559e")
          if autosaleStageAttr.longValue?
            console.log "autosaleStageAttr.longValue: #{autosaleStageAttr.longValue}"
            autosaleStage = autosaleStageAttr.longValue
          else
            autosaleStage = 1
          # компенсирууем
          autosaleStage--
          # дата следующей автораспродажи
          nextAutosaleDateAttr = tools.getAttr(good, "80eb0a92-e84a-11e5-7a69-9711000155a0")
          if nextAutosaleDateAttr.timeValue?
            nextAutosaleDate = nextAutosaleDateAttr.timeValue
            console.log "nextAutosaleDateAttr found:", moment(nextAutosaleDate).format("DD.MM")
          else
            nextAutosaleDate = new Date()
          # дата следующей автораспродажи
          normalPriceAttr = tools.getAttr(good, "80eb07e4-e84a-11e5-7a69-97110001559f")
          if normalPriceAttr.longValue?
            console.log "normalPriceAttr.longValue: #{normalPriceAttr.longValue}"
            if normalPriceAttr.longValue > 500
              normalPrice = normalPriceAttr.longValue
            else
              normalPrice = good.salePrice
          else
            normalPrice = good.salePrice
          # если это товар исключение или дата следующей автораспродажи не наступила - пропускаем
          if isException
            return
          if moment(nextAutosaleDate).isAfter(moment())
            return
          # подсчитываем остаток
          stock = good.realAvailableQty
          # на сколько недель остатка?
          if good.perWeekQtyNeeded?
            perWeekQtyNeeded = good.perWeekQtyNeeded
          else
            perWeekQtyNeeded = 0
          weeksStockWillLast = stock / perWeekQtyNeeded
          # на сколько закупаемся у поставщика?
          supplier = Companies.findOne {uuid: good.supplierUuid }
          if supplier?
            weekToBuyInAdvanceMetadata = _.find(supplier.attribute, (attr) -> attr.metadataUuid == "c5723e59-f3f7-11e5-7a69-970d0029005d")
            if weekToBuyInAdvanceMetadata?
              # увеличить срок на закупку у поставщика
              weeksHighBoundForThisGood +=weekToBuyInAdvanceMetadata.longValue
              weeksLowerBoundForThisGood +=weekToBuyInAdvanceMetadata.longValue
          prevAutosaleStage = autosaleStage
          # если больше порога, то снижаем цену
          if weeksStockWillLast > weeksHighBoundForThisGood
            autosaleStage++
          # если меньше порога, то возвращаем предыдущую цену
          if weeksStockWillLast < weeksLowerBoundForThisGood
            autosaleStage--
          # проверяем границы
          autosaleStage = Math.max(autosaleStage, 0)
          autosaleStage = Math.min(autosaleStage, numberOfAutosaleStages)
          # если товар не в наличии - сбрасываем уровень распродаж вообще
          if good.realAvailableQty == 0
            autosaleStage = 0
          # изменяем цену
          if prevAutosaleStage != autosaleStage
            buyPrice = good.buyPrice
            if buyPrice < 100
              buyPrice = good.salePrice * 0.7
            buyPrice = buyPrice * 1.10 # прибавляем минимум 10% к цене закупки
            price = Math.ceil(buyPrice + (normalPrice - buyPrice) * ((numberOfAutosaleStages - autosaleStage) / numberOfAutosaleStages))
            priceForMagento = Math.ceil(price / 100)
            console.log "#{good.name}, stock:#{good.realAvailableQty}, perWeekQtyNeeded:#{perWeekQtyNeeded}, weeksStockWillLast:#{weeksStockWillLast}, prevAutosaleStage:#{prevAutosaleStage}, autosaleStage:#{autosaleStage}, #{buyPrice} - #{priceForMagento} - #{normalPrice}"
            Goods.update {uuid:good.uuid}, {$set: {forAutoSale: true}}
            # устанавливаем дату следующей автораспродажи
            autosaleStageNew = autosaleStage
            # передаем цену в Мадженто
            request = {}
            request.sessionId = session
            request.storeView = "smmarket"
            request.identifierType = "sku"
            request.product = good.productCode
            request.productData = {
              special_price: priceForMagento
              special_from_date: ""
              special_to_date: ""
            }
            response = client.catalogProductUpdate request
            # устанавливаем все параметры в МС
            # компенсирууем
            autosaleStageAttr.longValue = autosaleStage + 1
            nextAutosaleDateAttr.timeValue = moment().add(durationOfAutosaleStageWeeks, 'weeks').toDate()
            normalPriceAttr.longValue = normalPrice
            msclient.save(good)

            #console.log "Response: #{response}"
            #console.log "Response: #{client.lastRequest}"
            #throw new Meteor.Error "завершили обработку одного товара: #{good.name}"
        catch error
          console.log "error:", error
    catch error
      console.log "error:", error
    finally
      client.endSession session
