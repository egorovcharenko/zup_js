Meteor.methods({
  loadMagentoPics:function(){
    console.log("loadMagentoPics");
    var liveParams = {
      user: 'zup_user',
      pass: 'zup_user',
      url: 'http://allshellac.ru/index.php/api/V2_soap?wsdl=1'
    }

    var paramsToUse = liveParams;

    var client = Soap.createClient(paramsToUse.url);
    client.setSecurity(new Soap.BasicAuthSecurity(paramsToUse.user, paramsToUse.pass));

    var result = client.login({username: paramsToUse.user, apiKey:paramsToUse.pass});
    //console.log(result);
    var session = result.loginReturn.$value;
    if (result.loginReturn.$value) {
      // get list of all the products
      var productList = client.catalogProductList({sessionId:session, storeView:"smmarket"});

      console.log("productList.storeView.item.length = ", productList.storeView.item.length);
      tempCol.upsert({"name": "countTotal"}, {$set: {"value": productList.storeView.item.length}});
      tempCol.upsert({"name": "isActive"}, {$set: {"value": true}});

      var countAlready = 0;
      // get image of each products
      _.each(productList.storeView.item, function (product) {
        var simplifiedProduct = {
          id: product.product_id.$value,
          sku: product.sku.$value,
          name: product.name.$value
        };
        // already have a pic?
        if (GoodsImages.findOne({id: simplifiedProduct.id})){
          // skip
        } else {
          var productImage = client.catalogProductAttributeMediaList({
            sessionId: session,
            product: simplifiedProduct.id,
            storeView: "smmarket"
          });
          var item;
          if (productImage.result.item) {
            if (productImage.result.item[0]){
              item = productImage.result.item[0];
            } else if (productImage.result.item) {
              item = productImage.result.item;
            } else {
              item = null;
            }
            if (item) {
              simplifiedProduct.imageUrl = item.url.$value;
            }
          }
          GoodsImages.insert(simplifiedProduct);
        }
        countAlready ++;
        tempCol.upsert({"name": "countAlready"}, {$set: {"value": countAlready}});
      });
    }
    // end
    tempCol.upsert({"name": "countTotal"}, {$set: {"value": 10}});
    tempCol.upsert({"name": "countAlready"}, {$set: {"value": 0}});
    tempCol.upsert({"name": "isActive"}, {$set: {"value": false}});
  }
});
