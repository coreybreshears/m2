# Aggregate model
class Aggregate < ActiveRecord::Base
  attr_protected

  extend UniversalHelpers
  belongs_to :originator, class_name: 'User', foreign_key: 'op_user_id'
  belongs_to :terminator, class_name: 'User', foreign_key: 'tp_user_id'
  belongs_to :reseller, class_name: 'User', foreign_key: 'reseller_id'
  belongs_to :time_period
  has_one :destinationgroup

  scope :ungrouped, -> { unscope(:group) }
  scope :unpaged, -> { unscope(:limit, :offset, :order) }
  scope :unscoped_and_ungrouped, -> { ungrouped.unpaged }

  def self.calls_per_hour_data_expand_params(params, session, options = {})
    current_user = options[:current_user]
    query_date = DateTime.strptime(params[:day], session[:date_format].to_s).strftime('%Y-%m-%d')
    query_time = params[:time].to_s.split(' ').last
    array_of_hours = []
    query_time.present? ? 2.times { |time| array_of_hours << query_time.to_i } : array_of_hours = [00, 23]
    time_from, time_till = ["#{query_date} #{array_of_hours[0]}:00:00", "#{query_date} #{array_of_hours[1]}:59:59"]
    params_destination_prefix = params[:destination].to_s.split('(').last.try(:chop)


    level = params[:row_id].to_s.count('.').to_i
    search_user = params[:search_user]
    search_terminator = params[:search_terminator]
    search_destination_group = params[:search_dg]
    search_prefix = params[:search_prefix]
    originator_id = search_user.to_i > 0 ? search_user : params[:originator]
    terminator_id = search_terminator if search_terminator.to_i > 0

    query_destination = if params_destination_prefix.present? && params_destination_prefix.to_i.to_s == params_destination_prefix
                          "#{params_destination_prefix}%"
                        else
                          search_prefix
                        end

    query_date_time_from = Time.parse(current_user.system_time(time_from)).to_s[0, 19].sub(' ', 'T')
    query_date_time_till =  Time.parse(current_user.system_time(time_till)).to_s[0, 19].sub(' ', 'T')
    {
        from: query_date_time_from, till: query_date_time_till,
        prefix: query_destination,
        terminator: terminator_id.to_i,
        destination_group: search_destination_group.to_i,
        user: originator_id.to_i,
        level: level.to_i
    }
  end

  def self.calls_per_hour_data_expand_rows(data_calls, query)
    row_id = query[:row_id].to_s
    call_list = _('Calls_List')
    level = row_id.count('.').to_i
    rows = []
    table_rows = data_calls[:table_rows]
    case level
    when 0
      table_rows.each_with_index do |call_zero, index|
        row_index = "#{row_id}.#{index}"
        zero_user_call_attempts = call_zero[:user_call_attempts].to_f
        zero_admin_call_attempts = call_zero[:admin_call_attempts].to_f
        zero_avg_retries = zero_user_call_attempts.zero? ? 0 : zero_admin_call_attempts / zero_user_call_attempts
        call_zero_day = call_zero[:day].to_s
        zero_date_day = call_zero_day[8..9]
        zero_date_month = call_zero_day[5..6]
        zero_date_year = call_zero_day[0..3]
        branch = call_zero[:branch]
        secret_user_id = call_zero[:secret_user_id]
        answered_calls = call_zero[:answered_calls]
        rows << "
        <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='true' style='height: 21px;' " \
        "data-tt-user_id='#{secret_user_id}'>
        <td id='cph_day_map_#{row_index}' class='side' style='text-align: left;'>#{branch}</td>
        <td id='cph_day_user_call_attempts_#{row_index}' style='text-align: right;'>" \
        "#{zero_user_call_attempts.to_i}</td>
        <td id='cph_day_user_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
        <td id='cph_day_user_acd_#{row_index}' style='text-align: center;'>" \
        "#{nice_time(call_zero[:user_acd], show_zero: true)}</td>
        <td id='cph_day_user_asr_#{row_index}' class='side' style='text-align: right;'>" \
        "#{call_zero[:user_asr].to_f.round}</td>
        <td id='cph_day_admin_call_attempts_#{row_index}' style='text-align: right;'>" \
        "#{zero_admin_call_attempts.to_i}</td>
        <td id='cph_day_admin_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
        <td id='cph_day_admin_acd_#{row_index}' style='text-align: center;'>" \
        "#{nice_time(call_zero[:admin_acd], show_zero: true)}</td>
        <td id='cph_day_admin_asr_#{row_index}' class='side' style='text-align: right;'>" \
        "#{call_zero[:admin_asr].to_f.round}</td>
        <td id='cph_day_call_list_link_#{row_index}' class='side' style='text-align: right;'>" \
        "#{Application.nice_number(zero_avg_retries)}</td>
        <td id='cph_day_duration_#{row_index}' class='side' style='text-align: center;'>" \
        "#{nice_time(call_zero[:duration], show_zero: true)}</td>
        <td id='cph_day_call_list_link_#{row_index}' style='text-align: center;'>
        <a id='call_list_link_' href='#{Web_Dir}/stats/calls_list?date_from[day]=#{zero_date_day}&date_from[hour]=0" \
        "&date_from[minute]=0&date_from[month]=#{zero_date_month}&date_from[year]=#{zero_date_year}" \
        "&date_till[day]=#{zero_date_day}&date_till[hour]=23&date_till[minute]=59" \
        "&date_till[month]=#{zero_date_month}&date_till[year]=#{zero_date_year}" \
        "&s_user=#{branch}&s_user_id=#{secret_user_id}" \
        "&s_destination=&search_on=1'>#{call_list}</a>
        </td>
        </tr>
        "
      end
    when 1
      index = -1
      23.downto(0) do |hour|
        index += 1
        row_index = "#{row_id}.#{index}"
        if table_rows.any? { |calls| calls[:hour].to_i == hour }
          call_one = table_rows.select { |call| call[:hour].to_i == hour }.first
          call_hour = call_one[:hour].to_i
          one_user_call_attempts = call_one[:user_call_attempts].to_f
          one_admin_call_attempts = call_one[:admin_call_attempts].to_f
          one_avg_retries = one_user_call_attempts.zero? ? 0 : one_admin_call_attempts / one_user_call_attempts
          call_one_day = call_one[:day].to_s
          date_day = call_one_day[8..9]
          date_month = call_one_day[5..6]
          date_year = call_one_day[0..3]
          secret_user_id = call_one[:secret_user_id]
          answered_calls = call_one[:answered_calls]
          rows << "
          <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='true' style='height: 21px;'>
          <td id='cph_day_map_#{row_index}' class='side' style='text-align: left;'>Hour #{call_hour}</td>
          <td id='cph_day_user_call_attempts_#{row_index}' style='text-align: right;'>" \
          "#{one_user_call_attempts.to_i}</td>
          <td id='cph_day_user_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
          <td id='cph_day_user_acd_#{row_index}' style='text-align: center;'>" \
          "#{nice_time(call_one[:user_acd], show_zero: true)}</td>
          <td id='cph_day_user_asr_#{row_index}' class='side' style='text-align: right;'>" \
          "#{call_one[:user_asr].to_f.round}</td>
          <td id='cph_day_admin_call_attempts_#{row_index}' style='text-align: right;'>" \
          "#{one_admin_call_attempts.to_i}</td>
          <td id='cph_day_admin_answered_calls_#{row_index}' style='text-align: right;'>" \
          "#{answered_calls}</td>
          <td id='cph_day_admin_acd_#{row_index}' style='text-align: center;'>" \
          "#{nice_time(call_one[:admin_acd], show_zero: true)}</td>
          <td id='cph_day_admin_asr_#{row_index}' class='side' style='text-align: right;'>" \
          "#{call_one[:admin_asr].to_f.round}</td>
          <td id='cph_day_call_list_link_#{row_index}' class='side' style='text-align: right;'>" \
          "#{Application.nice_number(one_avg_retries)}</td>
          <td id='cph_day_duration_#{row_index}' class='side' style='text-align: center;'>" \
          "#{nice_time(call_one[:duration], show_zero: true)}</td>
          <td id='call_list_link_#{row_index}' style='text-align: center;'>
          <a id='call_list_link_#{row_index}' " \
          "href='#{Web_Dir}/stats/calls_list?date_from[day]=#{date_day}&date_from[hour]=#{call_hour}" \
          "&date_from[minute]=0&date_from[month]=#{date_month}&date_from[year]=#{date_year}" \
          "&date_till[day]=#{date_day}&date_till[hour]=#{call_hour}&date_till[minute]=59" \
          "&date_till[month]=#{date_month}&date_till[year]=#{date_year}" \
          "&s_user=#{call_one[:nice_username]}&s_user_id=#{secret_user_id}" \
          "&s_destination=&search_on=1'>#{call_list}</a>
          </td>
          </tr>
          "
        else
          rows << "
          <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='false' style='height: 21px;'>
          <td id='cph_day_map_#{row_index}' class='side' style='text-align: left;'>Hour #{hour}</td>
          <td id='cph_day_user_call_attempts_#{row_index}' style='text-align: right;'>0</td>
          <td id='cph_day_user_answered_calls_#{row_index}' style='text-align: right;'>0</td>
          <td id='cph_day_user_acd_#{row_index}' style='text-align: center;'></td>
          <td id='cph_day_user_asr_#{row_index}' class='side' style='text-align: right;'></td>
          <td id='cph_day_admin_call_attempts_#{row_index}' style='text-align: right;'>0</td>
          <td id='cph_day_admin_answered_calls_#{row_index}' style='text-align: right;'>0</td>
          <td id='cph_day_admin_acd_#{row_index}' style='text-align: center;'></td>
          <td id='cph_day_admin_asr_#{row_index}' class='side' style='text-align: right;'></td>
          <td id='cph_day_avgretries_#{row_index}' class='side' style='text-align: right;'></td>
          <td id='cph_day_duration_#{row_index}' class='side' style='text-align: center;'></td>
          <td id='call_list_link_#{row_index}' style='text-align: center;'></td>
          </tr>
          "
        end
      end
    when 2
      table_rows.each_with_index do |call_two, index|
        call_hour = call_two[:hour].to_i
        row_index = "#{row_id}.#{index}"
        two_user_call_attempts = call_two[:user_call_attempts].to_f
        two_admin_call_attempts = call_two[:admin_call_attempts].to_f
        two_avg_retries = two_user_call_attempts.zero? ? 0 : two_admin_call_attempts / two_user_call_attempts
        call_day = call_two[:day].to_s
        date_day = call_two[:fixed_day]
        date_month = call_day[5..6]
        date_year = call_day[0..3]
        answered_calls = call_two[:answered_calls]
        rows << "
        <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='true' style='height: 21px;'>
        <td id='cph_day_map_#{row_index}' class='side' style='text-align: left;'>#{call_two[:dest_prefix]}</td>
        <td id='cph_day_user_call_attempts_#{row_index}' style='text-align: right;'>#{two_user_call_attempts.to_i}</td>
        <td id='cph_day_user_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
        <td id='cph_day_user_acd_#{row_index}' style='text-align: center;'>" \
        "#{nice_time(call_two[:user_acd], show_zero: true)}</td>
        <td id='cph_day_user_asr_#{row_index}' class='side' style='text-align: right;'>" \
        "#{call_two[:user_asr].to_f.round}</td>
        <td id='cph_day_admin_call_attempts_#{row_index}' style='text-align: right;'>" \
        "#{two_admin_call_attempts.to_i}</td>
        <td id='cph_day_admin_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
        <td id='cph_day_admin_acd_#{row_index}' style='text-align: center;'>" \
        "#{nice_time(call_two[:admin_acd], show_zero: true)}</td>
        <td id='cph_day_admin_asr_#{row_index}' class='side' style='text-align: right;'>" \
        "#{call_two[:admin_asr].to_f.round}</td>
        <td id='cph_day_call_list_avgretries_#{row_index}' class='side' style='text-align: right;'>" \
        "#{Application.nice_number(two_avg_retries)}</td>
        <td id='cph_day_duration_#{row_index}' class='side' style='text-align: center;'>" \
        "#{nice_time(call_two[:duration], show_zero: true)}</td>
        <td id='call_list_link_#{row_index}' class='side' style='text-align: center;'>
        <a id='call_list_link_#{row_index}' " \
        "href='#{Web_Dir}/stats/calls_list?date_from[day]=#{date_day}&date_from[hour]=#{call_hour}" \
        "&date_from[minute]=0&date_from[month]=#{date_month}&date_from[year]=#{date_year}" \
        "&date_till[day]=#{date_day}&date_till[hour]=#{call_hour}&date_till[minute]=59" \
        "&date_till[month]=#{date_month}&date_till[year]=#{date_year}" \
        "&s_user=#{call_two[:nice_username]}&s_destination=#{call_two[:prefix]}%25" \
        "&s_user_id=#{call_two[:secret_user_id]}&search_on=1'>#{call_list} </a>
        </td>
        </tr>
        "
      end
    when 3
      table_rows.each_with_index do |call, index|
        row_index = "#{row_id}.#{index}"
        user_call_attempts = call[:user_call_attempts].to_i
        admin_call_attempts = call[:admin_call_attempts].to_i
        avg_retries = user_call_attempts.zero? ? 0 : admin_call_attempts / user_call_attempts
        answered_calls = call[:answered_calls]
        rows << "
        <tr data-tt-id='#{row_index}' data-tt-parent-id='#{row_id}' data-tt-branch='false' style='height: 21px;'>
        <td id='cph_day_map_#{row_index}' class='side' style='text-align: left;'>#{call[:terminator_name]}</td>
        <td id='cph_day_user_call_attempts_#{row_index}' style='text-align: right;'>#{user_call_attempts.to_i}</td>
        <td id='cph_day_user_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
        <td id='cph_day_user_acd_#{row_index}' style='text-align: center;'>" \
        "#{nice_time(call[:user_acd], show_zero: true)}</td>
        <td id='cph_day_user_asr_#{row_index}' class='side' style='text-align: right;'>" \
        "#{call[:user_asr].to_f.round}</td>
        <td id='cph_day_admin_call_attempts_#{row_index}' style='text-align: right;'>#{admin_call_attempts.to_i}</td>
        <td id='cph_day_admin_answered_calls_#{row_index}' style='text-align: right;'>#{answered_calls}</td>
        <td id='cph_day_admin_acd_#{row_index}' style='text-align: center;'>" \
        "#{nice_time(call[:admin_acd], show_zero: true)}</td>
        <td id='cph_day_admin_asr_#{row_index}' class='side' style='text-align: right;'>" \
        "#{call[:admin_asr].to_f.round}</td>
        <td id='cph_day_call_list_link_#{row_index}' class='side' style='text-align: right;'>" \
        "#{Application.nice_number(avg_retries)}</td>
        <td id='cph_day_duration_#{row_index}' class='side' style='text-align: center;'>" \
        "#{nice_time(call[:duration], show_zero: true)}</td>
        <td id='call_list_link_#{row_index}' style='text-align: center;'>
        </td>
        </tr>
        "
      end
    end
    rows.join
  end

  def self.calls_per_hour_options(params = {}, options = {})
    options[:destination_groups] = Destinationgroup.order(:name).all
    if params[:commit] == 'refine'
      options[:searching] = true
    elsif params[:clear] == 'clear'
      options[:prefix] = nil
      options[:s_user] = nil
      options[:s_terminator] = nil
      options[:s_user_id] = -2
      options[:s_terminator_id] = -2
      options[:searching] = false
    end
    options
  end

  def self.data_line(line, table_data_keys, session, originator_str, terminator_str, dec)
      data_line = []
      data_line << line[_('Destination_Group')] if table_data_keys.include?(_('Destination_Group'))
      data_line << line[_('Prefix')] if table_data_keys.include?(_('Prefix'))
      data_line << line[originator_str] if table_data_keys.include?(originator_str)
      data_line << line[_('Origination_point')] if table_data_keys.include?(_('Origination_point'))
      data_line << line[terminator_str] if table_data_keys.include?(terminator_str)
      data_line << line[_('Termination_point')] if table_data_keys.include?(_('Termination_point'))
      data_line << line[_('Manager')] if table_data_keys.include?(_('Manager'))

      data_line << line["#{originator_str} (#{session[:show_currency]})"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{originator_str} (#{session[:show_currency]})")
      data_line << line["#{originator_str} #{_('with_TAX')} (#{session[:show_currency]})"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{originator_str} #{_('with_TAX')} (#{session[:show_currency]})")
      data_line << line["#{terminator_str} (#{session[:show_currency]})"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{terminator_str} (#{session[:show_currency]})")
      data_line << line[_('Profit')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?(_('Profit'))
      data_line << line[(_('Profit') + ' %')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?(_('Profit') + ' %')
      data_line << nice_time(line[" #{originator_str} "].to_i) if table_data_keys.include?(" #{originator_str} ")
      data_line << nice_time(line[" #{terminator_str} "].to_i) if table_data_keys.include?(" #{terminator_str} ")
      data_line << nice_time(line[_('Duration')].to_i) if table_data_keys.include?(_('Duration'))

      data_line << line[_('Answered')].to_i if table_data_keys.include?(_('Answered'))
      data_line << line[_('Total')].to_i if table_data_keys.include?(_('Total'))

      data_line << line["#{_('ASR')} %"].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?("#{_('ASR')} %")
      data_line << nice_time(line[_('ACD')].to_i) if table_data_keys.include?(_('ACD'))
      data_line << line[_('PDD')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec) if table_data_keys.include?(_('PDD'))
      data_line
  end

end
