
//LocalOrders = new Mongo.Collection(null);

// dropdown
Template.ordersList.rendered = function(){
  this.$('.ui.dropdown').dropdown();
  this.$('.ui.checkbox').checkbox();
  Session.setDefault("StateToLoad", "Требуется закупка");
}

Template.ordersList.helpers({
  ordersListHelper: function () {
    //console.log("ordersListHelper got invoked");
    return orders.find({_state: Session.get("StateToLoad")});
  },
  suppliers: function () {
    var ret = Companies.find({tags: {$in: ["поставщики"]}});
    //console.log(ret);
    //console.log(ret.fetch());
    return ret;
  }
});


Template.ordersList.events({
  "click .order-state": function (event, template) {
    //console.log(event);
    Session.set("StateToLoad", event.target.innerText)
    Meteor.call("loadOrdersFromMS", {"state.name": event.target.innerText}, function (error, result) {
      //LocalOrders = result;
      //LocalOrders.remove({});
      //_.each(result, function (order) {
      //  LocalOrders.insert (order);
        //console.log(order);
      //})
    });
  }
});


Template.ordersList.helpers({
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
  },
  "getPathForBuying": function () {
    var ret = {};
    ret.supplierUuid = Session.get("supplierUuid");
    return ret;
  }
});

Template.ordersList.events({
  "click .orderSelect": function(event, template){
    Meteor.call("toggleChecked", this);
  },
  "change #supplierSelector": function (event, template) {
    //console.log(event);
    //Session.set("supplierUuid", event.target.value);
    Router.go('buyingList', {"supplierUuid": event.target.value});

  }
});
