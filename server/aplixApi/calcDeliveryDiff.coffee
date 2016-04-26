Meteor.methods
  calcDeliveryDiff: ->
    AplixMutualSettlements.remove {}
    AplixDeliveryCosts.remove {}
    # Загрузить из апликса фин инфу всю
    credentials = [{apiKey: '48d38fe6-fb40-4c8c-be48-ee96448b1a0b', shipperId: '5000a7af-a256-eb15-11e5-6c17dd4cddfe'}, {apiKey: 'c83edc56-7f97-4212-95c5-1f6d7bce3073', shipperId: '5000f3a9-a256-eb15-11e4-610eb7073e6f'}]
    try
      for credential in credentials
        startDate = moment("2016-01-01")
        endDate = moment().add(1, 'days')
        curDate = startDate
        while curDate <= endDate
          result = HTTP.get "http://client.aplix.ru/pa/services/rest/delivery/getMutualSettlements?apiKey=#{credential.apiKey}&shipperId=#{credential.shipperId}&startDate=#{curDate.format('YYYY-MM-DD')}&endDate=#{curDate.add(5, 'days').format('YYYY-MM-DD')}&first=0&pageSize=999999"
          # Пройтись по всем заказам из фин. инфы
          _.each result.data.details, (detail) ->
            if detail.type is "MutualSettlementDetailCalcCostShipping"
              AplixMutualSettlements.insert detail
              packageItem = _.find(detail.items, (item) -> item.service is "Услуги по упаковке и маркировке")
              if packageItem?
                packagePrice = packageItem.sum
              else
                packagePrice = 0

              weightTarifItem = _.find(detail.items, (item) -> item.service is "Тариф за вес")
              if weightTarifItem?
                weightTarif = weightTarifItem.sum
              else
                weightTarif = 0

              insuranceItem = _.find(detail.items, (item) -> item.service is "Страхование")
              if insuranceItem?
                insurance = insuranceItem.sum
              else
                insurance = 0

              AplixDeliveryCosts.upsert {orderName: detail.content.orderExternalNumber}, {$set: {packagePrice: packagePrice, weightTarif: weightTarif, insurance: insurance, weight: detail.content.postWeight, deliveryCostTotal: detail.content.deliveryCost - packagePrice}}
              # Найти соотв. заказ у нас
              order = Orders.findOne {name: detail.content.orderExternalNumber}
              if order?
                nalozPlatSum = 0
                deliveryPrice = 0
                weight = 0
                # Если нашли - находим стоимость доставки клиентом
                _.each order.customerOrderPosition, (pos) ->
                  if pos.goodUuid is "6c7c59e7-68d0-11e4-7a07-673d00030b2f"
                    deliveryPrice = pos.price.sum / 100
                  good = Goods.findOne {uuid: pos.goodUuid}
                  if good?
                    weight += good.weight
                    if (good.name.lastIndexOf("Наложенный", 0) == 0)
                      nalozPlatSum = pos.price.sum / 100
                  else
                    service = Services.findOne {uuid: pos.goodUuid}
                    if service?
                      if (service.name.lastIndexOf("Наложенный", 0) == 0)
                        nalozPlatSum = pos.price.sum / 100
                AplixDeliveryCosts.upsert {orderName: detail.content.orderExternalNumber}, {$set: {weCharged: deliveryPrice, nalozPlatSum: nalozPlatSum, difference: (deliveryPrice - detail.content.deliveryCost + packagePrice + nalozPlatSum), weightMS: weight.toFixed(2)}}
          console.log curDate.format("YYYY-MM-DD")
    catch err
        console.log "Ошибка при подсчете расхождений в доставках:", err


    # Если нашли - записываем в таблицу отдельную
