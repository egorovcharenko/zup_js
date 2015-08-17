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
      orders = (Orders.find {}, sort: name: 1).fetch()
      for order in orders
        # адрес доставки
        customer = Companies.findOne({uuid: order.sourceAgentUuid})
        if customer?
          order.customerAddress = customer.requisite.actualAddress
          # Meteor.call "getMSAttributeValue", this, [{entityName: "CustomerOrder", attrName: "Способ доставки"}], (error, result) ->
          #   if result
          #     deliveryWay = result["Способ доставки"].valueString
          #     console.log "deliveryWay:", deliveryWay
          # return deliveryWay
        else
          console.log "Клиент в заказе #{order.name} не найден"
      return orders
    onBeforeAction: (pause) ->
      @next()
      return
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
  @route 'packOrder',
    path: '/packOrder/:orderName/:orderPosSelected?'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe 'packOrderPub', @params.orderName
        Meteor.subscribe 'workflows'
      ]
    data: ->
      order = Orders.findOne(name: @params.orderName)
      ret = []
      if order
        _.each order.customerOrderPosition, (pos) ->
          isNeeded = true
          temp = {}
          temp.qty = pos.quantity
          temp.uuid = pos.uuid
          good = Goods.findOne(uuid: pos.goodUuid)
          if good
            #uuid
            temp.goodUuid = good.uuid

            # название
            if good.name == 'Наложенный платеж'
              isNeeded = false
            else
              temp.goodName = good.name

            # место хранения
            if good.description?
              temp.goodDesc = good.description.replace(new RegExp('\n', 'g'), '<br/>')
              parse = temp.goodDesc.match(/^([a-Я])-([0-9])-([0-9]{1,3})/)
              if parse and parse.length == 4
                temp.pallet = parse[1]
                temp.shelf = parse[2]
                temp.place = parse[3]
              else
                temp.pallet = temp.shelf = temp.place = 'Нет'
            else
              temp.goodDesc = 'Место хранения не задано'
              temp.pallet = temp.shelf = temp.place = 'Нет'

            # артикул
            temp.sku = good.productCode

            # отсутствие на складе
            temp.outOfStock = good.outOfStock

            # image
            img = GoodsImages.findOne(sku: good.productCode)
            if img and img.imageUrl
              temp.imageUrl = img.imageUrl
            else
              temp.imageUrl = 'http://semantic-ui.com/images/wireframe/image.png'
          else
            isNeeded = false
          temp.packedQty = pos.packedQty or 0
          if isNeeded
            ret.push temp
          return
        ret = _.sortBy(ret, (arg) ->
          arg.pallet + arg.shelf + arg.place + arg.goodName
        )
        if order.description?
          order.description = order.description.replace(new RegExp('\n', 'g'), '<br/>')
        return {order: order, customerOrderPositionsModified: ret }
      return
  return
