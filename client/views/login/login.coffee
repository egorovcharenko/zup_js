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
          workStartMon: template.find('#workStartMon').value
          workEndMon: template.find('#workEndMon').value
          workStartTue: template.find('#workStartTue').value
          workEndTue: template.find('#workEndTue').value
          workStartWed: template.find('#workStartWed').value
          workEndWed: template.find('#workEndWed').value
          workStartThu: template.find('#workStartThu').value
          workEndThu: template.find('#workEndThu').value
          workStartFri: template.find('#workStartFri').value
          workEndFri: template.find('#workEndFri').value
          workStartSat: template.find('#workStartSat').value
          workEndSat: template.find('#workEndSat').value
          workStartSun: template.find('#workStartSun').value
          workEndSun: template.find('#workEndSun').value
Template.login.helpers
  currentUserProfile: () ->
    Meteor.user().profile
