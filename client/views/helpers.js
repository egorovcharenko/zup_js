
Template.registerHelper("prettifyDate", function(timestamp) {
  return moment(timestamp).format("DD.MM.YYYY");
});
