Meteor.methods
  toggleBuyingState: (dataObject)->
    try
      state = OrderStatuses.findOne({uuid: dataObject.stateUuid})
      if state?
        if state.buyGoodsInThisState?
          newState = not state.buyGoodsInThisState
        else
          newState = true
        res = OrderStatuses.update({uuid: dataObject.stateUuid}, {$set: {buyGoodsInThisState: newState}})
    catch error
      console.log "error:", error
