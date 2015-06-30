Meteor.methods({
  loadTracksFromAplix:function(dateFrom){
    var liveParams = {
      user: 'allshellac.ru',
      pass: 'cbioy815',
      url: 'z.aplix.ru/post/ws/Delivery.1cws?wsdl'
    }

    var testParams = {
      user: 'test',
      pass: 'test',
      url: 'z.aplix.ru/post/ws/Delivery.1cws?wsdl'
    }

    var paramsToUse = liveParams;

    var url = 'http://' + paramsToUse.user + ":" + paramsToUse.pass + "@" + paramsToUse.url;

    try {
      var client = Soap.createClient(url);
      client.setSecurity(new Soap.BasicAuthSecurity(paramsToUse.user, paramsToUse.pass));
      var args = {DateOfLastGetting: dateFrom.toISOString()};
      //console.log("args", args);
      //console.log("dateFrom", dateFrom);
      //console.log("dateFrom ISO", dateFrom.toISOString());

      var result = client.GetTrackNumbers(args);
      _.each(result.TrackNumbers.Items, function (track) {
        var savedTrack = OrderTracks.findOne({OrderID: track.OrderID});
        if (savedTrack) {
          OrderTracks.remove({OrderID: track.OrderID});
        }
        OrderTracks.insert(track);
      })

      args = {DateOfLastGetting: dateFrom.toISOString(), OnlyCompleted:false};
      result = client.GetStatusesOrders(args);
      _.each(result.StatusesOrders.Items, function (status) {
        var saved = OrderAplixStatuses.findOne({OrderID: status.OrderID});
        if (saved) {
          OrderAplixStatuses.remove({OrderID: status.OrderID});
        }
        OrderAplixStatuses.insert(status);
      })

    }
    catch (err) {
      if(err.error === 'soap-creation') {
        console.log(err);
        console.log('SOAP Client creation failed');
      }
      else if (err.error === 'soap-method') {
        console.log(err);
        console.log('SOAP Method call failed');
      } else {
        console.log(err);
      }
    }
  }
});
