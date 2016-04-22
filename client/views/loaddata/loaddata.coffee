getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then moment(lastTimeLoaded.value).subtract(2, 'seconds') else moment('2014-01-01')

loadEntityGeneric = (entityMSName, collectionName) ->
  currentTime = moment()
  Meteor.call 'loadEntityFromMS', entityMSName, collectionName, getLastTimeRun(entityMSName), (error, result) ->
  if not error?
    Meteor.call 'updateTimestampFlag', entityMSName, currentTime
  else
    console.log "Error in loading entities: #{error}"

Template.loadData.helpers
  'progress': ->
    toret = {}
    toret.dataPercent = tempCol.findOne('name': 'countAlready').value / tempCol.findOne('name': 'countTotal').value * 100
    toret.countAlready = tempCol.findOne('name': 'countAlready').value
    toret.countTotal = tempCol.findOne('name': 'countTotal').value
    toret
  'isActive': ->
    t = tempCol.findOne('name': 'isActive')
    if t
      t.value
    else
      false
Template.loadData.events
  'click #calcDeliveryDiff': (event, template) ->
    Meteor.call "calcDeliveryDiff"
  'click #testMethod': (event, template) ->
    Meteor.call "testMethod"
  'click #calcNalogi': (event, template) ->
    Meteor.call "calcNalogi"
  'click #checkOrdersAccounts': (event, template) ->
    Meteor.call "checkOrdersAccounts"
  'click #autoStatusChange': (event, template) ->
    Meteor.call "autoStatusChange"
  'click #setAutosalePrices': (event, template) ->
    Meteor.call "setAutosalePrices"
  'click #calculate_kpis': (event, template) ->
    Meteor.call "calculateKpis"
  'click #drop_reserve': (event, template) ->
    job = new Job myJobs, 'periodicalDropReserve', {}
    job.priority('high')
      .retry({ retries: 1, wait: 1*1000})
      .save()
  'click #make_buying_request': (event, template) ->
    job = new Job myJobs, 'calculateBuyingQty', {forceBuying:true}
    job.priority('high')
      .retry({ retries: 1, wait: 1*1000})
      .save()
  'click #load_goods': (event, template) ->
    loadEntityGeneric 'good', 'Goods'
  'click #load_companies': (event, template) ->
    loadEntityGeneric 'company', 'Companies'
  'click #load_updated_orders': (event, template) ->
    loadEntityGeneric 'customerOrder', 'Orders'
  'click #load_rest': (event, template) ->
    loadEntityGeneric 'workflow', 'Workflows'
    loadEntityGeneric 'customEntityMetadata', 'CustomEntityMetadata'
    loadEntityGeneric 'customEntity', 'CustomEntity'
    loadEntityGeneric 'embeddedEntityMetadata', 'EmbeddedEntityMetadata'
  'click #load_aplix_tracks': (event, template) ->
    Meteor.call 'loadTracksFromAplix'
  'click #load_pics': (event, template) ->
    Meteor.call 'loadMagentoPics'
  'click #load_everything': (event, template) ->
    Meteor.call 'loadAllEntities'
  'click #load_stock': (event, template) ->
    Meteor.call 'loadStockFromMS' , (error, result) ->
      if not error?
        console.log "loadStockFromMS успешно, результат: #{result}"
      else
        console.log "loadStockFromMS НЕуспешно, ошибка: #{error}"
  'click #send_stock_to_magento': (event, template) ->
    Meteor.call 'sendStockToMagento' , (error, result) ->
      if not error?
        console.log "sendStockToMagento успешно, результат: #{result}"
      else
        console.log "sendStockToMagento НЕуспешно, ошибка: #{error}"
  'click #close_orders_in_ms': (event, template) ->
    console.log "close_orders_in_ms"
    Meteor.call "closeOrdersInMS", (error, result) ->
      if error
        console.log "error:", error
      if result
        console.log  "success:",result

  'click #load_aplix_billing': (event, template) ->
    console.log "load_aplix_billing"
    Meteor.call "loadBillingInfo", (error, result) ->
      if error
        console.log "error:", error
      if result
        console.log  "success:", result
