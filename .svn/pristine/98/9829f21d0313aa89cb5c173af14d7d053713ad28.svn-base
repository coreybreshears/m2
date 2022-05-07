# DisconnectCodesHelper
module DisconnectCodesHelper
  def status_box(value, classname = '', pass_reason = false)
  	text = [pass_reason ? _('Drop') :_('No'), pass_reason ? _('Pass') : _('Yes'), _('Generate_if_missing'), _('Overwrite')]
  	classes = %w[disconnect-codes-no disconnect-codes-yes disconnect-codes-generate_if_missing disconnect-codes-overwrite]
  	"<span class=\"#{classes[value]} #{classname}\">#{text[value].upcase}</span>".html_safe
  end

  def disabled_text(code, dc_group_id)
  	'disconnect-codes-disabled-text' if code.global? && dc_group_id.to_i > 2
  end

  def default_codes_not_exist?
    DisconnectCode.default.blank?
  end

  def codes_and_reasons
    [
      '300 Multiple Choices', '301 Moved Permanently', '302 Moved Temporarily', '305 Use Proxy',
      '380 Alternative Service', '400 Bad Request', '401 Unauthorized', '402 Payment Required', '403 Forbidden',
      '404 Not Found', '405 Method Not Allowed', '406 Not Acceptable', '407 Proxy Authentication Required',
      '408 Request Timeout', '409 Conflict', '410 Gone', '411 Length Required', '412 Conditional Request Failed',
      '413 Request Entity Too Large', '414 Request-URI Too Long', '415 Unsupported Media Type',
      '416 Unsupported URI Scheme', '417 Unknown Resource-Priority', '420 Bad Extension', '421 Extension Required',
      '422 Session Interval Too Small', '423 Interval Too Brief', '424 Bad Location Information',
      '425 Bad Alert Message', '428 Use Identity Header', '429 Provide Referrer Identity', '430 Flow Failed',
      '433 Anonymity Disallowed', '436 Bad Identity-Info', '437 Unsupported Certificate', '438 Invalid Identity Header',
      '439 First Hop Lacks Outbound Support', '440 Max-Breadth Exceeded', '469 Bad Info Package', '470 Consent Needed',
      '478 Unresolvable destination', '480 Temporarily Unavailable', '481 Call/Transaction Does Not Exist',
      '482 Loop Detected', '483 Too Many Hops', '484 Address Incomplete', '485 Ambiguous', '486 Busy Here',
      '487 Request Terminated', '488 Not Acceptable Here', '489 Bad Event', '491 Request Pending', '493 Undecipherable',
      '494 Security Agreement Required', '500 Internal Server Error', '501 Not Implemented', '502 Bad Gateway',
      '503 Service Unavailable', '504 Server Time-out', '505 Version Not Supported', '513 Message Too Large',
      '555 Push Notification Service Not Supported', '580 Precondition Failure', '600 Busy Everywhere',
      '603 Decline', '604 Does Not Exist Anywhere', '606 Not Acceptable', '607 Unwanted', '608 Rejected'
    ]
  end

  def q850_codes
    [
      1, 2, 3, 4, 5, 6, 7, 8, 9, 16, 17, 18, 19,20, 21, 22, 23, 25, 26, 27, 28, 29, 30, 31, 34, 35, 38, 39, 40, 41, 42,
      43, 44, 46, 47, 49, 50, 52, 53, 54, 55, 57, 58, 62, 63, 65, 66, 69, 70, 79, 81, 82, 83, 84, 85, 86, 87, 88, 90,
      91, 95, 96, 97, 98, 99, 100, 101, 102, 103, 110, 111, 127
    ]
  end
end
