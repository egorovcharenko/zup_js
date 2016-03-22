Router.map ->
  @route 'buyinglist',
    path: '/buyinglist'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe "allSuppliersSub"
      ]
    data: ->
      dataVar = {}
      return dataVar
    onBeforeAction: (pause) ->
      @next()
      return
