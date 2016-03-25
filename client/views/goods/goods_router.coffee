Router.map ->
  @route 'goods',
    path: '/goods'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe "allSuppliersSub"
      ]
    onBeforeAction: (pause) ->
      @next()
      return
