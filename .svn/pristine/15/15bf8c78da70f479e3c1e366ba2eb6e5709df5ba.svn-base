# Rate Notification Jobs' processing
class RateNotificationJob < ActiveRecord::Base
  require 'csv'
  require 'digest/sha2'
  include UniversalHelpers

  attr_protected

  belongs_to :tariff
  belongs_to :user
  belongs_to :email
  belongs_to :rate_notification_template

  before_destroy :task_related_cleanup

  def task_related_cleanup
    `rm -rf "/tmp/m2/tariff_rate_notifications/rate_notification_data_#{id}.csv"`
    `rm -rf "/tmp/m2/tariff_rate_notifications/rate_notification_data_#{id}.xlsx"`
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS rate_notification_data_#{id};")
  end

  def self.generate_data_for_all_assigned
    assigned_jobs = where(status: :assigned)
    return if assigned_jobs.blank?

    assigned_jobs.each do |assigned_job|
      assigned_job.generate_data_for_assigned
    end
  end

  def generate_data_for_assigned
    return if RateNotificationJob.select(:status).where(id: id).first.status.to_s.downcase != 'assigned'

    update_column(:status, :generating_data)
    MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned - BEGIN", true)

    # Request script to generate data
    Tariff.tariff_rates_effective_from_cache("-t #{tariff_id}")
    script_command = "/usr/local/m2/m2_rates_notification_data #{id}"
    MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned \n  Script run command: #{script_command}", true)
    script_status = system(script_command)
    MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned \n  Script return status: #{script_status}", true)

    if RateNotificationJob.select(:status).where(id: id).first.status.to_s.downcase == 'generation_failed'
      MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned\n  Data Generation Script Failed", true)
      return
    end

