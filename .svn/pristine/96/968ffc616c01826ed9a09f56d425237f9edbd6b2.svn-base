# Email Sender
class EmailSender
  def send_notification(email, addresses, user_id = 0, options = {})
    log_message = if !emails_enabled?
                    _('Email_disabled')
                  elsif no_email? || email.blank?
                    _('Email_was_not_found')
                  end

    if log_message.present?
      MorLog.my_debug(log_message, true)
      return
    end

    user = User.where(id: user_id).first

    smtp = Email.smtp_options(user.owner_id)
    variables = Email.email_variables(user).merge(options)
    prepared_email = prepare_email(email, addresses, smtp, variables)
    status = system(prepared_email)

    variables[:status] = check_status(status, variables)
    Action.create_email_sending_action(user, 'send_email', email, variables)
    variables[:status]
  end

  def self.send_tariff_import_notification(rule, notification, options = {})
    email_id = rule["trigger_#{notification}_email_notification_id"].try(:to_i)
    email = Email.where(id: email_id).first

    recipients = rule["trigger_#{notification}_email_notification_recipients"].to_s
    MorLog.my_debug("Sending tariff import #{notification} notification", true)
    email_sender = new
    email_sender.send_notification(email, recipients, 0, options)
  end

  private

  def no_email?
    defined?(NO_EMAIL) && NO_EMAIL.to_i == 1
  end

  def emails_enabled?
    Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
  end

  def prepare_email(email, address_to, smtp, email_variables = {})
    email_body = rendered_email(email, email_variables)
    email_subject = rendered_email(email, email_variables, :subject)
    email_from = email.from_email.presence || smtp[:from]
    email_string(email_from, address_to, "#{email_body} ", "#{email_subject}", '', smtp[:connection], email[:format])
  end

  def email_string(from = '', to = '', message = '', subject = '', files = '', smtp = "'localhost'", message_type = 'plain')
    cmd = "/usr/local/m2/sendEmail -s #{smtp} -f '#{from}' -t $'#{to.gsub("'", "\\\\'")}' -u '#{subject}' -o 'message-content-type=text/#{message_type}'"
    cmd << " -m '#{message}'"
    cmd << " #{files}" if files.present?
    MorLog.my_debug(cmd)
    cmd
  end

  def rendered_email(email, assigns = {}, field = :body)
    if email
      email_builder = ActionView::Base.new(nil, assigns)
      email_builder.render(
          inline: nice_email_body(email.try(field)),
          locals: assigns
      ).gsub("'", '&#8216;')
    end
  end

  def nice_email_body(email_body)
    result = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |part| part.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$') }
    result = result.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    result.gsub(/(<%=?\s*\S+\s*%>)/) { |part| part if Email::ALLOWED_VARIABLES.include?(part.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

  def check_status(status, variables)
    return _('Email_sent') if status
    if variables[:api].to_i == 1
      status = _('Incorrect_Email_settings')
    else
      status = _('Something_is_wrong_please_consult_help_link')
      status += "<a id='exception_info_link' href='http://wiki.ocean-tel.uk/index.php/Configuration_from_GUI#Emails' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
    end
  end
end
