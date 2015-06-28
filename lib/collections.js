Orders = new Mongo.Collection('orders');
OrderTracks = new Mongo.Collection('order_tracks');
OrderAplixStatuses = new Mongo.Collection('order_aplix_statuses');

Goods = new Mongo.Collection('goods');
GoodsImages = new Mongo.Collection('goods_images');

Companies = new Mongo.Collection('companies');

Workflows = new Mongo.Collection('workflows');
CustomEntityMetadata = new Mongo.Collection('customEntityMetadata');
CustomEntity = new Mongo.Collection('customEntity');
AttributeMetadata = new Mongo.Collection('attributeMetadata');
EmbeddedEntityMetadata = new Mongo.Collection('embeddedEntityMetadata');
tempCol = new Mongo.Collection('tempCol');

DataTimestamps = new Mongo.Collection('data_timestamps');

myJobs = JobCollection('myJobQueue');

CollectionNameMap = {
  "Orders": Orders,
  "Goods": Goods,
  "Companies": Companies,
  "Workflows": Workflows,
  "DataTimestamps": DataTimestamps,
  "CustomEntityMetadata": CustomEntityMetadata,
  "CustomEntity": CustomEntity,
  "AttributeMetadata": AttributeMetadata,
  "EmbeddedEntityMetadata": EmbeddedEntityMetadata
}

//ordersChecked = new Mongo.Collection('ordersChecked');