=begin
    # Currently work in progress http://trac.ocean-tel.uk/trac/ticket/15598
    # Until then, create dummy data:
    data_table_name = "rate_notification_data_#{id}"
    sql = "
    CREATE TABLE IF NOT EXISTS `#{data_table_name}` (
      `id` INT(11) NOT NULL AUTO_INCREMENT,
      `rate_id` BIGINT(20) NOT NULL,
      `ratedetail_id` BIGINT(20) NOT NULL,
      `prefix` VARCHAR(60) NOT NULL,
      `price` DECIMAL(30,15),
      `effective_from` DATETIME,
      `price_difference_raw` DECIMAL(30,15),
      `price_difference_percentage` DECIMAL(30,15),
      `increment` INT(11) NOT NULL,
      `minimal_time` INT(11) NOT NULL,
      `is_blocked` TINYINT(4),
      `is_deleted` TINYINT(4),
      `is_new` TINYINT(4),
      `destinationgroup_id` INT(11),
      `destinationgroup_name` VARCHAR(255),
      `destination_id` BIGINT(20),
      `destination_name` VARCHAR(255),
      `client_agreement` TINYINT(4) NOT NULL DEFAULT 0,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    "
    ActiveRecord::Base.connection.execute(sql)
    sql_insert = "
    INSERT INTO #{data_table_name}
    (rate_id, ratedetail_id, prefix, price, effective_from, price_difference_raw, price_difference_percentage, increment, minimal_time, destinationgroup_id, destinationgroup_name, destination_id, destination_name)
    VALUES (1, 1, '93', 10, '2020-09-01 00:00:00', 0, NULL, 1, 0, 1, 'Afghanistan', 2, 'Afghanistan proper');
    "
    ActiveRecord::Base.connection.execute(sql_insert)
    # Dummy data created
=end

    generate_data_file

    MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned - SUCCESSFUL END", true)
  end

  def self.send_email_for_all_generated_data
    return false if Confline.get_value('Email_Sending_Enabled', 0).to_i == 0

    assigned_jobs = where("status IN ('data_generated', 'email_sent') AND agreement_timeout_datetime > NOW()")
    return if assigned_jobs.blank?

    assigned_jobs.each do |assigned_job|
      assigned_job.send_email_for_generated_data
    end
  end

  def send_email_for_generated_data
    job_status = RateNotificationJob.select(:status).where(id: id).first.status.to_s.downcase
    return unless %w[data_generated email_sent].include?(job_status)

    if job_status == 'email_sent' && last_email_sent_at.present? && ((last_email_sent_at + 1.day) >= Time.now || send_once == 1)
      return false
    end

    update_column(:status, :sending_email)
    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data - BEGIN", true)


    filename = "/tmp/m2/tariff_rate_notifications/rate_notification_data_#{id}.xlsx"
    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Checking if file exist: #{filename}", true)
    if File.exist?(filename)
      MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  File exist", true)
    else
      MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  File does not exist, trying to regenerate", true)
      generate_data_file

      unless File.exist?(filename)
        MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  File regeneration failed, check permissions", true)
      end
    end

    urls = {
        agree_link: "#{Web_URL}#{Web_Dir}/tariff_rate_notification_jobs/agree?id=#{url_agree}",
        disagree_link: "#{Web_URL}#{Web_Dir}/tariff_rate_notification_jobs/disagree?id=#{url_disagree}"
    }
    smtp_options = Email.smtp_options
    email_variables = Email.email_variables(
        user, nil,
        rate_notification_url_agree: urls[:agree_link],
        rate_notification_url_disagree: urls[:disagree_link],
        rate_notification_tariff_name: tariff.name.to_s
    )
    email_template = Email.where(id: email_id).first
    email_body = EmailsController.nice_email_sent(email_template, email_variables)
    email_subject = EmailsController.nice_email_sent(email_template, email_variables, 'subject')
    email_from = email_template.from_email.presence || smtp_options[:from]
    user_emails = []

    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Trying to select users.rates_email", true)
    if user.rates_email.present?
      user_emails.concat(user.rates_email.to_s.gsub(',', ';').split(';'))
    end

    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Trying to select users.main_email", true)
    if user_emails.blank? && user.main_email.present?
      user_emails.concat(user.main_email.to_s.gsub(',', ';').split(';'))
    end

    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Trying to select users.billing_email", true)
    if user_emails.blank? && user.billing_email.present?
      user_emails.concat(user.billing_email.to_s.gsub(',', ';').split(';'))
    end

    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Trying to select users.noc_email", true)
    if user_emails.blank? && user.noc_email.present?
      user_emails.concat(user.noc_email.to_s.gsub(',', ';').split(';'))
    end

    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Selected User Emails: |#{user_emails.inspect}|", true)

    sent_emails = []
    user_emails.each do |email_to|
      MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data\n  Trying to send to: |#{email_to}|", true)
      next if email_to.to_s.strip.blank?

      system_status = system(
        ApplicationController.send_email_dry(
          email_from, email_to.strip,
          email_body, email_subject,
          "-a '#{filename}'",
          smtp_options[:connection], email_template[:format]
        )
      )
      sent_emails << system_status
    end

    sent_status = 'email_sent'
    sent_status = 'email_was_not_sent' if sent_emails.blank? || sent_emails.include?(false) || sent_emails.include?(nil)

    Action.create_email_sending_action(user, sent_status, email_template, status: sent_status == 'email_sent')
    update_columns(
      status: sent_status,
      last_email_sent_at: Time.now
    )
    MorLog.my_debug("Rate Notification Job ID: #{id} - send_email_for_generated_data - SUCCESSFUL END", true)
  end

  def agreed
    return if RateNotificationJob.select(:status).where(id: id).first.status.to_s.downcase != 'email_sent'
    MorLog.my_debug("Rate Notification Job ID: #{id} - agreed - BEGIN", true)

    update_columns(
        status: :completed,
        client_agreement_datetime: Time.now,
        client_agreement: 1
    )

    all_agreed_sql = "UPDATE #{data_table_name} SET client_agreement = 1;"
    ActiveRecord::Base.connection.execute(all_agreed_sql)

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_options = Email.smtp_options

      user.owner.email({array: 1}).each do |email_to|
        next if email_to.to_s.strip.blank?
        system(
            ApplicationController.send_email_dry(
                smtp_options[:from], email_to.strip,
                "Tariff Rate Notification ID: #{id} was agreed by the client.", 'Tariff Rate Notification - Agreed',
                '', smtp_options[:connection], 'html'
            )
        )
      end
    end

    MorLog.my_debug("Rate Notification Job ID: #{id} - agreed - SUCCESSFUL END", true)
  end

  def disagreed
    return if RateNotificationJob.select(:status).where(id: id).first.status.to_s.downcase != 'email_sent'
    MorLog.my_debug("Rate Notification Job ID: #{id} - disagreed - BEGIN", true)

    update_columns(
        status: :completed,
        client_agreement_datetime: Time.now,
        client_agreement: 2
    )

    agreed_sql = "UPDATE #{data_table_name} SET client_agreement = 1 WHERE price_difference_raw <= 0;"
    ActiveRecord::Base.connection.execute(agreed_sql)

    disagreed_sql = "UPDATE #{data_table_name} SET client_agreement = 2 WHERE client_agreement != 1 AND price_difference_raw > 0;"
    ActiveRecord::Base.connection.execute(disagreed_sql)

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_options = Email.smtp_options

      user.owner.email({array: 1}).each do |email_to|
        next if email_to.to_s.strip.blank?
        system(
            ApplicationController.send_email_dry(
                smtp_options[:from], email_to.strip,
                "Tariff Rate Notification ID: #{id} was disagreed by the client.", 'Tariff Rate Notification - Disagreed',
                '', smtp_options[:connection], 'html'
            )
        )
      end
    end

    create_custom_tariff_for_blocked

    MorLog.my_debug("Rate Notification Job ID: #{id} - disagreed - SUCCESSFUL END", true)
  end

  def self.ignore_for_all_email_sent
    all_ignored = where(status: :email_sent, client_agreement: 0).where('agreement_timeout_datetime < NOW()')
    return if all_ignored.blank?

    all_ignored.each do |ignored_job|
      ignored_job.ignored
    end
  end

  def ignored
    return if RateNotificationJob.select(:status).where(id: id).first.status.to_s.downcase != 'email_sent'
    MorLog.my_debug("Rate Notification Job ID: #{id} - ignored - BEGIN", true)

    update_columns(
        status: :completed,
        client_agreement: 3
    )

    agreed_sql = "UPDATE #{data_table_name} SET client_agreement = 1 WHERE price_difference_raw <= 0;"
    ActiveRecord::Base.connection.execute(agreed_sql)

    disagreed_sql = "UPDATE #{data_table_name} SET client_agreement = 2 WHERE client_agreement != 1 AND price_difference_raw > 0;"
    ActiveRecord::Base.connection.execute(disagreed_sql)

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_options = Email.smtp_options

      user.owner.email({array: 1}).each do |email_to|
        next if email_to.to_s.strip.blank?
        system(
            ApplicationController.send_email_dry(
                smtp_options[:from], email_to.strip,
                "Tariff Rate Notification ID: #{id} was ignored by the client.", 'Tariff Rate Notification - Ignored',
                '', smtp_options[:connection], 'html'
            )
        )
      end
    end

    create_custom_tariff_for_blocked

    MorLog.my_debug("Rate Notification Job ID: #{id} - ignored - SUCCESSFUL END", true)
  end

  def generate_data_file
    tmp_dir = '/tmp/m2/tariff_rate_notifications'
    `mkdir -p #{tmp_dir}`
    filename = "rate_notification_data_#{id}"

    template_xlsx_file = false

    if rate_notification_template
      template_xlsx_file = rate_notification_template.generate_data_file(self, tmp_dir, "#{filename}.xlsx")
    end

    unless template_xlsx_file
      MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned\n  Failed to use Rate Notification Template, trying to generate Data File without Template", true)

      begin
        full_path =  "#{tmp_dir}/#{filename}.csv"

        return true if File.exist?(full_path)

        File.open(full_path, 'wb') { |file| file.write(csv_data) }

        convert_via_libreoffice(tmp_dir, filename, 'csv', 'xlsx')
        system("rm -f #{full_path}")
        return true
      rescue => error
        MorLog.my_debug("Rate Notification Job ID: #{id} - generate_data_for_assigned\n  Failed to Create Data File\n  Crash: #{error}", true)
        update_columns(status: :failed_temp_import, status_reason: :failed_to_create_data_file)
        return false
      end
    end
  end

  def create_custom_tariff_for_blocked
    tariff_copy = tariff.dup
    tariff_copy.id = nil
    tariff_copy.purpose = 'user_custom'

    while_index = 1
    tariff_copy.name = "[RN Blocked Rates #{Time.now.to_date.to_s} (#{while_index})] #{tariff.name} - #{user.nice_user}"
    while Tariff.where(name: tariff_copy.name).first.present?
      while_index += 1
      tariff_copy.name = "[RN Blocked Rates #{Time.now.to_date.to_s} (#{while_index})] #{tariff.name} - #{user.nice_user}"
    end

    tariff_copy.save
    tariff_copy_id = tariff_copy.id

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("UPDATE rates SET old_id = id WHERE tariff_id = #{tariff.id}")
    }

    rate_columns = Rate.column_names - %w[id tariff_id old_id]
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        INSERT INTO rates (tariff_id, old_id, #{rate_columns.join(', ')})
        SELECT #{tariff_copy.id}, rates.old_id, #{rate_columns.map { |column_name| "rates.#{column_name}"}.join(', ')}
        FROM rates
        JOIN #{data_table_name} ON rates.id = #{data_table_name}.rate_id
        WHERE rates.tariff_id = #{tariff.id} AND #{data_table_name}.client_agreement = 2
      ")
    }

    ratedetails_columns = Ratedetail.column_names - %w[id rate_id blocked]
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        INSERT INTO ratedetails (rate_id, blocked, #{ratedetails_columns.join(', ')})
        SELECT new_rates_copy.id, 1, #{ratedetails_columns.map { |column_name| "ratedetails.#{column_name}"}.join(', ')}
        FROM ratedetails
        JOIN rates ON (rates.id = ratedetails.rate_id AND rates.tariff_id = #{tariff.id})
        JOIN rates AS new_rates_copy ON (new_rates_copy.old_id = rates.id AND new_rates_copy.tariff_id = #{tariff_copy.id})
      ")
    }

    ActiveRecord::Base.connection.execute("
      UPDATE devices SET op_custom_tariff_id = #{tariff_copy_id}
      WHERE op_tariff_id = #{tariff.id} AND devices.user_id = #{user.id}
    ")

    tariff_copy_id
  end

  private

  def csv_data
    default_currency = Confline.get_value('tariff_currency_in_csv_export').to_i
    sep, dec = %w[, .]

    exrate = Currency.count_exchange_rate(tariff.currency, user.currency.name)
    currency_name = (default_currency == 0) ? user.currency.name.to_s : tariff.currency.to_s

    sql = "SELECT * FROM rate_notification_data_#{id}"
    results = Array(ActiveRecord::Base.connection.select_all(sql))

    csv_string = CSV.generate(col_sep: sep, quote_char: "\'") do |csv|
      headers = []

      (headers << _('Destination_Group')) if show_destination_group.to_i == 1

      headers.concat([
                         _('Destination'),
                         _('Prefix'),
                         "#{_('Rate')} (#{currency_name})",
                         _('Effective_from'),
                         _('Rate_Difference'),
                         "#{_('Rate_Difference')} %",
                         _('Increment'),
                         _('Minimal_Time'),
                         _('Status')
                     ])

      csv << headers

      results.each do |result|
        if default_currency == 0
          rate, rate_difference = Currency.count_exchange_prices(exrate: exrate, prices: [result['price'].to_d, result['price_difference_raw'].to_d])
        else
          rate = result['price'].to_d
          rate_difference = result['price_difference_raw'].to_d
        end

        effective_from_value = nice_date_time_for_user(result['effective_from'])
        status_value = []
        status_value << _('new') if result['is_new'].to_i == 1
        status_value << _('Blocked') if result['is_blocked'].to_i == 1
        status_value << _('Deleted') if result['is_deleted'].to_i == 1

        row_result = []

        (row_result << "\"#{result['destinationgroup_name'].to_s.gsub(sep, ' ')}\"") if show_destination_group.to_i == 1

        row_result.concat([
                              "\"#{result['destination_name'].to_s.gsub(sep, ' ')}\"",
                              result['prefix'],
                              rate.to_s,
                              (effective_from_value.blank? ? "\"\"" : effective_from_value),
                              rate_difference.to_s,
                              result['price_difference_percentage'].blank? ? "\"\"" : result['price_difference_percentage'].to_s,
                              result['increment'],
                              result['minimal_time'],
                              status_value.blank? ? "\"\"" : status_value.join(', ')
                          ])

        csv << row_result
      end
    end
  end

  def nice_date_time_for_user(time)
    return '' unless time

    format = '%Y-%m-%d %H:%M:%S'
    t = time.respond_to?(:strftime) ? time : time.to_time
    user.user_time(t).strftime(format.to_s)
  end

  def url_agree
    if unique_url_agree.blank?
      secret = generate_secret('agree')
      update_columns(unique_url_agree: secret)
      secret
    else
      unique_url_agree
    end
  end

  def url_disagree
    if unique_url_disagree.blank?
      secret = generate_secret('disagree')
      update_columns(unique_url_disagree: secret)
      secret
    else
      unique_url_disagree
    end
  end

  def generate_secret(type)
    secret = Digest::SHA1.hexdigest("#{id}#{tariff_id}#{tariff.name}#{user_id}#{user.username}#{created_at}#{type}#{user.owner.username}#{user.owner.email}")

    while true
      duplicate_secret = RateNotificationJob.where("unique_url_agree = '#{secret}' OR unique_url_disagree = '#{secret}'").first

      if duplicate_secret.blank?
        break
      else
        secret << rand(10).to_s
      end
    end

    secret
  end

  def data_table_name
    "rate_notification_data_#{id}"
  end
end
