Meteor.methods
  testMethod: ->
    client = moyskladPackage.createClient()
    tools = moyskladPackage.tools
    client.setAuth 'admin@allshellac', 'qweasd'
    Meteor.call "logSystemEvent", "client.load", "5. notice", "Вызываем client.load в setOrderReserve, options: #{JSON.stringify(client.options,null,2)}"
    try
      order = client.load('customerOrder', "04aca886-ff50-11e5-7a69-93a7003ae493")
    catch err
      Meteor.call "logSystemEvent", "client.load", "2. error", "Ошибка при вызове в setOrderReserve, options: #{JSON.stringify(client.options,null,2)}, client: #{JSON.stringify(client,null,2)}"
    Meteor.call "logSystemEvent", "client.load", "5. notice", "Закончили вызывать client.load в setOrderReserve, options: #{JSON.stringify(client.options,null,2)}"
