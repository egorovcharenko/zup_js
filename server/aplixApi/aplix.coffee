Meteor.methods
  loadTracksFromAplix: () ->
    console.log "loadTracksFromAplix started"
    # треки
    credentials = [{apiKey: '48d38fe6-fb40-4c8c-be48-ee96448b1a0b', contractorId: '5000a7af-a256-eb15-11e5-6c178779fb38'}, {apiKey: 'c83edc56-7f97-4212-95c5-1f6d7bce3073', contractorId: '5000f3a9-a256-eb15-11e4-6022293d599d'}]
    try
      for credential in credentials
        startDate = moment("2014-04-08")
        endDate = moment().add(1, 'days')
        curDate = startDate
        while curDate <= endDate
          result = HTTP.get "http://client.aplix.ru/pa/services/rest/delivery/getTrackings?apiKey=#{credential.apiKey}&contractorId=#{credential.contractorId}&startDate=#{curDate.format('YYYY-MM-DD')}&endDate=#{curDate.add(5, 'days').format('YYYY-MM-DD')}"
          _.each result.data.trackings, (track) ->
            #console.log track
            savedTrack = OrderTracks.findOne {orderId: track.orderId}
            if savedTrack?
              OrderTracks.remove {orderId: track.orderId}
            track.apiKey = credential.apiKey
            track.contractorId = credential.contractorId
            OrderTracks.insert track
          console.log curDate.format("YYYY-MM-DD")
    catch err
        console.log "Ошибка при загрузке треков из Апликс:", err
    # заказы
    try
      _.each OrderTracks.find({}).fetch(), (track) ->
        result = HTTP.get "http://client.aplix.ru/pa/services/rest/delivery/getOrder?apiKey=#{track.apiKey}&orderId=#{track.orderId}"
        console.log result
        savedOrder = AplixOrders.findOne {orderId: track.orderId}
        if savedTrack?
          AplixOrders.remove {orderId: track.orderId}
        AplixOrders.insert result.data
    catch err
        console.log "Ошибка при загрузке треков из Апликс:", err

  checkOrdersAccounts: () ->
    console.log "Начали проверять заказы"
    # проверка по каждому заказу из МС: орг, курьеры
    _.each Orders.find().fetch(), (order) ->
      attrib = _.find(order.attribute, (attr) -> attr.metadataUuid is "50836a82-6912-11e4-90a2-8ecb00526879")
      if attrib?
        if (attrib.entityValueUuid is "eee3b452-691a-11e4-90a2-8ecb0052f8d1") # Апликс
          aplixOrder = AplixOrders.findOne {identifier: order.name}
          if aplixOrder?
            # организация - должна совпадать с Апликсовским контрагентом
            if (order.targetAgentUuid is "ddbb489e-65c9-11e5-90a2-8ecb004e1c38") and (aplixOrder.contractorId is "5000f3a9-a256-eb15-11e4-6022293d599d")
              console.log "Несовпадение, заказ #{order.name} заведен от ИП Трембачев а отгружен в Апликс от ИП Овчаренко"
            else if (order.targetAgentUuid is "8de836c7-65fe-11e4-90a2-8ecb00148411") and (aplixOrder.contractorId is "5000a7af-a256-eb15-11e5-6c178779fb38")
              console.log "Несовпадение, заказ #{order.name} заведен от ИП Овчаренко а отгружен в Апликс от ИП Трембачев"
            #else console.log "Заказ #{order.name} совпадает"
            return true
      return false
    # проверка по каждому заказу из Апликса: курьеры в МС
    console.log "Закончили проверять заказы"
    return

  markOrdersInDeliveryPlace: () ->
    # проверка по каждому заказу из МС: орг, курьеры
    Orders.update {}, {$unset:{atDeliveryPlace: ""}}, {multi: true}
    _.each AplixOrders.find().fetch(), (aplixOrder) ->
      if aplixOrder.status?
        if aplixOrder.status.value is "ARRIVED_AT_DELIVERY_PLACE"
          order = Orders.findOne {name: aplixOrder.identifier}
          if order?
            Orders.update {name: aplixOrder.identifier}, {$set: {atDeliveryPlace: "1"}}
            # если заказ в статусе что мы знаем что он в пункте выдачи - не меняем, иначе:
            # Заказ в пункте выдачи - НЕ требуется связь
            # Заказ в пункте выдачи - требуется связь
            # ВЫполнен
            # Отказ (после отправки)
            if not ((order.stateUuid is "a9508cfd-fe83-11e5-7a69-8f5500085d54") or (order.stateUuid is "5753d0b0-a6fb-11e4-90a2-8ecb0011be7f") or (order.stateUuid is "798d5b49-68d0-11e4-7a07-673d00031aa2") or (order.stateUuid is "a33d0fff-7496-11e4-90a2-8ecb00385fe2") or (order.stateUuid is "a9508cfd-fe83-11e5-7a69-8f5500085d54"))
              # меняем статус на "Заказ в пункте выдачи - требуется связь"
              pendingChanges = [{
                type: "setState"
                value: "5753d0b0-a6fb-11e4-90a2-8ecb0011be7f" # Заказ в пункте выдачи - требуется связь
              }]
              Meteor.call "startProcessingChanges", order.uuid, pendingChanges
              console.log "Меняем у заказа #{order.name} статус на то, что его не выкупают"
              #Meteor.call "setEntityStateByUuid", "customerOrder", order.uuid,
              # TODO отправляем СМСку
    return
  loadBillingInfo: ->
    console.log "loadBillingInfo started"
    liveParams =
      user: 'allshellac.ru'
      pass: 'cbioy815'
      url: 'z.aplix.ru/post/ws/Delivery.1cws?wsdl'
    testParams =
      user: 'test'
      pass: 'test'
      url: 'z.aplix.ru/post/ws/Delivery.1cws?wsdl'
    paramsToUse = liveParams
    url = 'http://' + paramsToUse.user + ':' + paramsToUse.pass + '@' + paramsToUse.url
    try
      client = Soap.createClient(url)
      client.setSecurity new (Soap.BasicAuthSecurity)(paramsToUse.user, paramsToUse.pass)

      # платежи
      args =
        BeginDate: (new Date(2014,0,1)).toISOString()
        EndDate: (new Date(2020,0,1)).toISOString()
      console.log "Начинаем загружать Платежи"
      result = client.GetBillingData(args)
      #console.log result
      console.log "Данные получены, кол-во:#{result.return.Items.length}"

      _.each result.return.Items, (billing) ->
        #console.log "Billing item for order #{billing.ExtNumber} processed, amount:#{billing.Amount}, service: #{billing.Service}"
        saved = OrderAplixBilling.findOne({ExtNumber: billing.ExtNumber, Service: billing.Service})
        if saved
          OrderAplixBilling.remove {ExtNumber: billing.ExtNumber, Service: billing.Service}
        OrderAplixBilling.insert billing
        return

    catch err
      if err.error == 'soap-creation'
        console.log err
        console.log 'SOAP Client creation failed'
      else if err.error == 'soap-method'
        console.log err
        console.log 'SOAP Method call failed'
      else
        console.log err
    return
