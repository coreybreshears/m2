# Aggregated Calls' statistics.
class AggregatesController < ApplicationController
  layout :determine_layout

  before_action :authorize
  before_action :check_localization
  before_action :check_post_method, only: [:aggregates_download_table_data]
  before_action :access_denied, if: -> { user? }
  before_action :calls_per_hour_access_denied, only: [:calls_per_hour],
                if: -> { current_user.blank? || user? || reseller? }
  before_action :reset_min_sec, only: [:list]
  before_action :load_ok?
  before_action :agg_page_setup, only: [:list]

  def list
    if @search_pressed
      @options.merge!(EsAggregates.format_options(params, es_session_from, es_session_till, current_user))
    end
    redirect_to(action: :list) && (return false) if @search_pressed && @errors.to_i > 0
    @data = EsAggregates.get_data(@options.merge(currency: session[:show_currency])) if @searching
    session[:aggregate_options] = @options
    # render xml: @data
  end

  def aggregates_download_table_data
    filename = aggregates_download_table_csv(params, current_user)
    filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)

    if params[:test].to_i == 1
      render text: File.open(filename).read, filename: filename.sub('/tmp/', '')
      return
    end

    cookies['fileDownload'] = 'true'
    send_data(File.open(filename).read, filename: filename.sub('/tmp/', ''))
  end

  def calls_per_hour
    @page_title = _('Calls_per_Hour')
    @page_icon = 'chart_bar.png'
    adjust_m2_date
    change_date
    calls_per_hour_search_options
    @options_from = "#{session[:year_from]}-#{good_date(session[:month_from].to_s)}-" \
        "#{good_date(session[:day_from].to_s)} " \
        "#{good_date(session[:hour_from].to_s)}:#{good_date(session[:minute_from].to_s)}:00"
    @options_till = "#{session[:year_till]}-#{good_date(session[:month_till].to_s)}-" \
        "#{good_date(session[:day_till].to_s)} " \
        '23:59:59'

    @es_calls_per_hour = EsCallsPerHour.get_data(
      calls_per_hour_data_search_variables.merge(current_user: current_user)
    )
  end

  def calls_per_hour_data_expand
    expand_options = {current_user: current_user}
    data = EsCallsPerHour.get_data(
      Aggregate.calls_per_hour_data_expand_params(params, session, expand_options).merge(current_user: current_user)
    )
    output = Aggregate.calls_per_hour_data_expand_rows(data, params)
    render(text: output)
  end

  def ajax_get_templates_list
    return dont_be_so_smart && redirect_to(:root) unless request.xhr?
    render layout: false
  end

  private

  def calls_per_hour_search_options
    @options = params
    if @options.try(:[], [:searching]) && Time.parse("#{session_from_date} 00:00:00") > Time.parse("#{session_till_date} 23:59:59")
      redirect_to(action: :calls_per_hour) && (return false)
    end
    change_date_to_present if params[:clear] == 'clear'
    @options = Aggregate.calls_per_hour_options(params, @options)
  end

  def calls_per_hour_data_search_variables
    {
      from: es_limit_search_by_days, till: es_session_till,
      prefix: @options[:prefix].to_s.strip,
      terminator: @options[:s_terminator].blank? ? 0 : @options[:s_terminator_id].to_i,
      destination_group: @options[:destination_group].to_i,
      user: @options[:s_user].blank? ? 0 : @options[:s_user_id].to_i
    }
  end

  def agg_page_setup
    @page_title = _('calls_aggregate')
    @show_currency_selector = 1
    @clean = params[:clean].to_i == 1
    @options = session[:aggregate_options] ||= {}
    @search_pressed = params[:search_pressed]
    @options[:search_on] = 1 if @search_pressed
    @searching = !@clean && (@options[:search_on] == 1 || params[:search_on].to_i == 1)
    agg_check_params
  end

  def agg_check_params
    @errors = 0
    agg_vlaidate_grouping
    change_date
    reset_min_sec
    agg_validate_time
    agg_clear_options
  end

  def agg_clear_options
    return unless @options.blank? || @search_pressed || @clean
    @default = !@searching
    agg_default_columns
    return if @search_pressed
    @options.merge!(
      originator: '', originator_id: '-1', terminator: '', terminator_id: '-1', dst: '',
      src: '', s_op_device: '', s_tp_device: '', op_devices: [], tp_devices: [], from_user_perspective: 0,
      answered_calls: 1, use_real_billsec: 0, dst_group: '',
      search_on: 0, s_duration: '', s_manager: ''
    )
    change_date_to_present
  end

  def agg_validate_time
    invalid_range = Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
    @errors += 1 if invalid_range
  end

  def agg_vlaidate_grouping
    group_params = %i[group_by_originator group_by_op
                      group_by_terminator group_by_tp group_by_dst_group group_by_dst group_by_manager
                     ]
    # Do not allow no grouping
    return unless @search_pressed && group_params.none? { |group| params[group].to_i == 1 }
    flash[:notice] = _('At_least_one_grouping_option_must_be_selected')
    @errors += 1
  end

  def agg_default_columns
    checkboxes = %i[price_orig_show price_term_show billed_time_orig_show billed_time_term_show
                    duration_show acd_show calls_answered_show asr_show calls_total_show group_by_originator
                    group_by_op group_by_terminator group_by_tp group_by_dst_group group_by_dst pdd_show profit_show
                    profit_percent_show group_by_manager
                   ]

    checkboxes.each do |check|
      @options[check] = if @default
                          %i[group_by_op group_by_tp group_by_dst profit_show profit_percent_show group_by_manager].member?(check) ? 0 : 1
                        else
                          @search_pressed ? params[check].to_i : @options[check]
                        end
    end
  end

  def aggregates_download_table_csv(params, user)
    require 'csv'

    filename = 'Aggregates'
    sep, dec = user.csv_params

    table_data = JSON.parse(params[:table_content])
    table_data_keys = table_data.present? ? table_data[0].keys : []

    CSV.open('/tmp/' + filename + '.csv', 'w', col_sep: sep, quote_char: '"') do |csv|
      headers = []
      originator_str = _('Originator')
      terminator_str = _('Terminator')
      table_data_keys.each do |header|
        headers << case header
                   when originator_str
                     "#{_('Customer')} #{originator_str}"
                   when terminator_str
                     "#{_('Customer')} #{terminator_str}"
                   when "#{originator_str} (#{session[:show_currency]})"
                     "#{_('Billed')} #{originator_str}"
                   when "#{originator_str} #{_('with_TAX')} (#{session[:show_currency]})"
                     "#{_('Billed')} #{originator_str} #{_('with_TAX')}"
                   when "#{terminator_str} (#{session[:show_currency]})"
                     "#{_('Billed')} #{terminator_str}"
                   when " #{originator_str} "
                     "#{_('Billed_Duration')} #{originator_str}"
                   when " #{terminator_str} "
                     "#{_('Billed_Duration')} #{terminator_str}"
                   else
                     header
                   end
      end

      csv << headers

      table_data.each do |line|
        data_line = Aggregate.data_line(line, table_data_keys, session, originator_str, terminator_str, dec)
        csv << data_line
      end
    end

    filename
  end

  def set_checkboxes
    checkboxes = %w[price_orig_show price_term_show billed_time_orig_show billed_time_term_show
                    duration_show acd_show calls_answered_show asr_show calls_total_show
                   ]

    checkboxes.each do |check|
      check = check.to_sym
      @options[check] = if @default
                          1
                        else
                          (params[:search_pressed].present? && params[:date_from].blank?) ? @options[check] : params[check].to_i
                        end
    end
  end

  def reset_min_sec
    session[:minute_from] = '00'
    session[:minute_till] = '59'
  end

  def calls_per_hour_access_denied
    dont_be_so_smart
    redirect_to(:root) && (return false)
  end
end
