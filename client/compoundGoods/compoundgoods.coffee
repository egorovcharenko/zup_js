Template.compoundgoods.helpers
  settings: () ->
    {
      collection: "compoundgoods_special_publish"
      rowsPerPage: 50
      showFilter: true
      fields: [{
          fieldId: "name"
          key:'name'
          label:"Составной товар"
        },{
          fieldId: "plan"
          key:'plan'
          label:"Техкарта"
        },{
          fieldId: "materials"
          key:'materials'
          label:"Составные части"
        },{
          fieldId: "minQty"
          key:'minQty'
          label:"Доступное количество"
          sortDirection: 'ascending'
          sortOrder: 1
        }]
      class: "ui celled table"
    }
