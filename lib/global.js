moyskladPackage = require('moysklad-client');
moment = require ('moment-business-time');

tools = moyskladPackage.tools;

client = moyskladPackage.createClient();
client.setAuth('admin@allshellac', 'qweasd');
client.options.requestPeriod = 500; // Период
client.options.requestsPerPeriod = 3; // Кол-во запросов за период
client.options.parallelTaskCount = 1; // параллельные запросы (для тебя не важно, но поставь 1 на всяк случай)
