Meteor.methods
  sendStockToMagento: (job) ->
    # magento
    liveParams = {
      user: 'zup_user',
      pass: 'zup_user',
      url: 'http://allshellac.ru/index.php/api/V2_soap?wsdl=1'
    }
    paramsToUse = liveParams;
    soapClient = Soap.createClient(paramsToUse.url);
    soapClient.setSecurity(new Soap.BasicAuthSecurity(paramsToUse.user, paramsToUse.pass));
    result = soapClient.login({username: paramsToUse.user, apiKey:paramsToUse.pass});
    session = result.loginReturn.$value;
    if not result.loginReturn.$value?
      throw new Error "Не получилось залогиниться в Magento"

    allDirtyGoods = Goods.find({dirty: true})
    console.log "Найдено #{allDirtyGoods.count()} остатков для отправки, начинаем отправку"

    for good in allDirtyGoods.fetch()
      try
        if good.realAvailableQty?
          if good.realAvailableQty > 0
            inStockStatus = "В наличии, отправим сегодня"
            shipmentStatus = "Товар в наличии на нашем складе, отправим сегодня или завтра утром"
            isInStock = 1
            stockQty = 9999 #good.stockQty
        if (not good.realAvailableQty? or good.realAvailableQty <= 0)
          outOfStockInSupplier = good.outOfStockInSupplier #tools.getAttrValue(good, metadataUuid)
          if outOfStockInSupplier
            #console.log "Флаг 'отсутствует у поставщика' у товара '#{good.name}': #{outOfStockInSupplier}"
            inStockStatus = "Временно нет в продаже"
            shipmentStatus = "Товар отсутствует у поставщика. Отправка возможна после появления в продаже."
            isInStock = 0
            stockQty = 0
          else
            if good.nextDate?
              inStockStatus = "В наличии, отправим #{moment(good.nextDate).format("DD.MM")}"
              shipmentStatus = "Товар в наличии, находится на складе поставщика, отправим #{moment(good.nextDate).format("DD.MM")}"
              isInStock = 1
              stockQty = 999
            else
              inStockStatus = "Доступно под заказ"
              shipmentStatus = "Товар под заказ, уточняйте время поступления у менеджера"
              isInStock = 1
              stockQty = 999

        console.log "Отправляем остаток: #{good.productCode}, кол-во #{good.realAvailableQty} наличие: #{inStockStatus}, отгрузка: #{shipmentStatus}"

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
        response = soapClient.catalogProductUpdate request
      catch error
        console.log "Ошибка при отправке остатка:", error.message

    soapClient.endSession session
    return "Остатки отправлены в Мадженто: #{allDirtyGoods.count()} всего"

  loadMagentoPics: ->
    console.log 'loadMagentoPics'
    liveParams =
      user: 'zup_user'
      pass: 'zup_user'
      url: 'http://allshellac.ru/index.php/api/V2_soap?wsdl=1'
    paramsToUse = liveParams
    soapClient = Soap.createClient(paramsToUse.url)
    soapClient.setSecurity new (Soap.BasicAuthSecurity)(paramsToUse.user, paramsToUse.pass)
    result = soapClient.login(
      username: paramsToUse.user
      apiKey: paramsToUse.pass)
    #console.log(result);
    session = result.loginReturn.$value
    if result.loginReturn.$value
      # get list of all the products
      productList = soapClient.catalogProductList(
        sessionId: session
        storeView: 'smmarket')
      console.log 'productList.storeView.item.length = ', productList.storeView.item.length
      countAlready = 0
      # get image of each products
      _.each productList.storeView.item, (product) ->
        simplifiedProduct =
          id: product.product_id.$value
          sku: product.sku.$value
          name: product.name.$value
        # already have a pic?
        if GoodsImages.findOne(id: simplifiedProduct.id)
          # skip
        else
          productImage = soapClient.catalogProductAttributeMediaList(
            sessionId: session
            product: simplifiedProduct.id
            storeView: 'smmarket')
          item = undefined
          if productImage.result.item
            if productImage.result.item[0]
              item = productImage.result.item[0]
            else if productImage.result.item
              item = productImage.result.item
            else
              item = null
            if item
              simplifiedProduct.imageUrl = item.url.$value
          GoodsImages.insert simplifiedProduct
        countAlready++
        return
    return
