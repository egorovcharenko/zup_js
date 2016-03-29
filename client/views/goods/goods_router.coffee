Router.map ->
  @route 'goods',
    path: '/goods/:goodSelected?'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe "allSuppliersSub"
      ]
    onBeforeAction: (pause) ->
      @next()
      return
