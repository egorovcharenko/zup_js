#var subs = new SubsManager();
Router.configure layoutTemplate: 'basicLayout'
Router.map ->
  @route 'ordersList',
    path: '/orders/list/:orderState?'
    loadingTemplate: 'loading'
    waitOn: ->
      orderState = @params.orderState or 'На сборку'
      [
        Meteor.subscribe('ordersWithStateAndAplix', orderState)
        Meteor.subscribe('allSuppliersSub')
        Meteor.subscribe('tempCol')
        Meteor.subscribe('workflows')
      ]
    data: ->
      orders = (Orders.find {}, sort: {name: 1})
      #for order in orders
        # адрес доставки
        #customer = Companies.findOne({uuid: order.sourceAgentUuid})
        #if customer?
          #order.customerAddress = customer.requisite.actualAddress
          # Meteor.call "getMSAttributeValue", this, [{entityName: "CustomerOrder", attrName: "Способ доставки"}], (error, result) ->
          #   if result
          #     deliveryWay = result["Способ доставки"].valueString
          #     console.log "deliveryWay:", deliveryWay
          # return deliveryWay
        #else
          #console.log "Клиент в заказе #{order.name} не найден"
      return orders
    onBeforeAction: (pause) ->
      @next()
      return
  @route 'login',
    path: '/login'
    loadingTemplate: 'loading'
  @route 'viewlog',
    path: '/viewlog'
    loadingTemplate: 'loading'
  @route 'systemlog',
    path: '/systemlog'
    loadingTemplate: 'loading'
  @route 'statushistory',
    path: '/statushistory'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe('workflows')
      ]
  @route 'loadData',
    path: '/loaddata'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe('tempCol')
        Meteor.subscribe('dataTimestamps')
      ]
  @route 'buyingList',
    path: '/buyingList/:supplierUuid'
    loadingTemplate: 'loading'
    waitOn: ->
      Meteor.subscribe 'buyingListPub'
    data: ->
      supplierUuid = @params.supplierUuid
      retOrd = []
      _.each Orders.find({ checked: true }, { fields:
        name: 1
        'customerOrderPosition.goodUuid': 1
        'customerOrderPosition.quantity': 1
        created: 1 }, sort: created: 1).fetch(), (order) ->
        ret = []
        _.each order.customerOrderPosition, (pos) ->
          good = Goods.findOne({ uuid: pos.goodUuid }, fields:
            name: 1
            supplierUuid: 1)
          if good
            if good.supplierUuid == supplierUuid
              company = Companies.findOne({ uuid: good.supplierUuid }, fields: name: 1)
              tt =
                name: if pos.quantity > 1 then good.name + ' ' + pos.quantity + ' ШТУК(И)!!!' else good.name
                quantity: pos.quantity
                companyName: if company then company.name else ''
              ret.push tt
          return
        if ret.length > 0
          order.customerOrderPositionModified = ret
          retOrd.push order
        return
      { customerOrders: retOrd }
  @route 'home',
    path: '/'
    action: ->
      @render 'ordersList'
      return
  return
