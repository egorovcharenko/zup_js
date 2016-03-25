Meteor.startup ()->
  OrderRules.remove {}
  # считать файлы
  rulesJson = JSON.parse(Assets.getText("order_rules.json"))
  _.each rulesJson.orderRules, (rule)->
    OrderRules.insert rule
