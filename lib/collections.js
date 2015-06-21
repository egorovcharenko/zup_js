orders = new Mongo.Collection('orders');

Goods = new Mongo.Collection('goods');

Companies = new Mongo.Collection('companies');

tempCol = new Mongo.Collection('tempCol');

CollectionNameMap = {
  "orders": orders,
  "Goods": Goods,
  "Companies": Companies
}

//ordersChecked = new Mongo.Collection('ordersChecked');
