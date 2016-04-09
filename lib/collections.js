// процессы
ProcessesIns = new Mongo.Collection('processes_ins');

// настройки
Settings = new Mongo.Collection('settings');

// kpi
Kpis = new Mongo.Collection('kpis');

// оприходования
Enters = new Mongo.Collection('enters');

// списания
Losses = new Mongo.Collection('losses');

// техкарты
ProcessingPlans = new Mongo.Collection('processing_plans');
Processings = new Mongo.Collection('processings');

// Отгрузки
Demands = new Mongo.Collection('demands');
Supplies = new Mongo.Collection('supplies');

// сотрудники
Employees = new Mongo.Collection('employees');

// лог
Log = new Mongo.Collection('log');

// лог
SystemLog = new Mongo.Collection('system_log');

// история заказов
StatusHistory = new Mongo.Collection('status_history');

// история заказов
PurchaseOrders = new Mongo.Collection('purchase_orders');

// история заказов
OrderRules = new Mongo.Collection('order_rules');

Orders = new Mongo.Collection('orders');
OrderTracks = new Mongo.Collection('order_tracks');
OrdersAplixStatuses = new Mongo.Collection('order_aplix_statuses');
OrderAplixBilling = new Mongo.Collection('order_aplix_billing');
OrderStatuses = new Mongo.Collection('order_statuses');

AplixOrders = new Mongo.Collection('aplix_orders');

Goods = new Mongo.Collection('goods');
GoodsImages = new Mongo.Collection('goods_images');

// услуги
Services = new Mongo.Collection('services');

Companies = new Mongo.Collection('companies');

Workflows = new Mongo.Collection('workflows');
CustomEntityMetadata = new Mongo.Collection('customEntityMetadata');
CustomEntity = new Mongo.Collection('customEntity');
AttributeMetadata = new Mongo.Collection('attributeMetadata');
EmbeddedEntityMetadata = new Mongo.Collection('embeddedEntityMetadata');
tempCol = new Mongo.Collection('tempCol');

DataTimestamps = new Mongo.Collection('data_timestamps');

myJobs = JobCollection('myJobQueue', {
  idGeneration: 'MONGO',
  transform: function (d) {
    var res;
    try {
      res = new Job (myJobs, d);
    } catch (e) {
      res = d;
    }
    //console.log("res = " + res);
    return res;
  }
});

CollectionNameMap = {
  "Orders": Orders,
  "Goods": Goods,
  "Services": Services,
  "Companies": Companies,
  "Workflows": Workflows,
  "DataTimestamps": DataTimestamps,
  "CustomEntityMetadata": CustomEntityMetadata,
  "CustomEntity": CustomEntity,
  "AttributeMetadata": AttributeMetadata,
  "EmbeddedEntityMetadata": EmbeddedEntityMetadata,
  "PurchaseOrders": PurchaseOrders,
  "Employees": Employees,
  "ProcessingPlans": ProcessingPlans,
  "Processings": Processings,
  "Demands": Demands,
  "Supplies": Supplies,
  "Losses": Losses,
  "Enters": Enters
}
