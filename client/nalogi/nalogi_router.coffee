Router.map ->
  @route 'nalogi',
    path: '/nalogi'
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
