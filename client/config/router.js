//var subs = new SubsManager();

var allOrdersSub = null;
var tempColSub = null;
var allSuppliersSub = null;
var workflowsSub = null;

Router.configure({
  layoutTemplate: 'basicLayout'
});

Router.map(function() {
  this.route('ordersList', {
    path: '/orders/list',
    waitOn: function() {
      allOrdersSub = Meteor.subscribe('allOrders');
      allSuppliersSub = Meteor.subscribe('allSuppliersSub');
      tempColSub = Meteor.subscribe('tempCol');
      workflowsSub = Meteor.subscribe('workflows');
      return [allOrdersSub, allSuppliersSub, tempColSub, workflowsSub];
    }
  });
  this.route('loadData', {
    path: '/loaddata',
    waitOn: function() {
      return Meteor.subscribe('tempCol');
    }
    });
  this.route('/buyingList/:supplierUuid', {
    waitOn: function() {
      return Meteor.subscribe('buyingListPub');
    },
    data: function() {
      var supplierUuid = this.params.supplierUuid;
      var retOrd = [];
      _.each(orders.find({checked: true}, {fields: {name:1, 'customerOrderPosition.goodUuid':1, 'customerOrderPosition.quantity':1, created: 1}}, {sort: {created: 1}}).fetch(), function (order) {
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
    },
    name: 'buyingList'
  });
});
