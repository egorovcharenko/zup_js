Orders = new Mongo.Collection('orders');

Goods = new Mongo.Collection('goods');

Companies = new Mongo.Collection('companies');

Workflows = new Mongo.Collection('workflows');

tempCol = new Mongo.Collection('tempCol');

DataTimestamps = new Mongo.Collection('data_timestamps');

CollectionNameMap = {
  "Orders": Orders,
  "Goods": Goods,
  "Companies": Companies,
  "Workflows": Workflows,
  "DataTimestamps": DataTimestamps
}

//ordersChecked = new Mongo.Collection('ordersChecked');
