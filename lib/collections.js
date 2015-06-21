orders = new Mongo.Collection('orders');

Goods = new Mongo.Collection('goods');

Companies = new Mongo.Collection('companies');

Workflows = new Mongo.Collection('workflows');

tempCol = new Mongo.Collection('tempCol');

CollectionNameMap = {
  "orders": orders,
  "Goods": Goods,
  "Companies": Companies,
  "Workflows": Workflows
}

//ordersChecked = new Mongo.Collection('ordersChecked');
