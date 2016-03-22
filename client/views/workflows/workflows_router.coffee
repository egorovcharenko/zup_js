Router.map ->
  @route 'workflows',
    path: '/workflows'
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
