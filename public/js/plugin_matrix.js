$(document).ready( function() {
  $('.collapse').collapse();

  $('#matrix-params').bind('click', function() { $('.collapse').collapse('toggle') });

  $("table").addTableFilter();
});

