Router.map ->
  @route 'compoundgoods',
    path: '/compoundgoods'
    loadingTemplate: 'loading'
    waitOn: ->
      [
      ]
    data: ->
      dataVar = {}
      return dataVar
    onBeforeAction: (pause) ->
      @next()
      return
