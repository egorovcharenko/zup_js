Router.map ->
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
              parse = temp.goodDesc.match(/^([a-Я0-9]+)-?([0-9]{0,3})-?([0-9]*)/)
              if parse and parse.length == 4
                temp.pallet = parse[1]
                temp.shelf = parse[2]
                temp.place = parse[3]
              else if parse and parse.length == 3
                temp.pallet = parse[1]
                temp.shelf = parse[2]
              else if parse and parse.length == 2
                temp.pallet = parse[1]
              else
                temp.pallet = temp.shelf = temp.place = 'Нет'
            else
              temp.goodDesc = 'Место хранения не задано'
              temp.pallet = temp.shelf = temp.place = 'Нет'

            # артикул
            temp.sku = good.productCode

            # остатки
            temp.stockQty = good.stockQty
            temp.reserveQty = good.reserveQty
            temp.quantityQty = good.quantityQty

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
