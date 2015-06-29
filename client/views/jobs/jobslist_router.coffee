Router.map ->
  @route 'jobslist',
    path: '/jobs/list'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe('last200jobs')
      ]
    data: ->
      myJobs.find {}, {sort: {updated:-1}}
