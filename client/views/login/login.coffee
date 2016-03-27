Template.login.events
  'submit form': (event) ->
    console.log "register form submitted"
    event.preventDefault()
    email = $('[name=email]').val()
    password = $('[name=password]').val()
    dataObject = {}
    dataObject.email = email
    dataObject.password = password
    Meteor.call "createUserMethod", dataObject, (error, result) ->
      if error
        console.log "error", error
      if result
        console.log 'success!'
  'click #setMsUuid': (event, template) ->
    msUserId = template.find('#msUuidInput').value
    userName = template.find('#userNameInput').value
    id = Meteor.userId()
    Meteor.users.update id,
      $set:
        profile:
          msUserId: msUserId
          userName: userName

Template.login.helpers
  currentUserProfile: () ->
    Meteor.user().profile
