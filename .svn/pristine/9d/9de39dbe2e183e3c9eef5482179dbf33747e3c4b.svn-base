$(window).ready(function(){
  $.browser.chrome = /chrom(e|ium)/.test(navigator.userAgent.toLowerCase());
  var is_safari = navigator.userAgent.indexOf("Safari") > -1;

  if ($.browser.chrome || is_safari) {
    $('.login-form').attr('autocomplete', 'off');
  }
});