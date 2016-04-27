moyskladPackage = require('moysklad-client');
moment = require ('moment-business-time');
Future = require('fibers/future');

tools = moyskladPackage.tools;

client = moyskladPackage.createClient();
client.setAuth('admin@allshellac', 'qweasd');
//client.options.requestPeriod = 1000; // Период
//client.options.requestsPerPeriod = 100; // Кол-во запросов за период
//client.options.parallelTaskCount = 1; // параллельные запросы (для тебя не важно, но поставь 1 на всяк случай)
