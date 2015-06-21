
//LocalOrders = new Mongo.Collection(null);

// dropdown
Template.ordersList.rendered = function(){
  this.$('.ui.dropdown').dropdown();
  this.$('.ui.checkbox').checkbox();
  Session.setDefault("StateToLoad", "Требуется закупка");
}

Template.ordersList.helpers({
  ordersListHelper: function () {
    var temp = Workflows.findOne({name:"CustomerOrder"});
    if (temp) {
      var stateUuid;
      _.each(temp.state, function (state) {
        if (state.name == Session.get("StateToLoad")) {
          stateUuid = state.uuid;
        }
      })
      var ret = orders.find({stateUuid: stateUuid});
      //console.log(ret.fetch());
      return ret;
    }
    return [];
  },
  orderHelper: function () {
    var ret = {};
    ret.sum = this.sum.sum / 100;
    stateUuid = this.stateUuid;
    var temp = Workflows.findOne({name:"CustomerOrder"});
    //console.log(temp);
    if (temp) {
      _.each(temp.state, function (state) {
        //console.log(stateUuid + " <> " + stateUuid);
        if (state.uuid == stateUuid) {
          ret.state = state.name;
        }
      });
    }
    //console.log(ret);
    return ret;
  },
  suppliers: function () {
    var ret = Companies.find({tags: {$in: ["поставщики"]}});
    return ret;
  }
});


Template.ordersList.events({
  "click .order-state": function (event, template) {
    //console.log(event);
    Session.set("StateToLoad", event.target.innerText)
    //Meteor.call("loadOrdersFromMS", {"state.name": event.target.innerText}, null);
    var temp = Workflows.findOne({name:"CustomerOrder"});
    if (temp) {
      var stateUuid;
      _.each(temp.state, function (state) {
        if (state.name == Session.get("StateToLoad")) {
          stateUuid = state.uuid;
          Session.set("StateToLoadUuid", state.uuid);
          console.log(state.uuid);
        }
      })
    }


    Meteor.call('resetChecked');
    Meteor.call('loadEntityFromMS', {"state.name": event.target.innerText}, "customerOrder", "Orders");
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
  "click .allOrdersSelect": function(event, template){
    var temp = Workflows.findOne({name:"CustomerOrder"});
    if (temp) {
      var stateUuid;
      _.each(temp.state, function (state) {
        if (state.name == Session.get("StateToLoad")) {
          Meteor.call("setAllChecked", state.uuid);
        }
      })
    }
  },
  "change #supplierSelector": function (event, template) {
    //console.log(event);
    //Session.set("supplierUuid", event.target.value);
    Router.go('buyingList', {"supplierUuid": event.target.value});

  }
});
