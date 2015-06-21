Router.configure({
  layoutTemplate: 'basicLayout'
});

Router.map(function() {
  this.route('ordersList', {path: '/orders/list'});
  this.route('loadData', {path: '/loaddata'});
  this.route('/buyingList/:supplierUuid', {
    data: function() {
      var supplierUuid = this.params.supplierUuid;
      var retOrd = [];
      _.each(orders.find({checked: true}, {name: 1, _state: 1, customerOrderPosition: 1}).fetch(), function (order) {
        var ret = [];
        _.each(order.customerOrderPosition, function (pos) {
          var good = Goods.findOne({uuid: pos.goodUuid});
          if (good) {
            console.log(good.supplierUuid + " - " + supplierUuid);
            if (good.supplierUuid == supplierUuid){
              var company = Companies.findOne({uuid: good.supplierUuid});
              var tt = {name: good.name, quantity: pos.quantity, companyName: (company ? company.name : "")};
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
