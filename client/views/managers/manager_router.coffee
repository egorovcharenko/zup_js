Router.map ->
  @route 'managers',
    path: '/managers'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe('ordersForModeration')
        Meteor.subscribe('workflows')
        Meteor.subscribe("orderRules")
        Meteor.subscribe("employees")
      ]
    data: ->
      # orders = (Orders.find {}, sort: {name: 1})
      # return orders
    onBeforeAction: (pause) ->
      @next()
      return
