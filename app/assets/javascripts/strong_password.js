function getStrongPassword (event) {
   event.preventDefault();
   jQuery.ajax({
     type: "POST",
     url: mor_web_dir + "/users/suggest_strong_password",
     beforeSend: function (xhr) {
        // Security concerns
        xhr.setRequestHeader("X-CSRF-Token", jQuery("meta[name='csrf-token']").attr("content"));
      },
      success: function(data, status, xhrs) {
        setStrongPassword(data.data);
      }
    });
  }

function setStrongPassword (pass) {
  var pass_input = $j("#password_password");
  document.getElementById('password_password').type = 'text';
  pass_input.val(pass);
  pass_input.focus();
  pass_input.select();

  try {
    var successful = document.execCommand('copy');
    var msg = successful ? 'successful' : 'unsuccessful';
    showMessage('#26BB03');
  } catch (err) {
    console.error('Oops, unable to copy', err);
  }
}

function showMessage(color) {
  var message_container = jQuery("#copy_notice");
  message_container.css('color', color);
  message_container.show().delay(2000).fadeOut();
}