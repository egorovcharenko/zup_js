Router.map ->
  @route 'jobslist',
    path: '/jobs/list'
    loadingTemplate: 'loading'
    waitOn: ->
      [
        Meteor.subscribe('last200jobs')
      ]
    data: ->
      myJobs.find {type: {$nin: ['autofail', 'cleanup']}}, {sort: {after:-1}}
