moyskladPackage = require('moysklad-client');
moment = require ('moment-business-time');

tools = moyskladPackage.tools;

client = moyskladPackage.createClient();
client.setAuth('admin@allshellac', 'qweasd');
client.options.requestPeriod = 1000; // Период
client.options.requestsPerPeriod = 100; // Кол-во запросов за период
client.options.parallelTaskCount = 100; // параллельные запросы (для тебя не важно, но поставь 1 на всяк случай)
