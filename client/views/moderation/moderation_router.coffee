Router.map ->
  @route 'moderation',
    path: '/managers/moderation/:orderName'
    loadingTemplate: 'loading'
    waitOn: ->
      orderName = @params.orderName
      [
        Meteor.subscribe 'moderation', orderName
        Meteor.subscribe "orderWithGoodsAndCompany", orderName
        Meteor.subscribe('workflows')
      ]
    data: ->
      dataVar = {}
      orderName = @params.orderName
      order = Orders.findOne {name: orderName}
      # все текущие задачи
      Steps = new (Mongo.Collection)(null)
      #processIns = ProcessesIns.findOne({name:"Модерация", "params.orderNumber": orderName})
      processIns = ProcessesIns.findOne({"params.orderNumber": orderName, status: "active"})
      #console.log "orderName:", orderName
      #console.log "processIns ", processIns
      if processIns?
        _.each processIns.steps, (step) ->
          #console.log "step", step
          if step.status == "active"
            Steps.insert step
          #console.log "iteration step ", step
        #console.log "steps ", Steps.find({}).fetch()
        dataVar.activeSteps = Steps.find({})
        dataVar.processIns = processIns
      if order?
        # найти атрибуты
        _.each order.attribute, (attribute) ->
          if attribute.metadataUuid is "7eae7fd0-a200-11e4-90a2-8ecb003256f9"
            order.deliveryWay = attribute.valueString
          if attribute.metadataUuid is "8206e25c-7ba5-11e4-90a2-8ecb000b98de"
            order.outOfStock = attribute.valueString
        dataVar.order = order
        dataVar.company = Companies.findOne({uuid: order.sourceAgentUuid})
      #console.log "dataVar", dataVar
      return dataVar
    onBeforeAction: (pause) ->
      @next()
      return
