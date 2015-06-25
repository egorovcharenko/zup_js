//var subs = new SubsManager();

Router.configure({
  layoutTemplate: 'basicLayout'
});

Router.map(function() {

  this.route('ordersList', {
    path: '/orders/list/:orderState?',
    loadingTemplate: 'loading',
    waitOn: function() {
      console.log("in ordersList waitOn");
      var orderState = this.params.orderState || "Требуется закупка";
      return [
        Meteor.subscribe('ordersWithState', orderState),
        Meteor.subscribe('allSuppliersSub'),
        Meteor.subscribe('tempCol'),
        Meteor.subscribe('workflows')
      ];
    },
    data: function () {
      return Orders.find({});
    },
    onBeforeAction: function (pause) {
      //Meteor.call('loadEntityFromMS', {"state.name": this.params.orderState}, "customerOrder", "Orders");
      this.next();
    }
  });

  this.route('loadData', {
    path: '/loaddata',
    waitOn: function() {
      return [Meteor.subscribe('tempCol'), Meteor.subscribe('dataTimestamps')];
    }
  });

  this.route('buyingList', {
    path: '/buyingList/:supplierUuid',
    waitOn: function() {
      return Meteor.subscribe('buyingListPub');
    },
    data: function() {
      var supplierUuid = this.params.supplierUuid;
      var retOrd = [];
      _.each(Orders.find({checked: true}, {fields: {name:1, 'customerOrderPosition.goodUuid':1, 'customerOrderPosition.quantity':1, created: 1}}, {sort: {created: 1}}).fetch(), function (order) {
        var ret = [];
        _.each(order.customerOrderPosition, function (pos) {
          var good = Goods.findOne({uuid: pos.goodUuid}, {fields: {name:1, supplierUuid: 1}});
          if (good) {
            if (good.supplierUuid == supplierUuid){
              var company = Companies.findOne({uuid: good.supplierUuid}, {fields: {name:1}});
              var tt = {name: (pos.quantity > 1) ? good.name + " " + pos.quantity + " ШТУК(И)!!!" : good.name, quantity: pos.quantity, companyName: (company ? company.name : "")};
              ret.push(tt);
            }
          }
        });
        if (ret.length > 0) {
          order.customerOrderPositionModified = ret;
          retOrd.push(order);
        }
      });
      return { customerOrders: retOrd };
    }
  });

  this.route('home', {
    path: '/',
    action: function () {
      this.render('ordersList');
    }
  });
});
