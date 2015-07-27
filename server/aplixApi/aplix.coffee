Meteor.methods
  loadTracksFromAplix: (dateFrom) ->
    console.log "loadTracksFromAplix started, dateFrom:#{dateFrom}"
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

      # треки
      args = DateOfLastGetting: dateFrom.toISOString()
      console.log("args", args);
      #console.log("dateFrom", dateFrom);
      console.log("dateFrom ISO", dateFrom.toISOString());
      console.log "Начинаем загружать Треки"
      result = client.GetTrackNumbers(args)
      console.log "GetTrackNumbers completed"
      _.each result.TrackNumbers.Items, (track) ->
        #console.log "track for order #{track.OrderID} processed: #{track.Number}"
        savedTrack = OrderTracks.findOne(OrderID: track.OrderID)
        if savedTrack
          OrderTracks.remove OrderID: track.OrderID
        OrderTracks.insert track
        return

      # статусы
      args =
        DateOfLastGetting: dateFrom.toISOString()
        OnlyCompleted: false
      console.log "Начинаем загружать Заказы"
      result = client.GetStatusesOrders(args)
      _.each result.StatusesOrders.Items, (status) ->
        #console.log "StatusesOrders for order #{status.OrderID} processed: #{status.Status.Name}"
        saved = OrderAplixStatuses.findOne(OrderID: status.OrderID)
        if saved
          OrderAplixStatuses.remove OrderID: status.OrderID
        OrderAplixStatuses.insert status
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
