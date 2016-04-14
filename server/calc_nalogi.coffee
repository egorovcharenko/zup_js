Meteor.methods
  calcNalogi: ->
    console.log "Начинаем подсчитывать налоги"
    # очистить остатки
    Stock.remove({})
    NalogiRashodi.remove({})
    NalogiSums.remove({})

    # пройтись по всем приемкам Трембачева
    _.each Supplies.find({targetAgentUuid: "ddbb489e-65c9-11e5-90a2-8ecb004e1c38", applicable: true}).fetch(), (supply) ->
      _.each supply.shipmentIn, (shipmentIn) ->
        Stock.insert {uid: uuid.v4(), goodUuid: shipmentIn.goodUuid, date: supply.created, quantity: shipmentIn.quantity, price: shipmentIn.price.sum, shipmentInName: supply.name, quantityLeft: shipmentIn.quantity}

    console.log "Подсчитали остатки, переходим к отгрузкам"

    # пройтись по всем отгрузкам
    _.each Demands.find({applicable: true, moment: {$gte: new Date('2015-09-01')}}).fetch(), (demand) ->
      console.log "Начинаем обрабатывать отгрузку #{demand.name} от #{moment(demand.moment).format('YYYY-MM-DD')}"
      # пройтись по каждому товару из заказа
      _.each demand.shipmentOut, (shipmentOut) ->
        good = Goods.findOne {uuid: shipmentOut.goodUuid}
        if good?
          if (good.name.lastIndexOf("Доставка", 0) == 0)
            return # пропускаем доставки
          #console.log "-- #{good.name}"
          # товар, не услуга
          # посчитать, остались ли товары на складе и их стоимость
          alreadyTaken = 0
          if demand.sourceAgentUuid is "ddbb489e-65c9-11e5-90a2-8ecb004e1c38"
            _.find Stock.find({goodUuid: shipmentOut.goodUuid, date: {$lte: demand.created}}).fetch(), (stock) ->
              needMore = shipmentOut.quantity - alreadyTaken
              canTake = Math.min(needMore, stock.quantityLeft)
              alreadyTaken += canTake
              Stock.update({uid: stock.uid}, {$inc: {quantityLeft: -canTake}})
              # добавить их в налоговую таблицу
              NalogiRashodi.insert {sourceAgentUuid: demand.sourceAgentUuid, quantity: canTake, date: demand.moment, goodUuid: shipmentOut.goodUuid, demandNumber: demand.name, shipmentInName: stock.shipmentInName, priceEachBought: stock.price, dateBought: stock.date, priceEachSold: shipmentOut.price.sum}
              if alreadyTaken == shipmentOut.quantity
                return true
              else
                return false
          if alreadyTaken == shipmentOut.quantity
            ;#console.log "- Для товара #{good.name} нашли все в закупках Кирилла, приемка (одна из): " + NalogiRashodi.findOne({goodUuid: good.uuid, demandNumber: demand.name}).shipmentInName
          else
            #console.log "- Для товара #{good.name} НЕ нашли все в закупках Кирилла, не хватило: #{shipmentOut.quantity - alreadyTaken}"
            NalogiRashodi.insert {sourceAgentUuid: demand.sourceAgentUuid, quantityNotFound: shipmentOut.quantity - alreadyTaken, date: demand.moment, goodUuid: shipmentOut.goodUuid, demandNumber: demand.name, shipmentInName: "", priceEachBought: "", dateBought: "", priceEachSold: shipmentOut.price.sum}
    console.log "Подсчитали отгрузки, переходим к статистике"
    # подготовить суммы по месяцам
    _.each NalogiRashodi.find({}).fetch(), (nalog) ->
      if nalog.quantity?
        if nalog.quantity?
          # нашли в стоке ИП Трембачева
          NalogiSums.upsert {date: moment(nalog.date).format("YYYY-MM"), accountUuid: nalog.sourceAgentUuid}, {$inc: {sumSoldFromKTBuyPrice: nalog.priceEachBought * nalog.quantity}}
        else
          # не нашли в его стоке
          NalogiSums.upsert {date: moment(nalog.date).format("YYYY-MM"), accountUuid: nalog.sourceAgentUuid}, {$inc: {sumSoldNotFromKTSalePrice: (nalog.priceEachSold * nalog.quantityNotFound)}}
    console.log "Закончили подсчитывать налоги"
