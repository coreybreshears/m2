class AggregateExportJob < JobInterface
  include UniversalHelpers
  ATTRIBUTES = %i[template options errors agg_export owner from till data filename period_options from_email till_email real_owner]
  attr_accessor *ATTRIBUTES

  def initialize(options = {})
    @errors = []
    @agg_export = options[:agg_export]
    @owner = User.find(0)
    set_real_owner
    set_correct_period
    set_template
  end

  def do_job
    return unless no_errors?
    @options = @template.to_hash
    get_data_from_elastic
    prepare_table
    log_to_action if send_email
    set_last_run_at
  end

  def next_run_at
    AggregateExportRuns.new(agg_export).set_run_at
  end

  private

  def get_data_from_elastic
    @es_options = EsAggregates.format_options(ActionController::Parameters.new(@template.to_hash).merge!(period_options), from.strftime('%Y-%m-%dT%H:%M:%S'), till.strftime('%Y-%m-%dT%H:%M:%S'), @real_owner)

    @data = EsAggregates.get_data(@es_options.merge(currency: owner.currency.name))
  end

  def set_last_run_at
    agg_export.last_run_at = agg_export.next_run_at
  end

  def log_to_action
    Action.add_action_hash(0, action: 'Auto_Aggregate_Job_run_successful', data: '', target_id: owner.id, target_type: 'User')
  end

  def log_to_action_error
    Action.add_action_hash(0, action: 'error', data: 'Auto_Aggregate_Job dont run', data4: errors[errors.count - 1], target_id: owner.id, target_type: 'User')
  end

  def set_template
    template = AggregateTemplate.where(id: agg_export.template_id).first
    errors << _('Template_is_empty') if template.blank?
    @template = template
  end

  def set_real_owner
    @real_owner = User.where(id: agg_export.owner_id).first || @owner
  end

  def send_email
    smtp_options = Email.smtp_options
    email_variables = Email.email_variables(owner, nil,
      auto_aggregate_export_from: nice_date_time_user(from_email, nil),
      auto_aggregate_export_till: nice_date_time_user(till_email, nil),
      auto_aggregate_export_template: @template.name
      )
    email_template = Email.where(name: 'auto_aggregate_report', owner_id: 0).first
    email_body = EmailsController.nice_email_sent(email_template, email_variables)
    email_subject = EmailsController.nice_email_sent(email_template, email_variables, 'subject')

    system_call_response = system(
        ApplicationController.send_email_dry(
            smtp_options[:from], email_addresses, email_body,
            email_subject,
            "-a '/tmp/m2/#{filename}.csv'",
            smtp_options[:connection], email_template[:format]
        )
    )
    tmp_file = "/tmp/m2/#{filename}.csv"
    #File.delete(tmp_file)
    return true
  rescue => err
    Action.add_action_hash(0, action: 'error', data: 'Auto_Aggregate_Job dont run', data4: err.message.to_s + ' ' + err.class.to_s, target_id: owner.id, target_type: 'User')
    return false
  end

  def email_addresses
    emails = agg_export.try(:email).to_s.gsub(',', ';')
    if agg_export.user_id > 0
      user = User.find(agg_export.user_id)
      emails += ';' + user.email.to_s
    end
    emails
  end

  def prepare_table
    require 'csv'

    @filename = ('aggregate_export_' + Time.now.to_s(:db)).gsub(' ', '_')
    sep, dec = owner.csv_params

    CSV.open('/tmp/m2/' + filename + '.csv', 'w', {col_sep: sep, quote_char: "\""}) do |csv|
      originator_str = _('Originator')
      terminator_str = _('Terminator')
      headers = prepare_table_headers
      csv << headers
      time_format = Confline.get_value('time_format', owner.owner.id)
      data[:table_rows].each_with_index do |line|
        csv << prepare_table_row(line, headers, time_format, dec)
      end
    end
  end

  def prepare_table_headers
    headers = []
    originator_str = _('Originator')
    terminator_str = _('Terminator')

    headers << _('Destination_Group') if %i[dst dst_group].any? { |group| @data[:options][:group_by].include? group }
    headers << _('Prefix') if @data[:options][:group_by].include?(:dst)
    if %i[originator op].any? { |group| @data[:options][:group_by].include? group }
      headers << (@data[:options][:group_by].include?(:originator) ? "#{_('Customer')} #{originator_str}" : _('Origination_point'))
    end

    if %i(terminator tp).any? { |group| @data[:options][:group_by].include? group }
      headers << (@data[:options][:group_by].include?(:terminator) ? "#{_('Customer')} #{terminator_str}" : _('Termination_point'))
    end
    headers << _('Manager') if %i[manager].any? { |group| @data[:options][:group_by].include? group }

    headers << "#{_('Billed')} #{originator_str}" if @options[:price_orig_show].to_i == 1
    headers << "#{_('Billed')} #{originator_str} #{_('with_TAX')}" if @options[:price_orig_show].to_i == 1 && @data[:options][:group_by].include?(:originator)
    headers << "#{_('Billed')} #{terminator_str}" if @options[:price_term_show].to_i == 1
    headers << _('Profit') if @options[:profit_show].to_i == 1
    headers << "#{_('Profit')} %" if @options[:profit_percent_show].to_i == 1
    headers << "#{_('Billed_Duration')} #{originator_str}" if @options[:billed_time_orig_show].to_i == 1
    headers << "#{_('Billed_Duration')} #{terminator_str}" if @options[:billed_time_term_show].to_i == 1
    headers << _('Duration') if @options[:duration_show].to_i == 1
    headers << _('Answered') if @options[:calls_answered_show].to_i == 1
    headers << _('Total') if @options[:calls_total_show].to_i == 1
    headers << "#{_('ASR')} %" if @options[:asr_show].to_i == 1
    headers << _('ACD') if @options[:acd_show].to_i == 1
    headers << _('PDD') if @options[:pdd_show].to_i == 1
    headers
  end

  def prepare_table_row(line, headers, time_format, dec)
    originator_str = _('Originator')
    terminator_str = _('Terminator')
    data_line = []
    data_line << line[:dst_group] if headers.include?(_('Destination_Group'))
    data_line << line[:dst] if headers.include?(_('Prefix'))
    data_line << line[:originator] if headers.include?("#{_('Customer')} #{originator_str}")
    data_line << line[:op] if headers.include?(_('Origination_point'))
    data_line << line[:terminator] if headers.include?("#{_('Customer')} #{terminator_str}")
    data_line << line[:tp] if headers.include?(_('Termination_point'))
    data_line << line[:manager] if headers.include?(_('Manager'))

    data_line << line[:billed_originator].to_s.gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if headers.include?("#{_('Billed')} #{originator_str}")
    data_line << line[:billed_originator_with_tax].to_s.gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if headers.include?("#{_('Billed')} #{originator_str} #{_('with_TAX')}")
    data_line << line[:billed_terminator].to_s.gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if headers.include?("#{_('Billed')} #{terminator_str}")
    data_line << line[:profit].to_f.to_s.gsub('.', dec) if headers.include?(_('Profit'))
    data_line << line[:profit_percent].to_f.to_s.gsub('.', dec) if headers.include?((_('Profit') + ' %'))

    data_line << nice_time(line[:billed_duration_originator], time_format: time_format) if headers.include?("#{_('Billed_Duration')} #{originator_str}")
    data_line << nice_time(line[:billed_duration_terminator], time_format: time_format) if headers.include?("#{_('Billed_Duration')} #{terminator_str}")
    data_line << nice_time(line[:duration], time_format: time_format) if headers.include?(_('Duration'))

    data_line << line[:answered_calls].to_i if headers.include?(_('Answered'))
    data_line << line[:total_calls].to_i if headers.include?(_('Total'))

    data_line << nice_number_with_separator(line[:asr], 2).to_s.gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if headers.include?("#{_('ASR')} %")
    data_line << nice_time(line[:acd].to_i, time_format: time_format) if headers.include?(_('ACD'))
    data_line << line[:pdd].to_s.gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if headers.include?(_('PDD'))
    data_line
  end

  def set_correct_time
    @from = agg_export.last_run_at.to_time.change(hour: 0, min: 0, sec: 0) - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
    tmp_till = agg_export.next_run_at.to_time - 1.day
    @till = tmp_till.change(hour: 23, min: 59, sec: 59) - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
  end


  def set_correct_period
    @period_options = {}
    case agg_export.period_type.to_i
      when 1
        @from_email = agg_export.next_run_at.to_time - agg_export.period.hours
        @till_email = agg_export.next_run_at.to_time
        @from = agg_export.next_run_at.to_time - agg_export.period.hours - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
        @till = agg_export.next_run_at.to_time - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
      when 2
        @period_options = set_agg_time
        next_run = agg_export.next_run_at.to_time - 1.day
        @from_email = (next_run - agg_export.period.days + 1.day).change(hour: 0, min: 0, sec: 0)
        @till_email = next_run.change(hour: 23, min: 59, sec: 59)
        @from = (next_run - agg_export.period.days + 1.day).change(hour: 0, min: 0, sec: 0) - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
        @till = next_run.change(hour: 23, min: 59, sec: 59) - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
      when 3
        @period_options = set_agg_time
        next_run = agg_export.next_run_at.to_time - 1.day
        @from_email = (next_run - agg_export.period.months).change(hour: 0, min: 0, sec: 0)
        @till_email = next_run.change(hour: 23, min: 59, sec: 59)
        @from = (next_run - agg_export.period.months).change(hour: 0, min: 0, sec: 0) - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
        @till = next_run.change(hour: 23, min: 59, sec: 59) - Time.now.in_time_zone(owner.time_zone).utc_offset().second + Time.now.utc_offset().second
    end
  end

  def set_agg_time
    {
      set_time_of_day: 1,
      from_time_of_day: agg_export.from_time,
      till_time_of_day: agg_export.till_time
    }
  end

  def no_errors?
    count = errors.count
    if count > 0
      log_to_action_error
    end
    count == 0
  end
end