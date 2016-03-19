Meteor.methods
  createUserMethod: (dataObject) ->
    Accounts.createUser {email: dataObject.email, password: dataObject.password}
