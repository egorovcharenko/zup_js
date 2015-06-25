Template.loadData.helpers({
  "progress": function () {
    var toret = {};
    toret.dataPercent = tempCol.findOne({"name":"countAlready"}).value / tempCol.findOne({"name":"countTotal"}).value * 100;

    toret.countAlready = tempCol.findOne({"name":"countAlready"}).value;
    toret.countTotal = tempCol.findOne({"name":"countTotal"}).value;

    console.log(toret);
    return toret;
  },
  "isActive": function() {
    var t = tempCol.findOne({"name":"isActive"});
    if (t) {
      return t.value;
    } else {
      return false;
    }
  }
});

Template.loadData.events({
  "click #load_goods": function(event, template){
    Meteor.call('loadEntityFromMS', "good", "Goods", '01-01-1900')
  },
  "click #load_companies": function(event, template){
    Meteor.call('loadEntityFromMS', "company", "Companies", '01-01-1900')
  },
  "click #load_rest": function(event, template){
    Meteor.call('loadEntityFromMS', "workflow", "Workflows", '01-01-1900')
  },
  "click #load_updated_orders": function(event, template){
    var lastTimeLoaded = DataTimestamps.findOne({name: "orders"});
    var temp = lastTimeLoaded ? new Date(lastTimeLoaded.value) : '24-06-2015';
    console.log(temp);
    Meteor.call("loadEntityFromMS", "customerOrder", "Orders", temp, function (error, result) {
      console.log(error);
      if (!error){
        Meteor.call("updateTimestampFlag", "orders");
      }
    });
  }
});
