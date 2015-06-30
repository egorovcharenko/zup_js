getLastTimeRun = (entityName) ->
  lastTimeLoaded = DataTimestamps.findOne(name: entityName)
  if lastTimeLoaded? then new Date(lastTimeLoaded.value) else '01-01-2014'

findMetadataUuidByName = (entityName, attrName) ->
  #console.log("findMetadataUuidByName: entityName:" + entityName + ", attrName: " + attrName);
  embEntityMetadata = EmbeddedEntityMetadata.findOne(name: entityName)
  #console.log("embEntityMetadata: " + objToString(embEntityMetadata));
  result = undefined
  _.every embEntityMetadata.attributeMetadata, (attr) ->
    #console.log("--attributeMetadata: " + objToString(attr));
    if attr.name == attrName
      result = attr.uuid
      return false
    true
  result

objToString = (obj) ->
  str = ''
  for p of obj
    if obj.hasOwnProperty(p)
      str += p + '::' + obj[p] + '\n'
  str

logChangesInDescription = (entityFromMS, field, oldv, newv) ->
  if entityFromMS.hasOwnProperty('description')
    entityFromMS.description += "\n-------------\n#{moment().format('DD.MM.YY [в] HH:mm')} через приложение изменено поле '#{field}', со значения '#{(if oldv then oldv else '(пусто)')}' на '#{(if newv then newv else '(пусто)')}'"

Meteor.methods
  updateEntityMS: (entityType, entityUuid, data, attributes) ->
    console.log 'updateEntityMS started, paremeters:' + arguments
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      client = moyskladPackage.createClient()
      tools = moyskladPackage.tools
      client.setAuth 'admin@allshellac', 'qweasd'
      console.log 'entityType: ' + entityType + ', entityUuid: ' + entityUuid
      entityFromMS = client.load(entityType, entityUuid)
      console.log 'entityFromMS: ' + entityFromMS
      console.log 'data:' + data
      for prop of data
        if data.hasOwnProperty(prop)
          console.log '-property ' + prop
          entityFromMS[prop] = data[prop]
      console.log entityFromMSAfter1: entityFromMS
      # update attribs
      _.each attributes, (attrib) ->
        # {name: value}
        console.log '-attrib: ' + attrib
        metadataUuid = findMetadataUuidByName('CustomerOrder', attrib.name)
        console.log 'metadataUuid: ' + metadataUuid
        console.log entityFromMSBeforeGettingAttrib: entityFromMS.attribute.length
        test = tools.getAttr(entityFromMS, metadataUuid)
        console.log 'test: ' + test
        console.log entityFromMSAfterGettingAttrib: entityFromMS.attribute.length
        oldValue = test.valueString
        test.valueString = attrib.value
        console.log entityFromMSAfterSettingAttrib: entityFromMS.attribute.length
        console.log 'new value: ' + tools.getAttrValue(entityFromMS, metadataUuid)
        logChangesInDescription entityFromMS, attrib.name, oldValue, attrib.value
        return
      console.log entityFromMSAfter2: entityFromMS
      newEntity = client.save(entityFromMS)
      console.log 'newEntity: ', newEntity
      done null, "Заменено"
    )
    console.log 'updateEntityMS ended'
    response.result

  setEntityStateByUuid: (entityType, entityUuid, newStateUuid) ->
    #console.log "setEntityState started, newState: #{newStateUuid}"
    moyskladPackage = Meteor.npmRequire('moysklad-client')
    response = Async.runSync((done) ->
      try
        client = moyskladPackage.createClient()
        client.setAuth 'admin@allshellac', 'qweasd'
        entityFromMS = client.load(entityType, entityUuid)
        #console.log "entityFromMS before: #{objToString entityFromMS}"
        stateWorkflow = Workflows.findOne name:"CustomerOrder"

        oldStateName = (_.find stateWorkflow.state, (state) -> state.uuid is entityFromMS.stateUuid).name
        newStateName = (_.find stateWorkflow.state, (state) -> state.uuid is newStateUuid).name
        #console.log "newStateUuid: #{newStateUuid}"

        entityFromMS.stateUuid = newStateUuid
        logChangesInDescription entityFromMS, "Статус", oldStateName, newStateName
        #console.log "entityFromMS after: #{objToString entityFromMS}"

        client.save(entityFromMS)

        #fake on the client
        if entityType is "customerOrder"
          Orders.update({uuid: entityUuid}, {$set:{stateUuid: newStateUuid}})

        done null, oldStateName + "->" + newStateName
      catch error
        done error, null
    )
    if response.error?
      throw error
    else
      response.result

  loadEntityGenericMethod: (entityMSName, collectionName) ->
    console.log "loadEntityGenericMethod, entityMSName: #{entityMSName}"
    Meteor.call 'loadEntityFromMS', entityMSName, collectionName, getLastTimeRun(entityMSName), (error, result) ->
      if not error?
        Meteor.call 'updateTimestampFlag', entityMSName
      else
        console.log "Error in loading entities: #{error}"

  loadAllEntities: () ->
    console.log "loadAllEntities started"
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'good', 'Goods'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'company', 'Companies'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customerOrder', 'Orders'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'workflow', 'Workflows'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customEntityMetadata', 'CustomEntityMetadata'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'customEntity', 'CustomEntity'
    Meteor._sleepForMs(1000);
    Meteor.call 'loadEntityGenericMethod', 'embeddedEntityMetadata', 'EmbeddedEntityMetadata'
    # Meteor.call 'loadTracksFromAplix', getLastTimeRun 'aplix_tracks', (error, result) ->
    #   if not error?
    #     Meteor.call 'updateTimestampFlag', 'aplix_tracks'
    console.log "loadAllEntities ended"
