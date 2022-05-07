# Email model
class Email < ActiveRecord::Base

  attr_protected

  extend UniversalHelpers
  require 'enumerator'
  require 'net/pop'
  # require 'tmail'

  ALLOWED_VARIABLES = %w(
    server_ip device_type device_username device_password login_url login_username username first_name
    last_name full_name balance nice_balance warning_email_balance nice_warning_email_balance
    currency user_email company_email email company primary_device_pin login_password user_ip
    amount date auth_code transaction_id customer_name description company_name url trans_id email
    cc_purchase_details payment_amount payment_payer_first_name user_currency
    payment_payer_last_name payment_payer_email payment_seller_email payment_receiver_email payment_date payment_free
    payment_currency payment_type payment_fee call_list user_id device_id caller_id
    calldate source destination billsec hdd_free_space server_id archive_size current_date date_from date_till
    search_user_username search_user_fullname search_device_description dp_id dp_name asr_deviation acd_deviation tp_name
    changed_tps balance_range_min warning_balance_admin_value balance_range_max auto_aggregate_export_from auto_aggregate_export_till
    auto_aggregate_export_template tariff_job_id tariff_job_analysis_url
    rate_notification_url_agree rate_notification_url_disagree payment_user_balance_before payment_user_balance_after
    invoice_price invoice_price_with_tax invoice_currency invoice_period_start invoice_period_end
    tariff_job_tariff_id tariff_job_tariff_name rate_notification_tariff_name payments_link payments_user_full_name
    two_fa_code user_edit_url current_time two_fa_code_attempt two_fa_login_status two_fa_login_ip
  )

  before_validation -> { self[:from_email].to_s.strip! }
  validates :from_email,
            allow_blank: true,
            format: {
                with: /\A[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,63})\z/,
                message: _('Invalid_email_format_in_from_field')
            },
            length: {
                maximum: 256,
                message: _('From_field_cannot_be_longer_than_256')
            }

  belongs_to :owner, class_name: 'User'
  has_one :tariff_email_detail, dependent: :delete
  has_many :rate_notification_jobs
  before_destroy :check_if_deletable

  def check_if_deletable
    if rate_notification_jobs.present?
      errors.add(:assigned_to_rate_notification, _('Assigned_to_Rate_Notification_Jobs'))
    end

    errors.blank?
  end

  def destroy_everything
    # rate details
    for rd in self.ratedetails
      rd.destroy
    end

    self.destroy
  end

  validate do |email|
    email.must_have_valid_variables
  end

  def self.address_validation(address, allow_only_one = false)
    emails = address.to_s.split(';')
    return false if allow_only_one && emails.size > 1

    emails.each do |mail|
      mail.gsub!(/\s+/, '')
      unless mail.match(/^[a-zA-Z0-9_\+-]+(\.[a-zA-Z0-9_\+-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.([a-zA-Z0-9_]{2,63})$/)
        return false
      end
    end
  end

  # PAY ATTENTION
  # variable names should differ because if you name variable 'a' all other variables will be replace by its content!!!!
  def Email.email_variables(user, device = nil, variables = {}, options = {})
    nnd = options[:nice_number_digits].to_i if options[:nice_number_digits]
    nnd = Confline.get_value("Nice_Number_Digits") if !nnd
    nnd = 2 if !nnd or nnd == ""
    user = User.includes([:devices, :address]).where(['users.id = ?', user.to_i]).first if user.class != User
    date_format = Confline.get_value('Date_format').to_s.split(' ')[0]
    date_format = date_format.blank? ? '%Y-%m-%d' : date_format
    datetime_format = Confline.get_value('Date_format').to_s
    datetime_format = datetime_format.blank? ? '%Y-%m-%d %H:%M:%S' : datetime_format
    device = user.primary_device if !device
    currency = Currency.find(1)
    user_currency_exchange_rate = user.currency.try(:exchange_rate).to_f
    owner_id = (user.usertype == 'reseller') ? user.id : user.owner_id
    company_email = Confline.get_value("Company_Email", owner_id)
    m2_payment = M2Payment.where(user_id: user.id).last
    m2_payment_amount = (m2_payment.try(:amount).to_f * m2_payment.try(:exchange_rate).to_f)
    m2_payment_user_balance_before = m2_payment.try(:user_balance_before).to_f
    m2_payment_user_balance_after = m2_payment.try(:user_balance_after).to_f
    invoice = options[:invoice]
    opts = {
        owner: user.owner_id.to_s,
        server_ip: Confline.get_value('Asterisk_Server_IP').to_s,
        device_type: '',
        device_username: '',
        device_password: '',
        primary_device_pin: '',
        login_url: Web_URL.to_s + Web_Dir.to_s,
        login_username: user.username.to_s,
        username: user.username.to_s,
        login_password: '*****',
        user_ip: '',
        amount: '',
        date: '',
        auth_code: '',
        transaction_id: '',
        customer_name: '',
        description: '',
        first_name: user.first_name.to_s,
        last_name: user.last_name.to_s,
        full_name: nice_user(user),
        balance: Email.nice_number(user.balance.to_f * user_currency_exchange_rate.to_f).to_s,
        nice_balance: User.current ? Email.nice_number(user.balance * Currency.count_exchange_rate(User.current.currency.try(:name), user.currency.try(:name)), {nice_number_digits: nnd, global_decimal: options[:global_decimal], change_decimal: options[:change_decimal]}).to_s : user.currency.try(:name),
        warning_email_balance: user.warning_email_balance.to_s,
        nice_warning_email_balance: Email.nice_number(user.warning_email_balance.to_s, {nice_number_digits: nnd, global_decimal: options[:global_decimal], change_decimal: options[:change_decimal]}),
        currency: user.currency.try(:name),
        user_currency: user.currency.try(:name),
        user_email: user.email,
        cc_purchase_details: '',
        company_email: company_email,
        email: company_email,
        company: Confline.get_value('Company', owner_id),
        payment_amount: Email.nice_number(m2_payment_amount).to_s,
        payment_payer_first_name: '',
        payment_payer_last_name: '',
        payment_payer_email: '',
        payment_seller_email: '',
        payment_receiver_email: '',
        payment_date: '',
        payment_fee: '',
        payment_currency: Currency.where(id: M2Payment.where(user_id: user.id).last.try(:currency_id).to_i).first.try(:name).to_s,
        payment_type: '',
        payment_user_balance_before: Email.nice_number(m2_payment_user_balance_before).to_s,
        payment_user_balance_after: Email.nice_number(m2_payment_user_balance_after).to_s,
        user_id: '',
        device_id: '',
        caller_id: '',
        calldate: '',
        source: '',
        destination: '',
        billsec: '',
        dp_id: '',
        dp_name: '',
        asr_deviation: '',
        acd_deviation: '',
        tp_name: '',
        changed_tps: '',
        balance_range_min: Email.nice_number(user.balance_min).to_s,
        balance_range_max: Email.nice_number(user.balance_max).to_s,
        warning_balance_admin_value: Email.nice_number(user.warning_email_balance_admin).to_s,
        auto_aggregate_export_from: '',
        auto_aggregate_export_till: '',
        auto_aggregate_export_template: '',
        current_date: Date.today.strftime(date_format).to_s,
        tariff_job_id: '',
        tariff_job_analysis_url: '',
        tariff_job_tariff_id: '',
        tariff_job_tariff_name: '',
        rate_notification_url_agree: '',
        rate_notification_url_disagree: '',
        rate_notification_tariff_name: '',
        invoice_price: '',
        invoice_price_with_tax: '',
        invoice_currency: '',
        invoice_period_start: '',
        invoice_period_end: '',
        payments_link: "#{Web_URL}#{Web_Dir}/payments/list?needs_approve=true",
        payments_user_full_name: '',
        two_fa_code: '',
        user_edit_url: "#{Web_URL}#{Web_Dir}/users/edit/#{user.id}",
        current_time: DateTime.now.strftime(datetime_format).to_s,
        two_fa_code_attempt: '',
        two_fa_login_status: '',
        two_fa_login_ip: ''
    }

    if invoice.present?
      global_decimal = Confline.get_value('Global_Number_Decimal').to_s
      change_decimal = global_decimal.to_s == '.' ? false : true
      inv_exchange_rate = invoice.currency_exchange_rate.to_f

      opts = opts.merge!({
        invoice_price: Email.nice_number(invoice.total_amount.to_f).to_s,
        invoice_price_with_tax: Email.nice_number(invoice.total_amount_with_taxes.to_f).to_s,
        invoice_currency: invoice.currency.to_s,
        invoice_period_start: Email.nice_date(invoice.period_start, user: user).to_s,
        invoice_period_end: Email.nice_date(invoice.period_end, user: user).to_s
      })
    end

    if device
      opts = opts.merge({
                            device_type: device.device_type.to_s,
                            device_username: device.username.to_s,
                            device_password: device.secret.to_s,
                            primary_device_pin: device.pin.to_s
                        })
    end
    if variables[:payment] && variables[:payment_notification] && variables[:payment_type]
      opts = opts.merge({
                            payment_amount: variables[:payment].amount,
                            payment_payer_first_name: variables[:payment].first_name,
                            payment_payer_last_name: variables[:payment].last_name,
                            payment_payer_email: variables[:payment].payer_email,
                            payment_seller_email: variables[:payment].user.owner.email,
                            payment_receiver_email: (variables[:payment_notification].respond_to?(:account)) ? variables[:payment_notification].account : variables[:payment_notification].receiver_email,
                            payment_date: variables[:payment].date_added,
                            payment_fee: variables[:payment].fee,
                            payment_currency: variables[:payment].currency,
                            payment_type: variables[:payment_type]
                        })
    end
    opts = opts.merge(variables)
    return opts
  end

  def self.nice_date(date, options = {})
    return unless date
    default_format = Confline.get_value('Date_format', 0)
    date_format = options[:date_format].presence || default_format || '%Y-%m-%d'
    unformatted_date = date.respond_to?(:strftime) ? date : date.to_time
    unformatted_date.strftime(date_format.split(' ')[0].to_s)
  end

  def Email.map_variables_for_api(params)
    opts = {}
    ALLOWED_VARIABLES.each{ |var|
      opts[var.to_sym] = params[var.to_sym].to_s
    }
    return opts
  end

  def Email.nice_number(number, options = {})
    n = "0.00"
    if options[:nice_number_digits].to_i > 0
      n = sprintf("%0.#{options[:nice_number_digits]}f", number.to_d) if number
    else
      nn ||= Confline.get_value("Nice_Number_Digits").to_i
      nn = 2 if nn == 0
      n = sprintf("%0.#{nn}f", number.to_d) if number
    end
    if options[:change_decimal]
      n = n.gsub('.', options[:global_decimal])
    end
    n
  end

  def Email.send_email(email, email_to, email_from, action, options = {})
    user_owner_id = options[:owner].to_i
    User.exists_resellers_confline_settings(user_owner_id) if user_owner_id != 0

    sending_batch_size = Confline.get_value('Email_Batch_Size', user_owner_id).to_i
    sending_batch_size = 50 if sending_batch_size.to_i == 0

    #end
      options[:smtp_server], options[:smtp_user] = Confline.get_value('Email_Smtp_Server', user_owner_id).to_s.strip,
                                                   Confline.get_value('Email_Login', user_owner_id).to_s.strip
      options[:smtp_pass], options[:smtp_port]   = Confline.get_value('Email_Password', user_owner_id).to_s.strip,
                                                   Confline.get_value('Email_Port', user_owner_id).to_s.strip

    string = []
    options[:from] = email_from
    if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
      status = _('Email_sent')
      string << status
      return string
    end
    email_to.each_slice(sending_batch_size) { |users_slice|
      begin
        users_slice.each do |user|
          options[:email_to_address] = user.get_email_to_address

          options[:email_to_address] = user.m2_email if action == 'send_all' && user.usertype != 'admin'

          if options[:email_to_address].present?
            tmail = Email.create_umail(user, action, email, options)
            status = system(tmail)
            options[:status] = status

            if status
              status = _('Email_sent')
            else
              if options[:api].to_i == 1
                status = _('Incorrect_Email_settings')
              else
                status = _('Something_is_wrong_please_consult_help_link')
                status += "<a id='exception_info_link' href='http://wiki.ocean-tel.uk/index.php/Configuration_from_GUI#Emails' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
              end
            end
            Action.create_email_sending_action(user, action, email, options)
          else
            status = _('Emeil_is_empty')
            status += ' ' + user.first_name + ' ' + user.last_name if user.class.to_s == 'User'
          end
          string << status
        end
      end
    }
    return string
  end

  def Email.create_umail(user, type, email, options={})

    from, smtp_server, smtp_user, smtp_pass, smtp_port =  options[:from],
                                                          options[:smtp_server],
                                                          options[:smtp_user],
                                                          options[:smtp_pass],
                                                          options[:smtp_port]

    smtp_connection =  "'#{smtp_server.to_s}:#{smtp_port.to_s}'"
    smtp_connection << " -xu '#{smtp_user}' -xp $'#{smtp_pass.gsub("'", "\\\\'")}'" if smtp_user.present?

    mail_subject = email.subject
    case type
    when 'send_email'
      email_body = EmailsController::nice_email_sent(email, options[:assigns])
      mail_subject = EmailsController::nice_email_sent(email, options[:assigns], 'subject')
    when 'send_all'
      email_body = EmailsController::nice_email_sent(email, Email.email_variables(user))
      mail_subject = EmailsController::nice_email_sent(email, Email.email_variables(user), 'subject')
    end

    tmail = ApplicationController::send_email_dry(from, options[:email_to_address], email_body + ' ', mail_subject, '', smtp_connection, email[:format])

    tmail
  end

  def must_have_valid_variables
    body.scan(/<%=?(\s*\S+\s*)%>|<%[^=]?[0-9a-zA-Z +=]*%>/).flatten.each do |var|
      unless !var.blank? and ALLOWED_VARIABLES.include?(var.to_s.strip)
        errors.add(:body, "#{_('Wrong_email_variables')} <a href='http://wiki.ocean-tel.uk/index.php/Email_variables'>wiki</a>")
        return false
      end
    end
  end

  def self.send_balance_warning_email(email, email_from, user, variables)
    user_owner_id = user.owner_id.to_i
    status = _('email_not_sent')

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_server = Confline.get_value('Email_Smtp_Server', user_owner_id).to_s.strip
      smtp_user = Confline.get_value('Email_Login', user_owner_id).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', user_owner_id).to_s.strip
      smtp_port = Confline.get_value('Email_Port', user_owner_id).to_s.strip

      smtp_connection =  "'#{smtp_server.to_s}:#{smtp_port.to_s}'"
      smtp_connection << " -xu '#{smtp_user}' -xp $'#{smtp_pass.gsub("'", "\\\\'")}'" if smtp_user.present?

      to = variables[:user_email]
      email_body = EmailsController::nice_email_sent(email, variables)
      email_subject = EmailsController::nice_email_sent(email, variables, 'subject')
      begin
        system_call = ApplicationController::send_email_dry(email_from.to_s, to.to_s, email_body, email_subject, '', smtp_connection, email[:format])
        if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
          #do nothing
        else
          email_send_status = system(system_call)
          if email_send_status
            status = _('Email_sent')
          else
            email_error = 1
          end
        end
      rescue
        email_error = 1
      end
    else
      status = _('Email_disabled')
    end

    return status, email_error
  end

  def self.smtp_options(owner_id = 0)
    options = {
      server: Confline.get_value('Email_Smtp_Server', owner_id).to_s.strip,
      user: Confline.get_value('Email_Login', owner_id).to_s.strip,
      pass: Confline.get_value('Email_Password', owner_id).to_s.strip,
      port: Confline.get_value('Email_Port', owner_id).to_s.strip,
      from: Confline.get_value('Email_from', owner_id).to_s.strip
    }
    user = options[:user]
    options[:connection] = "'#{options[:server]}:#{options[:port]}'" +
      (user.present? ? " -xu '#{user}' -xp $'#{options[:pass].gsub("'", "\\\\'")}'" : '')
    options
  end

  def self.send_email_with_attachment(email, email_to, from, file)
    smtp_options = Email.smtp_options

    if defined?(NO_EMAIL) and NO_EMAIL.to_i == 1
      return false
    end

    email_send_status = system(
          ApplicationController::send_email_dry(
              smtp_options[:from], email_to.strip,
              email.body, email.subject,
              "-a '#{file}'",
              smtp_options[:connection], email[:format]
          )
    )

    email_send_status
  end

  def self.tariff_rate_notification_default_template
    where(name: 'tariff_rate_notification', template: 1).first
  end
end
