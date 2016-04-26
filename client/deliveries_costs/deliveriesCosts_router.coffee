Router.map ->
  @route 'deliveriescosts',
    path: '/deliveriescosts'
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
