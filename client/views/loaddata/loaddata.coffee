getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then new Date(lastTimeLoaded.value) else new Date('01-01-2014')

loadEntityGeneric = (entityMSName, collectionName) ->
  Meteor.call 'loadEntityFromMS', entityMSName, collectionName, getLastTimeRun(entityMSName), (error, result) ->
    if not error?
      Meteor.call 'updateTimestampFlag', entityMSName
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
    Meteor.call 'loadTracksFromAplix', getLastTimeRun 'aplix_tracks', (error, result) ->
      if not error?
        Meteor.call 'updateTimestampFlag', 'aplix_tracks'
  'click #load_pics': (event, template) ->
    Meteor.call 'loadMagentoPics'
  'click #load_everything': (event, template) ->
    Meteor.call 'loadAllEntities'
