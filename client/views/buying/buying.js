Template.buyingList.helpers({
  good: function () {
    return Goods.findOne({uuid: this.goodUuid});
  },
  company: function () {
    return Companies.findOne({uuid: this.supplierUuid});
  }
});

Template.buyingList.onCreated (function () {
  //console.log(orders.findOne());
});

Template.buyingList.events({
  "click #foo": function(event, template){

  }
});
