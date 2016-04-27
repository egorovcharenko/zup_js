Template.deliveriescosts.helpers
  settings: () ->
    {
      collection: "deliveries_costs_special_publish"
      rowsPerPage: 50
      showFilter: true
      fields: [{
          fieldId: "orderName"
          key:'orderName'
          label:"Заказ"
        },{
            fieldId: "sumPaid"
            key:'sumPaid'
            label:"Клиент заплатил"
        },{
          fieldId: "packagePrice"
          key:'packagePrice'
          label:"Упаковка заказа Апликсом"
        },{
          fieldId: "weightTarif"
          key:'weightTarif'
          label:"Тариф перевозчика"
        },{
          fieldId: "insurance"
          key:'insurance'
          label:"Страховка"
        },{
          fieldId: "incassation"
          key:'incassation'
          label:"Инкассация"
        },{
          fieldId: "weight"
          key:'weight'
          label:"Вес"
        },{
          fieldId: "weightMS"
          key:'weightMS'
          label:"Вес в МС"
        },{
          fieldId: "deliveryCostTotal"
          key:'deliveryCostTotal'
          label:"Заплатили Апликсу за доставку"
        },{
          fieldId: "weCharged"
          key:'weCharged'
          label:"Взяли за доставку"
        },{
          fieldId: "nalozPlatSum"
          key:'nalozPlatSum'
          label:"Наложенный платеж - мы взяли"
        },{
          fieldId: "difference"
          key:'difference'
          label:"Прибыль от доставки"
          sortDirection: 'ascending'
          sortOrder: 1
        }]
      class: "ui celled table"
    }
