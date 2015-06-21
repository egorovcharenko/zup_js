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
    Meteor.call('loadEntityFromMS', null, "good", "Goods", null)
  },
  "click #load_companies": function(event, template){
    Meteor.call('loadEntityFromMS', null, "company", "Companies", null)
  }
});
