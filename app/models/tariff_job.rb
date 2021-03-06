# Tariff Import v2 Tariff Jobs
class TariffJob < ActiveRecord::Base
  require 'net/http'
  require 'base64'
  include UniversalHelpers

  attr_protected

  belongs_to :tariff_import_rule
  belongs_to :tariff_attachment

  before_destroy :not_deletable_by_status, :task_related_cleanup

  def self.build_and_create(tariff_import_rule_id, tariff_attachment_id)
    tariff_job = TariffJob.new
    tariff_job.tariff_import_rule_id = tariff_import_rule_id
    tariff_job.tariff_attachment_id = tariff_attachment_id

    location = tariff_job.tariff_import_rule.effective_date_from

    unless location == 'template'
      effective_date = TariffJob.parse_effective_date(tariff_job, location)

      return false unless effective_date
      tariff_job.effective_date = effective_date
    end

    tariff_job.created_at = DateTime.now
    tariff_job.status = 'assigned'

    if tariff_job.save
      sent = (EmailSender.send_tariff_import_notification(tariff_job.tariff_import_rule, 'received', tariff_job.notification_variables) == _('Email_sent'))
      tariff_job.update_column(:trigger_received_email_notification_sent, (sent ? 1 : 0))
    end

    tariff_job
  end

  def self.delete_older
    older_than = Confline.get_value('Delete_Tariff_Jobs_older_than').to_i
    older_than = 30 if older_than < 7

    jobs = where("created_at < (NOW() - INTERVAL #{older_than} DAY)").all
    jobs.each { |job| job.destroy }
  end

  protected

  def tariff_conversion_custom_url
    'https://support.kolmisoft.com/api/tariff_conversion_custom'
  end

  def rate_import_rule_analysis_column_names
    %w[
      rate_increase rate_decrease new_rate rate_deletion rate_blocked oldest_effective_date maximum_effective_date
      max_increase max_decrease max_rate zero_rate duplicate_rate min_times increments code_moved_to_new_zone
    ]
  end

  public

  def self.completed_statuses
    %w[
      completed failed_conversion failed_temp_import
      failed_analysis rejected cancelled imported failed_import
    ]
  end

  def self.deletable_statuses
    %w[
      completed assigned converted temp_imported failed_conversion failed_temp_import failed_analysis rejected
      cancelled imported failed_import
    ]
  end

  def self.max_processing_minutes_allowed
    30
  end

  def self.max_restarts_allowed
    2
  end

  def self.convert_all_assigned
    assigned_jobs = where(status: :assigned)
    return if assigned_jobs.blank?

    assigned_jobs.each do |assigned_job|
      assigned_job.convert_assigned
    end
  end

  def self.parse_effective_date(job, location)
    prefix = job.tariff_import_rule.effective_date_prefix.to_s
    date_format = job.tariff_import_rule.effective_date_format
    date_string = if location == 'subject'
                    job.tariff_attachment.tariff_email.subject.split(prefix)[1]
                  elsif location == 'email_body'
                    TariffJob.process_email_body(job.tariff_attachment.tariff_email.message_plain).split(prefix)[1]
                  elsif location == 'file_name'
                    job.tariff_attachment.file_name.split(prefix.gsub(/[^[:ascii:]]| /) { |match| "_" * match.bytesize })[1].to_s.gsub('_', '')
                  end
    begin
      DateTime.strptime(TariffJob.remove_formatting(date_string), date_format.to_s)
    rescue => error
      MorLog.my_debug("TariffJob not created\n  Error: #{error}", true)
      MorLog.my_debug("  Date string: #{date_string}\n  Date format: #{date_format}", false)
      return false
    end
  end

  def convert_assigned
    return if TariffJob.select(:status).where(id: id).first.status != 'assigned'
    update_column(:status, :converting)

    MorLog.my_debug("Tariff Job ID: #{id} - convert_assigned - BEGIN", true)

    if tariff_attachment.blank?
      MorLog.my_debug("Tariff Job ID: #{id} - convert_assigned\n  tariff_attachment not found", true)
      update_columns(status: :failed_conversion, status_reason: :tariff_attachment_not_found)
      return
    end

    request_data = {
        filename: 'tariff_job_assigned_for_conversion.zip',
        base64encoded: encoded_file_for_conversion
    }

    attempt = 0
    failed_conversion = 0
    finished = false

    while finished == false
      begin
        url = URI.parse(tariff_conversion_custom_url)
        req = Net::HTTP::Post.new(url)
        req.form_data = request_data
        response = {}
        Net::HTTP.start(url.hostname, url.port, :use_ssl => url.scheme == 'https', :read_timeout => 600) do |http|
          response = JSON.parse(http.request(req).body)
        end
      rescue => error
        MorLog.my_debug("Tariff Job ID: #{id}  - convert_assigned\n  Probably CRM Server Error - crash: #{error}\n  Attempt: #{attempt + 1}", true)
        update_columns(status: :failed_conversion, status_reason: :external_server_error)
        failed_conversion = 1
        break
      end

      if response.blank? || !['ok', 'not authorized', 'No Active Service Plan'].include?(response['status'])
        MorLog.my_debug("Tariff Job ID: #{id} - convert_assigned\n  Bad Response: #{response.inspect}\n  Attempt: #{attempt + 1}", true)
        attempt += 1
        next if attempt < 3
        update_columns(status: :failed_conversion, status_reason: :external_server_error_bad_response)
        failed_conversion = 1
        break
      end

      if response['status'] == 'not authorized'
        MorLog.my_debug("Tariff Job ID: #{id} - convert_assigned\n  Response: not authorized\n  Attempt: #{attempt + 1}", true)
        update_columns(status: :failed_conversion, status_reason: :external_server_error_not_authorized)
        failed_conversion = 1
        break
      end

      if response['status'] == 'No Active Service Plan'
        MorLog.my_debug("Tariff Job ID: #{id} - convert_assigned\n  Response: No Active Service Plan\n  Attempt: #{attempt + 1}", true)
        update_columns(status: :failed_conversion, status_reason: :external_server_error_no_active__service_plan)
        failed_conversion = 1
        break
      end

      finished = true
    end

    return if failed_conversion == 1

    full_path = "/tmp/m2/tariff_jobs/converted_#{id}/"
    `mkdir -p #{full_path}`

    File.open("#{full_path}#{response['filename']}", 'wb') do |file|
      file.write(Base64.decode64(response['base64encoded']))
    end

    update_columns(status: :converted, file_received_at: Time.now, restarts: 0)

    MorLog.my_debug("Tariff Job ID: #{id} - convert_assigned - SUCCESSFUL METHOD END", true)
  end

  def not_deletable_by_status
    unless TariffJob.deletable_statuses.include?(status)
      errors.add(:job_is_being_processed, _('Tariff_Job_is_being_processed_try_again_later'))
    end

    # Exceptions by status, that can override non-deletable statuses
    if status == 'analyzed' && reviewed == 0
      errors.delete(:job_is_being_processed)
    end

    errors.blank?
  end

  def task_related_cleanup
    `rm -rf "/tmp/m2/tariff_jobs/converted_#{id}/"`
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{temp_import_table_name};")
  end

  def self.temp_import_all_converted
    converted_jobs = where(status: :converted)
    return if converted_jobs.blank?

    converted_jobs.each do |converted_job|
      converted_job.temp_import_converted
    end
  end

  def temp_import_converted
    return if TariffJob.select(:status).where(id: id).first.status != 'converted'
    update_column(:status, :temp_importing)

    MorLog.my_debug("Tariff Job ID: #{id} - temp_import_converted - BEGIN", true)

    full_path = "/tmp/m2/tariff_jobs/converted_#{id}"

    unless File.file?("#{full_path}/converted_tariffs.zip")
      MorLog.my_debug("Tariff Job ID: #{id} - temp_import_converted\n  Converted Tariff ZIP File not found", true)
      update_columns(status: :failed_temp_import, status_reason: :converted_tariff_zip_file_not_found)
      return
    end

    `mkdir -p '#{full_path}/extracted'`
    `unzip '#{full_path}/converted_tariffs.zip' -d '#{full_path}/extracted/'`

    # Note: xargs mv command overwrites files with identical names
    `find '#{full_path}/extracted/' \\( -name '*.csv' \\) | xargs -I files mv files '#{full_path}/'`
    `rm -rf '#{full_path}/extracted'`
    `rm -f '#{full_path}/converted_tariffs.zip'`

    file_to_import = Dir["#{full_path}/*"].select { |f| File.file?(f) }.map { |f| File.basename(f) }.first

    if file_to_import.blank? || !File.file?("#{full_path}/#{file_to_import}")
      MorLog.my_debug("Tariff Job ID: #{id} - temp_import_converted\n  Converted Tariff File not found\n  Expected Filename: #{file_to_import}", true)
      update_columns(status: :failed_temp_import, status_reason: :converted_tariff_file_not_found)
      return
    end

    headers = File.open("#{full_path}/#{file_to_import}", &:gets).to_s.chomp.split(',')

    if headers.blank? || (headers - TariffTemplate.valid_headers).present?
      MorLog.my_debug("Tariff Job ID: #{id} - temp_import_converted\n  Converted Tariff File had invalid Header\n  Headers: #{headers.inspect}", true)
      update_columns(status: :failed_temp_import, status_reason: :converted_tariff_had_invalid_header)
      return
    end

    temp_table = {
        name: temp_import_table_name,
        columns: [{name: 'id', type: 'INT(11)', additional: 'NOT NULL AUTO_INCREMENT'}],
        keys: ['PRIMARY KEY (`id`)'],
        import_columns: []
    }

    temp_table[:columns] << {name: 'prefix', type: 'VARCHAR(50)'}
    temp_table[:columns] << {name: 'destination', type: 'VARCHAR(200)'}
    temp_table[:columns] << {name: 'connection_fee', type: 'DECIMAL(30,15)'}
    temp_table[:columns] << {name: 'rate', type: 'DECIMAL(30,15)'}
    temp_table[:columns] << {name: 'increment', type: 'INT(11)'}
    temp_table[:columns] << {name: 'min_time', type: 'INT(11)'}
    #temp_table[:columns] << {name: 'second_interval_rate', type: 'DECIMAL(30,15)'}
    #temp_table[:columns] << {name: 'second_interval_increment', type: 'INT(11)'}
    #temp_table[:columns] << {name: 'second_interval_min_time', type: 'INT(11)'}
    #temp_table[:columns] << {name: 'off_peak_first_interval_rate', type: 'DECIMAL(30,15)'}
    #temp_table[:columns] << {name: 'off_peak_first_interval_increment', type: 'INT(11)'}
    #temp_table[:columns] << {name: 'off_peak_first_interval_min_time', type: 'INT(11)'}
    #temp_table[:columns] << {name: 'off_peak_second_interval_rate', type: 'DECIMAL(30,15)'}
    #temp_table[:columns] << {name: 'off_peak_second_interval_increment', type: 'INT(11)'}
    #temp_table[:columns] << {name: 'off_peak_second_interval_min_time', type: 'INT(11)'}
    temp_table[:columns] << {name: 'effective_from', type: 'DATETIME'}
    temp_table[:columns] << {name: 'end_date', type: 'DATETIME'}
    temp_table[:columns] << {name: 'blocked', type: 'TINYINT(4)'}
    temp_table[:columns] << {name: 'deleted', type: 'TINYINT(4)'}

    headers.each do |header|
      case header
        when 'Prefix'
          temp_table[:columns] << {name: 'file_import_prefix', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_prefix'
        when 'Destination'
          temp_table[:columns] << {name: 'file_import_destination', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_destination'
        when 'Connection Fee'
          temp_table[:columns] << {name: 'file_import_connection_fee', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_connection_fee'
        when 'Rate'
          temp_table[:columns] << {name: 'file_import_rate', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_rate'
        when 'Increment'
          temp_table[:columns] << {name: 'file_import_increment', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_increment'
        when 'Min. time'
          temp_table[:columns] << {name: 'file_import_min_time', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_min_time'
        when 'Second Interval Rate'
          temp_table[:columns] << {name: 'file_import_second_interval_rate', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_second_interval_rate'
        when 'Second Interval Increment'
          temp_table[:columns] << {name: 'file_import_second_interval_increment', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_second_interval_increment'
        when 'Second Interval Min. time'
          temp_table[:columns] << {name: 'file_import_second_interval_min_time', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_second_interval_min_time'
        when 'Off-Peak First Interval Rate'
          temp_table[:columns] << {name: 'file_import_off_peak_first_interval_rate', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_off_peak_first_interval_rate'
        when 'Off-Peak First Interval Increment'
          temp_table[:columns] << {name: 'file_import_off_peak_first_interval_increment', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_off_peak_first_interval_increment'
        when 'Off-Peak First Interval Min. time'
          temp_table[:columns] << {name: 'file_import_off_peak_first_interval_min_time', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_off_peak_first_interval_min_time'
        when 'Off-Peak Second Interval Rate'
          temp_table[:columns] << {name: 'file_import_off_peak_second_interval_rate', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_off_peak_second_interval_rate'
        when 'Off-Peak Second Interval Increment'
          temp_table[:columns] << {name: 'file_import_off_peak_second_interval_increment', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_off_peak_second_interval_increment'
        when 'Off-Peak Second Interval Min. time'
          temp_table[:columns] << {name: 'file_import_off_peak_second_interval_min_time', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_off_peak_second_interval_min_time'
        when 'Effective from'
          temp_table[:columns] << {name: 'file_import_effective_from', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_effective_from'
        when 'End Date'
          temp_table[:columns] << {name: 'file_import_end_date', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_end_date'
        when 'Status Blocked'
          temp_table[:columns] << {name: 'file_import_blocked', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_blocked'
        when 'Status Deleted'
          temp_table[:columns] << {name: 'file_import_deleted', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'file_import_deleted'
      end
    end

    rate_import_rule_analysis_column_names.each do |header|
      temp_table[:columns] << {name: "import_rule_#{header}", type: 'TINYINT(4)', additional: 'NOT NULL DEFAULT 0'}
      temp_table[:keys] << "KEY `import_rule_#{header}_index` (`import_rule_#{header}`)"
    end

    temp_table[:columns] << {name: 'non_importable', type: 'TINYINT(4)', additional: 'NOT NULL DEFAULT 0'}
    temp_table[:columns] << {name: 'non_importable_reasons', type: 'VARCHAR(255)', additional: "NOT NULL DEFAULT ''"}

    temp_table[:columns] << {name: 'current_rate_id', type: 'BIGINT(20)'}
    temp_table[:columns] << {name: 'current_rate_prefix', type: 'VARCHAR(60)'}
    temp_table[:columns] << {name: 'current_rate_destination_id', type: 'BIGINT(20)'}
    temp_table[:columns] << {name: 'current_rate_destinationgroup_id', type: 'INT(11)'}
    temp_table[:columns] << {name: 'current_rate_ghost_min_perc', type: 'DECIMAL(30,15)'}
    temp_table[:columns] << {name: 'current_rate_effective_from', type: 'DATETIME'}

    temp_table[:columns] << {name: 'current_ratedetails_start_time', type: 'TIME'}
    temp_table[:columns] << {name: 'current_ratedetails_end_time', type: 'TIME'}
    temp_table[:columns] << {name: 'current_ratedetails_rate', type: 'DECIMAL(30,15)'}
    temp_table[:columns] << {name: 'current_ratedetails_connection_fee', type: 'DECIMAL(30,15)'}
    temp_table[:columns] << {name: 'current_ratedetails_increment_s', type: 'INT(11)'}
    temp_table[:columns] << {name: 'current_ratedetails_min_time', type: 'INT(11)'}
    temp_table[:columns] << {name: 'current_ratedetails_daytype', type: "ENUM('','FD','WD')"}
    temp_table[:columns] << {name: 'current_ratedetails_blocked', type: 'TINYINT(4)'}

    temp_table[:columns] << {name: 'current_destination_id', type: 'BIGINT(20)'}
    temp_table[:columns] << {name: 'current_destination_prefix', type: 'VARCHAR(50)'}
    temp_table[:columns] << {name: 'current_destination_name', type: 'VARCHAR(255)'}

    temp_table[:columns] << {name: 'new_destination_direction_code', type: 'VARCHAR(20)'}
    temp_table[:columns] << {name: 'new_destination_name', type: 'VARCHAR(255)'}

    begin
      CsvImportDb.tariff_job_temp_import(temp_table, "#{full_path}/#{file_to_import}")
    rescue => error
      MorLog.my_debug("Tariff Job ID: #{id} - temp_import_converted\n  Failed to Import Converted Tariff File\n  Crash: #{error}", true)
      update_columns(status: :failed_temp_import, status_reason: :failed_to_import_converted_tariff_file)
      return
    end

    `rm -rf "#{full_path}"`
    update_columns(status: :temp_imported, restarts: 0)

    MorLog.my_debug("Tariff Job ID: #{id} - temp_import_converted - SUCCESSFUL METHOD END", true)
  end

  def self.all_analyze_import_by_tariff
    jobs_by_tariff = select('tariff_jobs.*, tariff_import_rules.tariff_id').
        joins(:tariff_import_rule).
        where(status: %w[temp_imported analyzing analyzed importing]).
        order('tariff_import_rules.tariff_id ASC').
        all.
        group_by { |job| job.tariff_id }

    return if jobs_by_tariff.blank?

    jobs_by_tariff.each do |tariff_id, tariff_jobs|
      oldest_job = tariff_jobs.sort_by { |job| [job.created_at, job.id] }.first

      case oldest_job.status
        when 'temp_imported'
          oldest_job.analyze_temp_imported
          oldest_job.import_analyzed
        when 'analyzed'
          oldest_job.import_analyzed
      end
    end
  end

  def analyze_temp_imported
    return if TariffJob.select(:status).where(id: id).first.status != 'temp_imported'
    update_column(:status, :analyzing)

    MorLog.my_debug("Tariff Job ID: #{id} - analyze_temp_imported - BEGIN", true)

    alter_tmp_table_for_new_columns

    # Stop processing if at least one rate has more than one ratedetail
    rate_with_multiple_ratedetails_found = ActiveRecord::Base.connection.select_value("
      SELECT rates.id, COUNT(ratedetails.id) AS ratedetails_count
      FROM rates
      LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
      WHERE tariff_id = #{tariff_import_rule.tariff_id}
      GROUP BY rates.id
      HAVING ratedetails_count > 1
    ").present?
    if rate_with_multiple_ratedetails_found
      MorLog.my_debug("Tariff Job ID: #{id} - analyze_temp_imported\n  Failed to Analyze Temp Imported\n  Rate with multiple Ratedetails found", true)
      update_columns(status: :failed_analysis, status_reason: :rate_with_multiple_ratedetails_found)
      return false
    end

    importable_headers = %w[prefix destination connection_fee rate increment min_time effective_from end_date blocked deleted]

    importable_headers.each do |header|
      next unless ActiveRecord::Base.connection.column_exists?(temp_import_table_name, "file_import_#{header}")

      case header
        when 'connection_fee', 'increment', 'min_time'
          retry_lock_error(5) {
            ActiveRecord::Base.connection.execute("
              UPDATE #{temp_import_table_name}
              SET #{header} = file_import_#{header}
              WHERE file_import_#{header} IS NOT NULL AND file_import_#{header} != '' AND file_import_#{header} != -1;
            ")
          }
        else
          retry_lock_error(5) {
            ActiveRecord::Base.connection.execute("
              UPDATE #{temp_import_table_name}
              SET #{header} = file_import_#{header}
              WHERE file_import_#{header} IS NOT NULL AND file_import_#{header} != '';
            ")
          }
      end
    end

    # Connection Fee default value, if not present or incorrect in import file
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET connection_fee = #{tariff_import_rule.try(:default_connection_fee) || 0}
        WHERE connection_fee IS NULL;
      ")
    }

    # Connection Fee default value, if not present or incorrect in import file
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET increment = #{tariff_import_rule.try(:default_increment) || 1}
        WHERE increment IS NULL;
      ")
    }

    # Connection Fee default value, if not present or incorrect in import file
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET min_time = #{tariff_import_rule.try(:default_min_time) || 0}
        WHERE min_time IS NULL;
      ")
    }

    # Effective From preset or default value, if not present or incorrect in import file
    if effective_date.present?
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("UPDATE #{temp_import_table_name} SET effective_from = '#{effective_date}';")
      }
    else
      case tariff_import_rule.try(:default_effective_from).to_i
        when 1
          retry_lock_error(5) {
            ActiveRecord::Base.connection.execute("
              UPDATE #{temp_import_table_name}
              SET effective_from = NOW()
              WHERE effective_from = '0000-00-00 00:00:00' OR effective_from IS NULL;
            ")
          }
        else
          retry_lock_error(5) {
            ActiveRecord::Base.connection.execute("
              UPDATE #{temp_import_table_name}
              SET non_importable = 1,
                  non_importable_reasons = CONCAT(non_importable_reasons, 'effective_from_invalid;')
              WHERE effective_from = '0000-00-00 00:00:00' OR effective_from IS NULL;
            ")
          }
      end
    end

    # Update Effective From to specific Timezone
    #   Self Testing Sanity Check
    #     * X Import File         - 2021-04-06 00:00:00
    #     * A Tariff Job Timezone - Hawaii (-10 GMT)
    #     * B System Timezone     - UTC    ( +0 GMT)
    #     * C User Timezone       - Hawaii (-10 GMT)
    #   Scenarios
    #     When updating/saving Effective From to specific Timezone in DB
    #       X - (A - B)          => 2021-04-06 10:00:00
    #     When User views it in analysis
    #       X + (C - B)          => 2021-04-06 00:00:00
    import_rule_time_zone = tariff_import_rule.try(:effective_date_timezone).to_s
    import_rule_time_zone = User.first.time_zone.to_s if import_rule_time_zone.blank?
    timezone_offset = (Time.now.in_time_zone(import_rule_time_zone).utc_offset.second - Time.now.utc_offset.second).to_i

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET effective_from = (effective_from - INTERVAL #{timezone_offset} SECOND);
      ")
    }

    # CEIL effective_from to minute precision
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET effective_from = FROM_UNIXTIME(CEIL(UNIX_TIMESTAMP(effective_from)/60)*60);
      ")
    }

    # Check for non-importable Rates
    # retry_lock_error(5) {
    #   ActiveRecord::Base.connection.execute("
    #     UPDATE #{temp_import_table_name}
    #     SET non_importable = 1,
    #         non_importable_reasons = CONCAT(non_importable_reasons, 'rate_invalid;')
    #     WHERE rate IS NULL;
    #   ")
    # }

    # SET rate -1 if blocked, but rate is null
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET rate = -1
        WHERE blocked = 1 AND (rate IS NULL OR rate = 0);
      ")
    }

    # Fix Rates
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET rate = 0
        WHERE rate IS NULL;
      ")
    }

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET non_importable = 1,
            non_importable_reasons = CONCAT(non_importable_reasons, 'prefix_is_not_numeric;')
        WHERE prefix REGEXP '^[0-9]+$' = 0;
      ")
    }

    # Find matching Rates via prefix and update Temp Rates Table data with them
    Tariff.tariff_rates_effective_from_cache("-t #{tariff_import_rule.tariff_id}")
    currently_effective_exist_after_script = false
    begin
      # Percona adds rates.currently_effective column, prevent crash if Percona failed to add required columns
      currently_effective_exist_after_script = if Rate.where(tariff_id: tariff_import_rule.tariff_id, currently_effective: 1).first.present?
                                                 true
                                               elsif Rate.where(tariff_id: tariff_import_rule.tariff_id).first.blank?
                                                 true
                                               elsif Rate.where(tariff_id: tariff_import_rule.tariff_id).where('effective_from IS NULL OR effective_from < NOW()').first.present?
                                                 false
                                               else
                                                 true
                                               end
    rescue
      MorLog.my_debug("Tariff Job ID: #{id} - analyze_temp_imported\n  Failed to Analyze Temp Imported\n  rates.currently_effective column is missing, was not added by Percona", true)
      currently_effective_exist_after_script = false
    end

    unless currently_effective_exist_after_script
      MorLog.my_debug("Tariff Job ID: #{id} - analyze_temp_imported\n  Failed to Analyze Temp Imported\n  script 'm2_rates_effective_from_cache' did not run or was wrong", true)
      update_columns(status: :failed_analysis, status_reason: :rates_effective_from_cache_mismatch)
      return false
    end

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        LEFT JOIN rates ON #{temp_import_table_name}.prefix = rates.prefix AND rates.currently_effective = 1 AND rates.tariff_id = #{tariff_import_rule.tariff_id}
        SET current_rate_id = rates.id,
            current_rate_prefix = rates.prefix,
            current_rate_destination_id = rates.destination_id,
            current_rate_destinationgroup_id = rates.destinationgroup_id,
            current_rate_ghost_min_perc = rates.ghost_min_perc,
            current_rate_effective_from = rates.effective_from
        WHERE non_importable = 0 AND rates.id IS NOT NULL;
      ")
    }

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        ALTER TABLE #{temp_import_table_name} ADD INDEX `current_rate_id_index` ( `current_rate_id` )
      ")
    }

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        ALTER TABLE #{temp_import_table_name} ADD INDEX `current_rate_prefix_index` ( `current_rate_prefix` )
      ")
    }

    # Update Rates' Details accordingly
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        LEFT JOIN ratedetails ON #{temp_import_table_name}.current_rate_id = ratedetails.rate_id
        SET current_ratedetails_start_time = ratedetails.start_time,
            current_ratedetails_end_time = ratedetails.end_time,
            current_ratedetails_rate = ratedetails.rate,
            current_ratedetails_connection_fee = ratedetails.connection_fee,
            current_ratedetails_increment_s = ratedetails.increment_s,
            current_ratedetails_min_time = ratedetails.min_time,
            current_ratedetails_daytype = ratedetails.daytype,
            current_ratedetails_blocked = ratedetails.blocked
        WHERE #{temp_import_table_name}.current_rate_id IS NOT NULL;
      ")
    }

    # Find matching Destinations via prefix and update Temp Rates Table data with them
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        LEFT JOIN destinations ON destinations.prefix = #{temp_import_table_name}.prefix
        SET current_destination_id = destinations.id,
            current_destination_prefix = destinations.prefix,
            current_destination_name = destinations.name
        WHERE non_importable = 0 AND destinations.id IS NOT NULL;
      ")
    }

    # For Prefixes that did not find exact matching Destination do:
    #   Find Destination via most (longest) matching Prefix from left to right
    #     If Found
    #       Set for Creation of new Destination (Direction Code, Name) whose Name is taken from:
    #         either Importing Row column (destination)
    #         or found matched Destination Name
    #     Else
    #       Mark row as non importable with according reason

    # [['prefix', 'destination_name', 'temp_table_id'], ...]
    # ex.: [["93", "Afghanistan Fixed", "1"], ["7840", "Abkhazia Fixed", "2"]]
    temp_new_destinations = ActiveRecord::Base.connection.select_rows("
      SELECT prefix, destination, id
      FROM #{temp_import_table_name}
      WHERE non_importable = 0 AND current_destination_id IS NULL
      GROUP BY prefix
    ")

    if temp_new_destinations.present?
      # {'prefix' => ['direction_code', 'destination_name'], ...}
      # ex.: {"93"=>["AFG", "Afghanistan proper"], "9375"=>["AFG", "Afghanistan Cdma"], "9380"=>["AFG", "Afghanistan freephone"]}
      all_destinations_by_prefix = Hash[
        ActiveRecord::Base.connection.select_rows('SELECT prefix, direction_code, name FROM destinations').map do |row|
          [row[0].to_s.gsub(/\s/, ''), [row[1], row[2]]]
        end
      ]

      # {'direction_code' => ['temp_table_id', ...]}
      # ex.: {'AFG' => [1, 2, 3], 'RUS' => [4, 5]}
      temp_destinations_update_direction_code = {}

      # {'destination_name' => ['temp_table_id', ...]}
      # ex.: {'Afghanistan proper' => [1, 2], 'Afghanistan Cdma' => [3]}
      temp_destinations_update_name = {}

      temp_new_destinations.each do |new_destination|
        new_destination_prefix = new_destination[0].to_s

        new_destination_prefix.size.times do |i|
          closest_match = all_destinations_by_prefix[new_destination_prefix[0...(-1-i)]]

          if closest_match.present?
            (temp_destinations_update_direction_code[closest_match[0]] ||= []) << new_destination[2]

            if new_destination[1].blank?
              (temp_destinations_update_name[closest_match[1]] ||= []) << new_destination[2]
            end

            break
          end
        end
      end

      if temp_destinations_update_direction_code.present?
        temp_destinations_update_direction_code.each do |direction_code, temp_ids|
          retry_lock_error(5) {
            ActiveRecord::Base.connection.execute("
              UPDATE #{temp_import_table_name}
              SET new_destination_direction_code = '#{direction_code}'
              WHERE id IN (#{temp_ids.join(', ')})
            ")
          }
        end
      end

      if temp_destinations_update_name.present?
        temp_destinations_update_name.each do |destination_name, temp_ids|
          retry_lock_error(5) {
            ActiveRecord::Base.connection.execute("
              UPDATE #{temp_import_table_name}
              SET new_destination_name = '#{destination_name}'
              WHERE id IN (#{temp_ids.join(', ')})
            ")
          }
        end
      end
    end

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET new_destination_name = destination
        WHERE new_destination_direction_code IS NOT NULL AND new_destination_name IS NULL
      ")
    }

    # Check for non-importable Rates
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name}
        SET non_importable = 1,
            non_importable_reasons = CONCAT(non_importable_reasons, 'could_not_determine_direction_code;')
        WHERE non_importable = 0
              AND current_destination_id IS NULL AND new_destination_direction_code IS NULL;
      ")
    }

    # Rate Increase:
    #   If updating existing Rate, whose Rate (Price) increased and takes into effect earlier (by days compared to importing effective from) than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:rate_increase)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_rate_increase = #{rule_numeric_action}
          WHERE non_importable = 0
                AND current_rate_id IS NOT NULL
                AND rate > current_ratedetails_rate
                AND DATEDIFF(effective_from, NOW()) < #{rule_value}
          ;
        ")
      }
    end

    # Rate Decrease:
    #   If updating existing Rate, whose Rate (Price) decreased and takes into effect earlier (by days compared to importing effective from) than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:rate_decrease)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_rate_decrease = #{rule_numeric_action}
          WHERE non_importable = 0
                AND current_rate_id IS NOT NULL
                AND rate < current_ratedetails_rate
                AND DATEDIFF(effective_from, NOW()) < #{rule_value}
          ;
        ")
      }
    end

    # New Rate:
    #   If creating new non-existing Rate, which takes into effect earlier (by days compared to importing effective from) than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:new_rate)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_new_rate = #{rule_numeric_action}
          WHERE non_importable = 0
                AND current_rate_id IS NULL
                AND DATEDIFF(effective_from, NOW()) < #{rule_value}
          ;
        ")
      }
    end

    # TODO: Rate Deletion:
    #   If deleting existing Rate, which takes into effect earlier (by days compared to importing effective from) than set in Rule

    # TODO: Rate Blocked:
    #   If blocking existing Rate, which takes into effect earlier (by days compared to importing effective from) than set in Rule

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        UPDATE #{temp_import_table_name} SET blocked = 1 WHERE rate = -1 AND blocked = 0;")
    }


    # Oldest Effective Date:
    #   If updating existing or creating new Rate, whose new Effective From is earlier (by days) than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:oldest_effective_date)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_oldest_effective_date = #{rule_numeric_action}
          WHERE non_importable = 0
                AND DATEDIFF(effective_from, NOW()) < #{rule_value}
          ;
        ")
      }
    end

    # Maximum Effective Date:
    #   If updating existing or creating new Rate, whose new Effective From is later (by days) than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:maximum_effective_date)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_maximum_effective_date = #{rule_numeric_action}
          WHERE non_importable = 0
                AND DATEDIFF(effective_from, NOW()) > #{rule_value}
          ;
        ")
      }
    end

    # Max Increase:
    #   If updating existing Rate, whose Rate (Price) increased more by percentages than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:max_increase)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_max_increase = #{rule_numeric_action}
          WHERE non_importable = 0
                AND current_rate_id IS NOT NULL
                AND rate > (current_ratedetails_rate + (current_ratedetails_rate / 100 * #{rule_value}))
          ;
        ")
      }
    end

    # Max Decrease:
    #   If updating existing Rate, whose Rate (Price) decreased more by percentages than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:max_decrease)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_max_decrease = #{rule_numeric_action}
          WHERE non_importable = 0
                AND current_rate_id IS NOT NULL
                AND rate < (current_ratedetails_rate - (current_ratedetails_rate / 100 * #{rule_value}))
          ;
        ")
      }
    end

    # Max Rate:
    #   If updating existing or creating new Rate, whose Rate (Price) is higher than set in Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:max_rate)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_max_rate = #{rule_numeric_action}
          WHERE non_importable = 0
                AND rate > #{rule_value}
          ;
        ")
      }
    end

    # Zero Rate:
    #   If updating existing or creating new Rate, whose Rate (Price) is zero
    rule_numeric_action = tariff_import_rule.tariff_rate_import_rule.numeric_action(:zero_rate)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_zero_rate = #{rule_numeric_action}
          WHERE non_importable = 0
                AND rate = 0
          ;
        ")
      }
    end

    # Duplicate Rate:
    #   If updating existing or creating new Rate, whose Rate Prefix has duplicates
    rule_numeric_action = tariff_import_rule.tariff_rate_import_rule.numeric_action(:duplicate_rate)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          JOIN (SELECT prefix FROM #{temp_import_table_name} GROUP BY prefix HAVING COUNT(id) > 1) duplicates ON #{temp_import_table_name}.prefix = duplicates.prefix
          SET import_rule_duplicate_rate = #{rule_numeric_action}
          WHERE non_importable = 0
          ;
        ")
      }
    end

    # Min Times:
    #   If updating existing or creating new Rate, whose new Min Time value does not match any from set Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:min_times)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_min_times = #{rule_numeric_action}
          WHERE non_importable = 0
                AND min_time NOT IN (#{rule_value})
          ;
        ")
      }
    end

    # Increments:
    #   If updating existing or creating new Rate, whose new Increment value does not match any from set Rule
    rule_numeric_action, rule_value = tariff_import_rule.tariff_rate_import_rule.numeric_action_with_value(:increments)

    if rule_numeric_action > 0
      retry_lock_error(5) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{temp_import_table_name}
          SET import_rule_increments = #{rule_numeric_action}
          WHERE non_importable = 0
                AND increment NOT IN (#{rule_value})
          ;
        ")
      }
    end

    # TODO: Code Moved to New Zone:
    #   If updating existing Rate, whose Rate's Prefix's Destination Name is different
    # if ActiveRecord::Base.connection.column_exists?(temp_import_table_name, 'destination')
    #   rule_numeric_action = tariff_import_rule.tariff_rate_import_rule.numeric_action(:code_moved_to_new_zone)
    #
    #   if rule_numeric_action > 0
    #     ActiveRecord::Base.connection.execute("
    #       UPDATE #{temp_import_table_name}
    #       LEFT JOIN destinations ON #{temp_import_table_name}.current_rate_destination_id = destinations.id
    #       SET import_rule_code_moved_to_new_zone = #{rule_numeric_action}
    #       WHERE current_rate_id IS NOT NULL
    #             AND current_rate_destination_id IS NOT NULL
    #             AND destinations.id IS NOT NULL
    #             AND LOCATE(#{temp_import_table_name}.destination, destinations.name) = 0
    #       ;
    #     ")
    #   end
    # end

    accepted_rates = ActiveRecord::Base.connection.select_value("
      SELECT COUNT(id)
      FROM #{temp_import_table_name}
      WHERE non_importable = 0
            AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
      LIMIT 1
    ").to_i

    alerted_rates = ActiveRecord::Base.connection.select_value("
      SELECT COUNT(id)
      FROM #{temp_import_table_name}
      WHERE non_importable = 0
            AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} = 1" }.join(' OR ')})
      LIMIT 1
    ").to_i

    rejected_rates = ActiveRecord::Base.connection.select_value("
      SELECT COUNT(id)
      FROM #{temp_import_table_name}
      WHERE non_importable = 1
            OR (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} = 2" }.join(' OR ')})
      LIMIT 1
    ").to_i

    update_columns(status: :analyzed, rate_changes: accepted_rates, alerted: alerted_rates, rejected: rejected_rates, restarts: 0)
    update_columns(reviewed: 1) if tariff_import_rule.manual_review.to_i == 0

    if (tariff_import_rule.try(:reject_if_errors).to_i == 1) && (rejected_rates > 0)
      # Reviewed, because no more need for Confirmation
      update_columns(status: :rejected, status_reason: :rates_with_errors_present, reviewed: 1)
      EmailSender.send_tariff_import_notification(tariff_import_rule, 'rejected', notification_variables)
    end

    EmailSender.send_tariff_import_notification(tariff_import_rule, 'review', notification_variables) if tariff_import_rule.manual_review.to_i == 1 && reviewed == 0
    MorLog.my_debug("Tariff Job ID: #{id} - analyze_temp_imported - SUCCESSFUL METHOD END", true)
  end

  def import_analyzed
    return if TariffJob.where(id: id, status: :analyzed, reviewed: 1).where('schedule_import_at IS NULL OR schedule_import_at <= NOW()').first.blank?
    update_column(:status, :importing)

    MorLog.my_debug("Tariff Job ID: #{id} - import_analyzed - BEGIN", true)

    alter_tmp_table_for_new_columns

    importing_status = {failed: false, reason: ''}

    create_unknown_destinations = "
      INSERT IGNORE INTO destinations (prefix, direction_code, name)
        SELECT #{temp_import_table_name}.prefix,
               #{temp_import_table_name}.new_destination_direction_code,
               #{temp_import_table_name}.new_destination_name
        FROM #{temp_import_table_name}
        WHERE non_importable = 0
              AND new_destination_direction_code IS NOT NULL
              AND new_destination_name IS NOT NULL
    "
    unless importing_status[:failed]
      query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(create_unknown_destinations) }
      importing_status.merge!({failed: true, reason: 'failed with sql create unknown destinations'}) unless query_result.nil?
    end

    # Remove all non-assigned RateDetails, because they are illegal
    #   and sometimes are able to assign themselves to Rates they don't belong
    delete_nonassigned_ratedetails = '
      DELETE ratedetails
      FROM ratedetails
      LEFT JOIN rates ON rates.id = ratedetails.rate_id
      WHERE rates.id IS NULL
    '
    unless importing_status[:failed]
      query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(delete_nonassigned_ratedetails) }
      importing_status.merge!({failed: true, reason: 'failed with sql delete nonassigned ratedetails'}) unless query_result.nil?
    end

    unless importing_status[:failed]
      query_result = create_temporary_tariff_copy_with_device_assignation
      importing_status.merge!({failed: true, reason: 'failed with method create temporary tariff copy'}) unless query_result
    end

    unless importing_status[:failed]
      case tariff_import_rule.import_type.to_s
        when 'add_update'

          if tariff_import_rule.delete_rates_which_are_not_present_in_file.to_i == 1
            # Delete Rates for Prefixes which are not present in imported file
            delete_rates_not_present_in_import = "
              DELETE ratedetails, rates
              FROM ratedetails, rates
              LEFT JOIN #{temp_import_table_name} ON (rates.prefix = #{temp_import_table_name}.current_rate_prefix)
              WHERE rates.tariff_id = '#{tariff_import_rule.tariff_id}'
                    AND #{temp_import_table_name}.id IS NULL
                    AND ratedetails.rate_id = rates.id
            "
            unless importing_status[:failed]
              query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(delete_rates_not_present_in_import) }
              importing_status.merge!({failed: true, reason: 'failed with sql delete rates not present in import'}) unless query_result.nil?
            end
          end

          # Analysis skipped Rates which were currently_effective = 0
          #   this results in Rates being unmapped, because they only exist in future
          # To prevent this issue firstly we find Rates by precise effective_from,
          #   then it is enough to select any other rate which has currently_effective = 0
          assign_left_out_future_only_rates_precise_effective_from = "
            UPDATE #{temp_import_table_name}
            LEFT JOIN rates ON #{temp_import_table_name}.prefix = rates.prefix AND rates.effective_from = #{temp_import_table_name}.effective_from AND rates.tariff_id = #{tariff_import_rule.tariff_id}
            SET current_rate_id = rates.id,
                current_rate_prefix = rates.prefix,
                current_rate_destination_id = rates.destination_id,
                current_rate_destinationgroup_id = rates.destinationgroup_id,
                current_rate_ghost_min_perc = rates.ghost_min_perc,
                current_rate_effective_from = rates.effective_from
            WHERE non_importable = 0 AND rates.id IS NOT NULL AND #{temp_import_table_name}.current_rate_id IS NULL;
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(assign_left_out_future_only_rates_precise_effective_from) }
            importing_status.merge!({failed: true, reason: 'failed with sql assign left out future only rates precise effective from'}) unless query_result.nil?
          end

          assign_left_out_future_only_rates = "
            UPDATE #{temp_import_table_name}
            LEFT JOIN rates ON #{temp_import_table_name}.prefix = rates.prefix AND rates.currently_effective = 0 AND rates.tariff_id = #{tariff_import_rule.tariff_id}
            SET current_rate_id = rates.id,
                current_rate_prefix = rates.prefix,
                current_rate_destination_id = rates.destination_id,
                current_rate_destinationgroup_id = rates.destinationgroup_id,
                current_rate_ghost_min_perc = rates.ghost_min_perc,
                current_rate_effective_from = rates.effective_from
            WHERE non_importable = 0 AND rates.id IS NOT NULL AND #{temp_import_table_name}.current_rate_id IS NULL;
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(assign_left_out_future_only_rates) }
            importing_status.merge!({failed: true, reason: 'failed with sql assign left out future only rates'}) unless query_result.nil?
          end

          assign_left_out_future_only_ratedetails = "
            UPDATE #{temp_import_table_name}
            LEFT JOIN ratedetails ON #{temp_import_table_name}.current_rate_id = ratedetails.rate_id
            SET current_ratedetails_start_time = ratedetails.start_time,
                current_ratedetails_end_time = ratedetails.end_time,
                current_ratedetails_rate = ratedetails.rate,
                current_ratedetails_connection_fee = ratedetails.connection_fee,
                current_ratedetails_increment_s = ratedetails.increment_s,
                current_ratedetails_min_time = ratedetails.min_time,
                current_ratedetails_daytype = ratedetails.daytype,
                current_ratedetails_blocked = ratedetails.blocked
            WHERE #{temp_import_table_name}.current_rate_id IS NOT NULL;
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(assign_left_out_future_only_ratedetails) }
            importing_status.merge!({failed: true, reason: 'failed with sql assign left out future only ratedetails'}) unless query_result.nil?
          end

          # Add (Create) new Rates (with Ratedetails)
          create_new_rates = "
            INSERT INTO rates (tariff_id, prefix, destination_id, effective_from)
              SELECT #{tariff_import_rule.tariff_id},
                     #{temp_import_table_name}.prefix,
                     destinations.id,
                     #{temp_import_table_name}.effective_from
              FROM #{temp_import_table_name}
              JOIN destinations ON destinations.prefix = #{temp_import_table_name}.prefix
              WHERE non_importable = 0
                    AND #{temp_import_table_name}.current_rate_id IS NULL
                    AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(create_new_rates) }
            importing_status.merge!({failed: true, reason: 'failed with sql create new rates'}) unless query_result.nil?
          end

          create_new_ratedetails = "
            INSERT INTO ratedetails (rate_id, rate, connection_fee, increment_s, min_time, blocked)
              SELECT rates.id,
                     #{temp_import_table_name}.rate,
                     #{temp_import_table_name}.connection_fee,
                     #{temp_import_table_name}.increment,
                     #{temp_import_table_name}.min_time,
                     #{temp_import_table_name}.blocked
              FROM #{temp_import_table_name}
              JOIN rates ON rates.tariff_id = #{tariff_import_rule.tariff_id}
                            AND #{temp_import_table_name}.prefix = rates.prefix
              WHERE non_importable = 0
                    AND #{temp_import_table_name}.current_rate_id IS NULL
                    AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(create_new_ratedetails) }
            importing_status.merge!({failed: true, reason: 'failed with sql create new ratedetails'}) unless query_result.nil?
          end

          # Add (Create) existent Rates (with Ratedetails) for different Effective From
          # + Update existent Rate (with Ratedetails) for identical Effective From (by pre-Deleting)
          delete_rates_for_updating = "
            DELETE ratedetails, rates
            FROM ratedetails, rates
            JOIN #{temp_import_table_name} ON (rates.prefix = #{temp_import_table_name}.prefix AND rates.effective_from = #{temp_import_table_name}.effective_from)
            WHERE rates.tariff_id = '#{tariff_import_rule.tariff_id}'
                  AND #{temp_import_table_name}.current_rate_id IS NOT NULL
                  AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
                  AND ratedetails.rate_id = rates.id
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(delete_rates_for_updating) }
            importing_status.merge!({failed: true, reason: 'failed with sql delete rates for updating'}) unless query_result.nil?
          end

          update_rates = "
            INSERT INTO rates (tariff_id, prefix, destination_id, destinationgroup_id, ghost_min_perc, effective_from)
              SELECT #{tariff_import_rule.tariff_id},
                     #{temp_import_table_name}.prefix,
                     #{temp_import_table_name}.current_rate_destination_id,
                     #{temp_import_table_name}.current_rate_destinationgroup_id,
                     #{temp_import_table_name}.current_rate_ghost_min_perc,
                     #{temp_import_table_name}.effective_from
              FROM #{temp_import_table_name}
              WHERE non_importable = 0
                    AND #{temp_import_table_name}.current_rate_id IS NOT NULL
                    AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(update_rates) }
            importing_status.merge!({failed: true, reason: 'failed with sql update rates'}) unless query_result.nil?
          end

          update_ratedetails = "
            INSERT INTO ratedetails (rate_id, rate, connection_fee, increment_s, min_time, blocked)
              SELECT rates.id,
                     #{temp_import_table_name}.rate,
                     #{temp_import_table_name}.connection_fee,
                     #{temp_import_table_name}.increment,
                     #{temp_import_table_name}.min_time,
                     #{temp_import_table_name}.blocked
              FROM #{temp_import_table_name}
              JOIN rates ON rates.tariff_id = #{tariff_import_rule.tariff_id}
                            AND #{temp_import_table_name}.prefix = rates.prefix
                            AND #{temp_import_table_name}.effective_from = rates.effective_from
              WHERE non_importable = 0
                    AND #{temp_import_table_name}.current_rate_id IS NOT NULL
                    AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(update_ratedetails) }
            importing_status.merge!({failed: true, reason: 'failed with sql update ratedetails'}) unless query_result.nil?
          end
        when 'replace'
          tariff_import_rule.tariff.delete_all_rates

          create_rates = "
            INSERT INTO rates (tariff_id, prefix, destination_id, effective_from)
              SELECT #{tariff_import_rule.tariff_id},
                     #{temp_import_table_name}.prefix,
                     destinations.id,
                     #{temp_import_table_name}.effective_from
              FROM #{temp_import_table_name}
              JOIN destinations ON destinations.prefix = #{temp_import_table_name}.prefix
              WHERE non_importable = 0
                    AND (#{rate_import_rule_analysis_column_names.map { |header| "import_rule_#{header} < 2" }.join(' AND ')})
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(create_rates) }
            importing_status.merge!({failed: true, reason: 'failed with sql create rates'}) unless query_result.nil?
          end

          create_ratedetails = "
            INSERT INTO ratedetails (rate_id, rate, connection_fee, increment_s, min_time, blocked)
              SELECT rates.id,
                     #{temp_import_table_name}.rate,
                     #{temp_import_table_name}.connection_fee,
                     #{temp_import_table_name}.increment,
                     #{temp_import_table_name}.min_time,
                     #{temp_import_table_name}.blocked
              FROM #{temp_import_table_name}
              JOIN rates ON rates.tariff_id = #{tariff_import_rule.tariff_id} AND #{temp_import_table_name}.prefix = rates.prefix
          "
          unless importing_status[:failed]
            query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(create_ratedetails) }
            importing_status.merge!({failed: true, reason: 'failed with sql create ratedetails'}) unless query_result.nil?
          end
      end

      # Delete Rates which are marked as 'deleted'
      delete_rates_marked_as_deleted = "
            DELETE ratedetails, rates
            FROM ratedetails, rates
            LEFT JOIN #{temp_import_table_name} ON (rates.prefix = #{temp_import_table_name}.prefix)
            WHERE rates.tariff_id = '#{tariff_import_rule.tariff_id}'
                  AND ratedetails.rate_id = rates.id
                  AND #{temp_import_table_name}.deleted = 1
          "
      unless importing_status[:failed]
        query_result = retry_lock_error(5) { ActiveRecord::Base.connection.execute(delete_rates_marked_as_deleted) }
        importing_status.merge!({failed: true, reason: 'failed with sql delete rates marked as deleted'}) unless query_result.nil?
      end
    end

    unless importing_status[:failed]
      rate_with_multiple_ratedetails_found = ActiveRecord::Base.connection.select_value("
                                               SELECT rates.id, COUNT(ratedetails.id) AS ratedetails_count
                                               FROM rates
                                               LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
                                               WHERE tariff_id = #{tariff_import_rule.tariff_id}
                                               GROUP BY rates.id
                                               HAVING ratedetails_count > 1
                                             ").present?
      if rate_with_multiple_ratedetails_found
        MorLog.my_debug("Tariff Job ID: #{id} - import_analyzed\n  Failed to Import\n  Rate with multiple Ratedetails found after Importing", true)

        importing_status.merge!({failed: true, reason: 'rate with multiple ratedetails found after importing'})
      end
    end

    if importing_status[:failed]
      MorLog.my_debug("Tariff Job ID: #{id} - import_analyzed\n  Failed to Import\n  #{importing_status[:reason]}", true)

      restore_temporary_tariff_copy_with_device_assignation

      update_columns(status: :failed_import, status_reason: importing_status[:reason].parameterize('_').to_sym)
    else
      remove_temporary_tariff_copy_with_device_assignation

      tariff_import_rule.tariff.changes_present_set_1

      update_columns(status: :imported, restarts: 0)
      Tariff.tariff_rates_effective_from_cache("-t #{tariff_import_rule.tariff_id}")

      EmailSender.send_tariff_import_notification(tariff_import_rule, (import_alerts? ? 'alerts' : 'imported'), notification_variables)
      EmailSender.send_tariff_import_notification(tariff_import_rule, (import_rejects? ? 'rejects' : 'imported'), notification_variables)
    end

    MorLog.my_debug("Tariff Job ID: #{id} - import_analyzed - SUCCESSFUL METHOD END", true)
  end

  def self.check_for_hanging_jobs
    hanging_jobs = where(status: %w[converting temp_importing analyzing importing]).
        where("updated_at < (NOW() - INTERVAL #{TariffJob.max_processing_minutes_allowed} MINUTE)").
        order(:id).all

    return if hanging_jobs.blank?

    hanging_jobs.each { |assigned_job| assigned_job.process_hanged_job }
  end

  def process_hanged_job
    return if TariffJob.where(id: id, status: %w[converting temp_importing analyzing importing]).first.blank?

    MorLog.my_debug("Tariff Job ID: #{id} - process_hanged_job - BEGIN", true)
    fail_status_reason = "Status '#{status.to_s.titleize}' hanged for more than #{TariffJob.max_processing_minutes_allowed} minutes and attempted restarts (#{restarts.to_i}/#{TariffJob.max_restarts_allowed})"

    if restarts.to_i < TariffJob.max_restarts_allowed
      case status
        when 'converting'
          update_columns(
              status: :assigned,
              file_received_at: nil
          )
        when 'temp_importing'
          update_columns(status: :converted)
        when 'analyzing'
          update_columns(
              status: :temp_imported,
              rate_changes: nil,
              rejected: nil,
              reviewed: nil,
              alerted: nil
          )
        when 'importing'
          restore_temporary_tariff_copy_with_device_assignation
          update_columns(status: :analyzed)
      end

      update_columns(restarts: (restarts.to_i + 1))
    else
      case status
        when 'converting'
          update_columns(status: :failed_conversion, status_reason: fail_status_reason)
        when 'temp_importing'
          update_columns(status: :failed_temp_import, status_reason: fail_status_reason)
        when 'analyzing'
          update_columns(status: :failed_analysis, status_reason: fail_status_reason)
        when 'importing'
          update_columns(status: :failed_import, status_reason: fail_status_reason)
          restore_temporary_tariff_copy_with_device_assignation
      end
    end

    MorLog.my_debug("Tariff Job ID: #{id} - process_hanged_job\n  Info: #{fail_status_reason}\n", true)
    MorLog.my_debug("Tariff Job ID: #{id} - process_hanged_job - SUCCESSFUL METHOD END", true)
  end

  def tariff_job_analysis_results(params)
    search_params = tariff_job_analysis_search_params(params)
    results = "
      SELECT id, prefix, destination, connection_fee,
             rate, increment, min_time, effective_from, blocked, deleted,
             import_rule_rate_increase,
             import_rule_rate_decrease,
             import_rule_new_rate,
             import_rule_oldest_effective_date,
             import_rule_maximum_effective_date,
             import_rule_max_increase,
             import_rule_max_decrease,
             import_rule_max_rate,
             import_rule_zero_rate,
             import_rule_duplicate_rate,
             import_rule_min_times,
             import_rule_increments,
             non_importable,
             non_importable_reasons,
             new_destination_direction_code,
             new_destination_name
      FROM #{temp_import_table_name}
      #{"WHERE #{search_params}" if search_params.present?}
      ORDER BY #{params[:order_by].present? ? ActiveRecord::Base::sanitize(params[:order_by].to_s)[1..-2] : 'prefix' } #{ 'DESC' if params[:order_desc].try(:to_i) == 1}
    "
    ActiveRecord::Base.connection.exec_query(results)
  end

  def confirm(scheduled_import_at = nil)
    update_columns(schedule_import_at: scheduled_import_at) if scheduled_import_at.present?
    update_columns(reviewed: 1)
  end

  def cancel
    update_columns(status: :cancelled, reviewed: 1)
  end

  def show_schedule_form?
    tariff_import_rule.manual_review == 1 && !(status == 'importing' || TariffJob.completed_statuses.include?(status))
  end

  def notification_variables
    {
        tariff_job_id: id.to_s,
        tariff_job_analysis_url: "#{Web_URL}#{Web_Dir}/tariff_job_analysis/list/#{id}",
        tariff_job_tariff_id: tariff_import_rule.try(:tariff).try(:id).to_s,
        tariff_job_tariff_name: tariff_import_rule.try(:tariff).try(:name).to_s
    }
  end

  def self.delete_all_imported
    imported_jobs = self.where(status: :imported).all
    imported_jobs.each { |job| job.destroy }
    imported_jobs.size
  end

  def self.process_email_body(email_body)
    email_body.gsub("\r\n", ' ').gsub("\n", ' ').gsub("\r", ' ')
  end

  def self.remove_formatting(date_string)
    date_string.to_s.gsub('*', '').strip
  end

  def self.tariff_job_analysis_result_reason(result, hide_passed = false)
    non_importable_reasons = if result['non_importable_reasons'].present?
                               result['non_importable_reasons'].split(';').map { |reason| reason.titleize }.join(', ')
                             else
                               '-'
                             end
    rules_and_actions =
        {
            import_rule_rate_increase: [_('Rate_Increase'), TariffJob.import_rule_value(result['import_rule_rate_increase'])],
            import_rule_rate_decrease: [_('Rate_Decrease'), TariffJob.import_rule_value(result['import_rule_rate_decrease'])],
            import_rule_new_rate: [_('New_Rate'), TariffJob.import_rule_value(result['import_rule_new_rate'])],
            import_rule_oldest_effective_date: [_('Oldest_Effective_Date'), TariffJob.import_rule_value(result['import_rule_oldest_effective_date'])],
            import_rule_maximum_effective_date: [_('Maximum_Effective_Date'), TariffJob.import_rule_value(result['import_rule_maximum_effective_date'])],
            import_rule_max_increase: [_('Max_Increase'), TariffJob.import_rule_value(result['import_rule_max_increase'])],
            import_rule_max_decrease: [_('Max_Decrease'), TariffJob.import_rule_value(result['import_rule_max_decrease'])],
            import_rule_max_rate: [_('Max_Rate'), TariffJob.import_rule_value(result['import_rule_max_rate'])],
            import_rule_zero_rate: [_('Zero_Rate'), TariffJob.import_rule_value(result['import_rule_zero_rate'])],
            import_rule_duplicate_rate: [_('Duplicate_Rate'), TariffJob.import_rule_value(result['import_rule_duplicate_rate'])],
            import_rule_min_times: [_('Min_Times'), TariffJob.import_rule_value(result['import_rule_min_times'])],
            import_rule_increments: [_('Increments'), TariffJob.import_rule_value(result['import_rule_increments'])],
            non_importable_reasons: [_('Non_Importable_Reasons'), non_importable_reasons]
        }

    if hide_passed
      rules_and_actions.reject! { |key, value| value[1] == '-' }
    end

    rules_and_actions
  end

  def self.import_rule_value(import_rule)
    case import_rule
      when 1
        _('Alert')
      when 2
        _('Rejected')
      else
        '-'
    end
  end

  def alter_tmp_table_for_new_columns
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("ALTER TABLE #{temp_import_table_name} ADD COLUMN `blocked` TINYINT(4) DEFAULT 0") rescue nil
    }
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("ALTER TABLE #{temp_import_table_name} ADD COLUMN `deleted` TINYINT(4) DEFAULT 0") rescue nil
    }

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("ALTER TABLE #{temp_import_table_name} ADD COLUMN `file_import_blocked` VARCHAR(255) DEFAULT '0'") rescue nil
    }
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("ALTER TABLE #{temp_import_table_name} ADD COLUMN `file_import_deleted` VARCHAR(255) DEFAULT '0'") rescue nil
    }
  end

  def temp_import_table_name
    "tariff_job_rates_temporary_#{id}"
  end

  private

  def encoded_file_for_conversion
    full_path = "/tmp/m2/tariff_jobs/assigned_for_conversion_#{id}/"
    full_path_attachment_rar = "#{full_path}#{tariff_attachment.file_name.to_s}.rar"
    full_path_attachment = "#{full_path}#{tariff_attachment.file_full_name.to_s}"
    full_path_template = "#{full_path}template.txt"

    `mkdir -p #{full_path}`

    File.open(full_path_attachment_rar, 'wb') do |file|
      file.write(tariff_attachment.data.to_s)
    end

    `cd #{full_path} && /usr/local/bin/unrar e -y '#{full_path_attachment_rar}'`
    `rm -rf '#{full_path_attachment_rar}'`
    `cd #{full_path} && zip -j -r rates.zip '#{full_path_attachment}'`
    `rm -rf '#{full_path_attachment}'`

    tariff_import_rule.tariff_template.generate_template
    File.open(full_path_template, 'wb') do |file|
      file.puts(tariff_import_rule.tariff_template.generated_template.to_s.split('\n'))
    end

    `cd #{full_path} && zip -j -r tariff_job_assigned_for_conversion.zip *`

    base64encoded = Base64.encode64(File.open("#{full_path}tariff_job_assigned_for_conversion.zip", 'rb').read)

    `rm -rf #{full_path}`

    base64encoded
  end

  def tariff_job_analysis_search_params(params)
    search_params = []
    search = params[:search]


    if search[:show_only].present? && search[:show_only].length < 3
      show_only = (search[:show_only].key?(:good) && search[:show_only].length == 2) ? 10 : 0
      %i[good alerted rejected].each { |key| show_only += search[:show_only][key].try(:to_i) if search[:show_only].key?(key) }

      case show_only
        when 0
          search_params << "(#{import_rule_columns.join(' + ')} + non_importable) = 0"
        when 1
          search_params << "#{import_rule_columns.join(' < 2 AND ')} < 2"
          search_params << "(#{import_rule_columns.join(' + ')}) > 0 AND non_importable = 0"
        when 2
          search_params << "(#{import_rule_columns.join(' = 2 OR ')} = 2 OR non_importable = 1)"
        when 3
          search_params << "(#{import_rule_columns.join(' > 0 OR ')} = 2)"
        when 11
          search_params << "#{import_rule_columns.join(' < 2 AND ')} < 2 AND non_importable = 0"
        when 12
          search_params << "((#{import_rule_columns.join(' + ')} + non_importable) = 0 OR (#{import_rule_columns.join(' = 2 OR ')} = 2 OR non_importable = 1))"
      end
    end

    if search.present?
      import_rule_params = search.reject {|column| column[/^(?!import_rule_).+/]}
      import_rule_params.each { |key, value| search_params << "#{key} = #{ActiveRecord::Base::sanitize(value.to_s)[1..-2]}" if value.try(:to_i) > -1 }

      non_importable_reasons = search[:non_importable_reasons].to_s
      if non_importable_reasons.present? && non_importable_reasons != '-1'
        search_params << 'non_importable = 0' if non_importable_reasons == 'none'
        search_params << 'non_importable > 0' if non_importable_reasons == 'any'
        unless %[none any].include?(search[:non_importable_reasons])
          search_params << "non_importable_reasons = #{ActiveRecord::Base::sanitize(search[:non_importable_reasons].to_s)}"
        end
      end
    end
    search_params.join(' AND ')
  end

  def import_alerts?
    erorrs_query = "
      SELECT id
      FROM #{temp_import_table_name}
      WHERE import_rule_rate_increase = 1 OR import_rule_rate_decrease = 1 OR
            import_rule_new_rate = 1 OR import_rule_oldest_effective_date = 1 OR
            import_rule_maximum_effective_date = 1 OR import_rule_max_increase = 1 OR
            import_rule_max_decrease = 1 OR import_rule_max_rate = 1 OR
            import_rule_zero_rate = 1 OR import_rule_zero_rate = 1 OR
            import_rule_duplicate_rate = 1 OR import_rule_min_times = 1 OR
            import_rule_increments = 1
      LIMIT 1
    "
    errors = ActiveRecord::Base.connection.exec_query(erorrs_query).first['id']
    return errors.present?
  end

  def import_rejects?
    erorrs_query = "
      SELECT id
      FROM #{temp_import_table_name}
      WHERE import_rule_rate_increase = 2 OR import_rule_rate_decrease = 2 OR
            import_rule_new_rate = 2 OR import_rule_oldest_effective_date = 2 OR
            import_rule_maximum_effective_date = 2 OR import_rule_max_increase = 2 OR
            import_rule_max_decrease = 2 OR import_rule_max_rate = 2 OR
            import_rule_zero_rate = 2 OR import_rule_zero_rate = 2 OR
            import_rule_duplicate_rate = 2 OR import_rule_min_times = 2 OR
            import_rule_increments = 2 OR non_importable = 1
      LIMIT 1
    "
    errors = ActiveRecord::Base.connection.exec_query(erorrs_query).first['id']
    return errors.present?
  end

  def import_rule_columns
    %w[import_rule_rate_increase import_rule_rate_decrease
       import_rule_new_rate import_rule_oldest_effective_date
       import_rule_maximum_effective_date import_rule_max_increase
       import_rule_max_decrease import_rule_max_rate
       import_rule_zero_rate import_rule_duplicate_rate
       import_rule_min_times import_rule_increments
      ]
  end

  def create_temporary_tariff_copy_with_device_assignation
    current_tariff_id = tariff_import_rule.tariff.id
    temp_tariff_id = tariff_import_rule.tariff.create_copy

    temp_tariff = Tariff.where(id: temp_tariff_id).first
    return false if temp_tariff.blank?

    update_column(:temporary_tariff_id, temp_tariff_id)

    ActiveRecord::Base.connection.execute("UPDATE devices SET tp_tariff_id = #{temp_tariff_id} WHERE tp_tariff_id = #{current_tariff_id}")
    true
  end

  def remove_temporary_tariff_copy_with_device_assignation
    current_tariff_id = tariff_import_rule.tariff.id
    temp_tariff = Tariff.where(id: temporary_tariff_id).first
    return false if temp_tariff.blank?

    ActiveRecord::Base.connection.execute("UPDATE devices SET tp_tariff_id = #{current_tariff_id} WHERE tp_tariff_id = #{temp_tariff.id}")

    temp_tariff.delete_all_rates
    temp_tariff.destroy
  end

  def restore_temporary_tariff_copy_with_device_assignation
    current_tariff = tariff_import_rule.tariff
    current_tariff_id = current_tariff.id
    current_tariff_name = current_tariff.name.to_s

    temp_tariff = Tariff.where(id: temporary_tariff_id).first
    return false if temp_tariff.blank?

    restoring_tariff_id = temp_tariff.create_copy
    restoring_tariff = Tariff.where(id: restoring_tariff_id).first
    return false if restoring_tariff.blank?

    current_tariff.delete_all_rates
    current_tariff.delete

    ActiveRecord::Base.connection.execute("
      UPDATE tariffs
      SET id = #{current_tariff_id},
          name = #{ActiveRecord::Base::sanitize(current_tariff_name)}
      WHERE id = #{restoring_tariff_id}
    ")
    ActiveRecord::Base.connection.execute("
      UPDATE rates
      SET tariff_id = #{current_tariff_id}
      WHERE tariff_id = #{restoring_tariff_id}
    ")

    ActiveRecord::Base.connection.execute("UPDATE devices SET tp_tariff_id = #{current_tariff_id} WHERE tp_tariff_id = #{temp_tariff.id}")

    temp_tariff.delete_all_rates
    temp_tariff.destroy
  end
end
