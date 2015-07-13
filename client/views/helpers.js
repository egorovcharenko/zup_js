
Template.registerHelper("prettifyDate", function(timestamp) {
  return moment(timestamp).format("DD.MM.YYYY");
});

Template.registerHelper("prettifyDateTime", function(timestamp) {
  return moment(timestamp).format('DD.MM.YY [в] HH:mm:ss')
});

Template.registerHelper('breaklines', function(text) {
  if (!!text) {
    text = Handlebars.Utils.escapeExpression(text);
    text = text.replace(/(\r\n|\n|\r)/gm, '<br>');
    return new Handlebars.SafeString(text);
  }
});
