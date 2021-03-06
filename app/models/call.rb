# Call model
class Call < ActiveRecord::Base
  include SqlExport
  include CsvImportDb
  extend UniversalHelpers
  belongs_to :user
  belongs_to :device, foreign_key: 'accountcode'
  has_one :call_detail
  belongs_to :server

  validates_presence_of :calldate, message: _('Calldate_cannot_be_blank')
  attr_accessible :server_id
  attr_protected

  def call_log_request
    "/usr/local/m2/m2_call_log \"#{id}\""
  end

  def nice_billsec
    billsec = self.billsec
    billsec = self.real_billsec.ceil if billsec == 0 and self.real_billsec > 1
    billsec
  end

  def nice_duration
    duration = self.duration
    duration = self.real_duration.ceil if duration == 0 && self.real_duration > 1
    duration
  end

  def self.nice_billsec_condition
    if User.current.is_user? and Confline.get_value('Invoice_user_billsec_show', User.current.owner.id).to_i == 1
      'CEIL(user_billsec)'
    else
      'IF((billsec = 0 AND real_billsec > 1), CEIL(real_billsec), billsec)'
    end
  end

  def self.nice_billsec_sql
    nice_billsec_condition << " as 'nice_billsec'"
  end

  def Call.nice_answered_cond_sql(search_not = true)
    where_clause = " calls.disposition = 'ANSWERED' "

    if self.user_is_user_and_hgc_not_equal_to_sixteen

      if search_not
        " (#{where_clause}AND calls.hangupcause='16') "
      else
        " (#{where_clause}OR (calls.disposition='ANSWERED' AND calls.hangupcause!='16') ) "
      end
    else
      where_clause
    end
  end

  def Call.nice_failed_cond_sql
    where_clause = " calls.disposition = 'FAILED' "

    if self.user_is_user_and_hgc_not_equal_to_sixteen
      " (#{where_clause}OR (calls.disposition='ANSWERED' and calls.hangupcause!='16')) "
    else
      where_clause
    end
  end

  def Call.nice_disposition
    if self.user_is_user_and_hgc_not_equal_to_sixteen
      " IF(calls.disposition  = 'ANSWERED',IF((calls.disposition='ANSWERED' AND calls.hangupcause='16'), 'ANSWERED', 'FAILED'), disposition)"
    else
      " IF(calls.hangupcause = '312', 'CANCEL', calls.disposition)"
    end
  end

  def destinations
    (self.prefix and (self.prefix.to_i > 0)) ? Destination.find(self.prefix) : nil
  end

  def peerip
    self.call_detail.try :peerip
  end

  def recvip
    self.call_detail.try :recvip
  end

  def sipfrom
    self.call_detail.try :sipfrom
  end

  def uri
    self.call_detail.try :uri
  end

  def useragent
    self.call_detail.try :useragent
  end

  def peername
    self.call_detail.try :peername
  end

  def t38passthrough
    self.call_detail.try :t38passthrough
  end

  # Returns hash with call debuginfo if that info exists otherwise returns nil
  def getDebugInfo
    debug = 0
    debug += self.peerip.size if self.peerip
    debug += self.recvip.size if self.recvip
    debug += self.sipfrom.size if self.sipfrom
    debug += self.uri.size if self.uri
    debug += self.useragent.size if self.useragent
    debug += self.peername.size if self.peername
    #debug += self.t38passthrough.size if self.t38passthrough
    if debug != 0
      debuginfo = Hash.new()
      self.peerip ? debuginfo['peerip'] = self.peerip.to_s : debuginfo['peerip'] = ''
      self.recvip ? debuginfo['recvip'] = self.recvip.to_s : debuginfo['recvip'] = ''
      self.sipfrom ? debuginfo['sipfrom'] = self.sipfrom.to_s : debuginfo['sipfrom'] = ''
      self.useragent ? debuginfo['useragent'] = self.useragent.to_s : debuginfo['useragent'] = ''
      self.peername ? debuginfo['peername'] = self.peername.to_s : debuginfo['peername'] = ''
      self.uri ? debuginfo['uri'] = self.uri.to_s : debuginfo['uri'] = ''
      self.t38passthrough ? debuginfo['t38passthrough'] = self.t38passthrough.to_s : debuginfo['t38passthrough'] = ''
      debuginfo
    else
      nil
    end
  end

  def Call::total_calls_by_direction_and_disposition(start_date, end_date, users = [])
    #parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    #returns - array of hashs. total call count for incoming and outgoing, answered, not answered,
    #  busy and failed calls grouped by disposition and direction originated or received by
    #  specified users. if no users were specified - for all users
    Call.total_calls_by([], {outgoing: true, incoming: true}, start_date, end_date, {direction: true, disposition: true}, users)
  end

  def Call::answered_calls_day_by_day(start_date, end_date, users = [])

    raw_calls = Call.total_calls_by(['ANSWERED'], {outgoing: true, incoming: true}, start_date, end_date, {date: true}, users)
    totals = raw_calls.pop
    tz = User.current.time_zone

    start_time = Time.parse(start_date).in_time_zone(tz).strftime('%F')
    end_time = Time.parse(end_date).in_time_zone(tz).strftime('%F')

    dates = (start_time.to_date..end_time.to_date).map { |date| date.strftime('%F') }
    calls = []
    t_billsec = []
    avg_billsec = []

    date_get = lambda do |index|
      (Time.parse(start_date).in_time_zone(tz) + (index).days).strftime('%F %T')
    end

    dates.each_with_index do |date, index|
      interval = raw_calls.select do |summary|
        date = summary[:calldate].strftime('%F %T')
        date >= date_get[index] && date < date_get[index + 1]
      end

      unless interval.blank?

        call_count = interval.collect(&:total_calls).sum
        billsec = interval.collect(&:total_billsec).sum

        calls << call_count
        t_billsec << billsec
        avg_billsec << (billsec / call_count)
      else
        calls << 0
        t_billsec << 0
        avg_billsec << 0
      end
    end

    return dates, calls, t_billsec, avg_billsec, totals
  end

  def Call::total_calls_by(disposition, direction, start_date, end_date, group_options = [], users = [])
    #parameters:
    #  disposition - expected array of dispositions deffined as
    #    strings(why not incapsulate strings by creating class Disposition?)
    #  direction - call direction(outgoing, incoming or both) expected array
    #    of posible directions as contstans or whatever it is:/(again why not
    #    incapsulate it in separate class?)
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string. if datetime or datetime sring will be passed QUERY WILL FAIL
    #  users - array of user id's, if not supplied, but direction is it will default to all
    #    incoming and/or outgoing calls
    #returns:
    #  whatever Calls.find returns, and the last element in array will be totals/averages of all fetched values
    select = []
    select << "COUNT(*) AS 'total_calls'"
    select << "SUM(calls.billsec) AS 'total_billsec'"
    select << "AVG(calls.billsec) AS 'average_billsec'"

    condition = []
    condition << "calls.calldate BETWEEN '#{start_date.to_s}' AND '#{end_date.to_s}'"
    #if disposition is not specified or it is all 4 types(answered, failed, busy, no answer),
    #there is no need to filter it
    condition << "calls.disposition IN ('#{disposition.join(', ')}')" if !disposition.empty? and disposition.length < 4

    join = []
    if users.empty?
      if direction.include?(:incoming) and direction.include?(:outgoing)
        condition << 'calls.user_id IS NOT NULL'
      else
        condition << 'calls.user_id != -1 AND calls.user_id IS NOT NULL' if direction.include?(:outgoing)
        condition << 'calls.user_id = -1' if direction.include?(:incoming)
      end
    else
      #no mater weather we are allready checking devices for user_id, call.user_id might still be NULL, else we would select
      #to many failed calls
      condition << 'calls.user_id IS NOT NULL'
      if direction.include?(:outgoing) and direction.include?(:incoming)
        condition << "(dst_devices.user_id IN (#{users.join(', ')}) OR src_devices.user_id IN (#{users.join(', ')}))"
      end
      if direction.include?(:incoming)
        join << 'LEFT JOIN devices dst_devices ON calls.dst_device_id = dst_devices.id'
        condition << "dst_devices.user_id IN (#{users.join(', ')}" if !direction.include?(:outgoing)
      end
      if direction.include?(:outgoing)
        join << 'LEFT JOIN devices src_devices ON calls.src_device_id = src_devices.id'
        condition << "src_devices.user_id IN (#{users.join(', ')})" if !direction.include?(:incoming)
      end
    end

    # dont group at all, group by date, direction and/or disposition
    # accordingly, we should select those fields from table
    group = []
    options_date = group_options[:date]
    if options_date
      select << "(calls.calldate) AS 'calldate'"
      group << 'year(calldate), month(calldate), day(calldate), hour(calldate)'
    end

    if group_options[:disposition]
      select << 'calls.disposition'
      group << 'calls.disposition'
    end

    if group_options[:direction]
      if users.empty?
        select << "IF(calls.user_id  = -1, 'incoming', 'outgoing') AS 'direction'"
        group << 'direction'
      else
        if direction.include?(:incoming)
          select << "IF(dst_devices.user_id IN (#{users.join(', ')}), 'incoming', 'outgoing') AS 'direction'"
          group << 'direction'
        end
        if direction.include?(:outgoing) and !direction.include?(:incoming)
          select << "IF(src_device.user_id IN (#{users.join(', ')}), 'outgoing', 'incoming') AS 'direction'"
          group << 'direction'
        end
      end
    end

    if options_date
      statistics = Call.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
      statistics.each do |st|
        st.calldate = (st.calldate.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db) if !st.calldate.blank?
      end
    else
      statistics = Call.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
    end

    #calculating total billsec, total calls and average billsec
    total_calls = 0
    total_billsec = 0
    for stats in statistics
      total_calls += stats['total_calls'].to_i
      total_billsec += stats['total_billsec'].to_i
    end
    average_billsec = total_calls == 0 ? 0 : total_billsec/total_calls

    #return array of hashs, bet we should definetly return some sort of Statistics class
    statistics << {'total_calls' => total_calls, 'total_billsec' => total_billsec, 'average_billsec' => average_billsec}
  end

  def Call.calls_order_by(params, options)
    case options[:order_by].to_s.strip
      when 'time'
        order_by = 'calls.calldate'
      when 'src'
        order_by = 'calls.src'
      when 'dst'
        order_by = 'calls.dst'
      when 'nice_billsec'
        order_by = 'nice_billsec'
      when 'hgc'
        order_by = 'calls.hangupcause'
      when 'server'
        order_by = 'calls.server_id'
      when 'p_name'
        order_by = 'providers.name'
      when 'p_rate'
        order_by = 'calls.provider_rate'
      when 'p_price'
        order_by = 'calls.provider_price'
      when 'user'
        order_by = 'nice_user'
      when 'u_rate'
        order_by = 'calls.user_rate'
      when 'u_price'
        order_by = 'calls.user_price'
      when 'prefix'
        order_by = 'calls.prefix'
      when 'direction'
        order_by = 'destinations.direction_code'
      when 'destination'
        order_by = 'destinations.name'
      when 'duration'
        order_by = 'duration'
      when 'answered_calls'
        order_by = 'answered_calls'
      when 'total_calls'
        order_by = 'total_calls'
      when 'asr'
        order_by = 'asr'
      when 'acd'
        order_by = 'acd'
      when 'markup'
        order_by = 'markup'
      when 'margin'
        order_by = 'margin'
      when 'user_price'
        order_by = 'user_price'
      when 'provider_price'
        order_by = 'provider_price'
      when 'profit'
        order_by = 'profit'
      when 'termination_name'
        order_by = 'nice_device'
      else
        col = options[:order_by]
        order_by = col if Call.column_names.include?(col)
    end

    unless order_by.blank?
      order_by += (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end

    order_by
  end


  def call_log
    CallLog.where(uniqueid: self.uniqueid).first
  end

  def Call.last_calls(options = {})
    current_user = options[:current_user]
    current_user_id = current_user.id
    cond, var, jn = Call.last_calls_parse_params(options)
    select = ['/*+ MAX_EXECUTION_TIME(300000) */ calls.*', Call.nice_billsec_sql]
    select << SqlExport.nice_user_sql
    select << Call.nice_disposition + ' AS disposition'
    select << "#{SqlExport.nice_device_sql('devices', 'nice_device', 'device_users')} "

    if current_user.usertype == 'user'
      # When simple user is checking calls list page, displayed price should depend on who made a call
      # If user made a call, show user_price, if someone else made a call trough user's terminator, show provider_price
      select << "(IF(calls.provider_id = #{current_user_id}, calls.provider_price, calls.user_price) * #{options[:exchange_rate]}) AS user_price_exrate"
      select << "(IF(calls.provider_id = #{current_user_id}, calls.provider_rate, calls.user_rate) * #{options[:exchange_rate]}) AS user_rate_exrate"
    else
      select << "(#{SqlExport.user_price_sql} * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.admin_user_rate_sql} * #{options[:exchange_rate]} ) AS user_rate_exrate"
      select << "(#{SqlExport.admin_provider_rate_sql} * #{options[:exchange_rate]}) AS provider_rate_exrate "
      select << "(#{SqlExport.admin_provider_price_sql} * #{options[:exchange_rate]} ) AS provider_price_exrate"
    end

    if options[:show_device_and_cid].to_i == 1
      select << "CASE WHEN src_device.description IS NULL or src_device.description = '' THEN CONCAT('nice_user', '/', src_device.host, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') ELSE CONCAT(src_device.description, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') END AS nice_src_device"
    end

    jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
    # Termination Points
    jn << "LEFT JOIN devices ON devices.id = calls.dst_device_id"
    jn << "LEFT JOIN users as device_users ON (devices.user_id = device_users.id)" # Nescessary because not allways device.user_id equals calls.user_id, used to retrieve device user info
    order = ActiveRecord::Base::sanitize(options[:order])[1..-2] if options[:order].present?
    used_index = calldate_index ? "FORCE INDEX(#{calldate_index})" : ''
    calls = Call.select(select.join(", \n"))
                .from("calls #{used_index}")
                .where([cond.join(" \nAND "), *var])
                .joins(jn.join(" \n")).order(order)
                .page(options[:page]).per(options[:items_per_page]).to_a

    return calls

    rescue ActiveRecord::StatementInvalid => e
    return ['error', _('Query_execution_time_is_too_long_please_select_shorter_period')] if e.to_s.include?('maximum statement execution time exceeded')
    return ['error', 'Mysql Error']
  end

  def self.calldate_index
    ActiveRecord::Base.connection.select(
        'SHOW INDEX IN calls WHERE Column_name = "calldate"'
    ).first['Key_name']
  end

  def Call.last_calls_total_stats(options = {})
    options[:exchange_rate] ||= 1
    cond, var, jn = Call.last_calls_parse_params(options)
    prov_price = "(SUM(#{SqlExport.admin_provider_price_sql}) * #{options[:exchange_rate].to_d}) as total_provider_price"
    user_price = SqlExport.user_price_sql

    if User.current.is_user? and Confline.get_value("Invoice_user_billsec_show", User.current.owner.id).to_i == 1
      billsec_sql = "CEIL(user_billsec)"
    else
      billsec_sql = "IF((billsec = 0 AND real_billsec > 1), CEIL(real_billsec), billsec)"
    end

    Call.select("COUNT(*) as total_calls,
                 SUM(#{billsec_sql}) as total_duration,
                 SUM(#{user_price}) * #{options[:exchange_rate].to_d} as total_user_price," + prov_price)
        .where([cond.join(' AND '), *var])
        .joins(jn.join(" \n")).first
  end

  def Call.last_calls_csv(options = {})
    cond, var, jn = Call.last_calls_parse_params(options)
    s = []
    format = Confline.get_value('Date_format', options[:current_user].owner_id).gsub('M', 'i')
    csv_full_src = (options[:show_full_src].to_i == 1)
    # calldate2 - because something overwites calldate when changing date format
    seconds_interval = options[:seconds_interval]
    time_offset = seconds_interval.present? ? seconds_interval.to_i : options[:current_user].time_offset
    automatic_cdr_export = options[:automatic_cdr_export].present?
    cdr_template_id = options[:cdr_template_id].present?
    column_options = options[:column_options]

    if options[:api].to_i == 1
      format = '%Y-%m-%d %H:%i:%S'
      s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => format, :offset => 0}), "calldate2")
      s << SqlExport.column_escape_null('calls.uniqueid', 'uniqueid')
    else
      s << SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => format, :offset => time_offset}), "calldate2")
    end

    unless csv_full_src
      s << SqlExport.column_escape_null('calls.src', 'src')
    end

    if csv_full_src or options[:pdf].to_i == 1
      s << SqlExport.column_escape_null('calls.clid', 'clid')
    end

    options[:current_user].usertype == 'user' ? s << SqlExport.hide_dst_for_user_sql(options[:current_user], "csv", SqlExport.column_escape_null('calls.localized_dst'), {as: 'dst'}) : s << SqlExport.column_escape_null('calls.localized_dst', 'dst')
    s << SqlExport.column_escape_null("calls.prefix", "prefix")
    s << "CONCAT(#{SqlExport.column_escape_null("directions.name")}, ' ', #{SqlExport.column_escape_null("destinations.name")}) as destination"
    s << Call.nice_billsec_sql
    s << 'calls.duration as duration' if %w[admin manager].include?(options[:current_user].usertype) && (column_options[:show_duration] || options[:api].to_i == 1)


    if options[:current_user].usertype != 'user' || options[:current_user].show_hangupcause.to_i == 1
      s << SqlExport.column_escape_null("IF(calls.hangupcause = '312', 'CANCEL', CONCAT(#{SqlExport.column_escape_null("calls.disposition")}, '(', #{SqlExport.column_escape_null("calls.hangupcause")}, ')'))", 'dispod')
    else
      s << SqlExport.column_escape_null(Call.nice_disposition, 'dispod')
    end

    if %w[admin manager].include?(options[:current_user].usertype)
      unless options[:hide_finances]
        jn << 'LEFT JOIN devices AS dst_provider_device ON (dst_provider_device.id = calls.dst_device_id) LEFT JOIN users AS dst_device_user ON (dst_device_user.id = dst_provider_device.user_id)'
        s << "IF(dst_provider_device.id IS NULL, '', IF(LENGTH(dst_provider_device.description ) > 0, dst_provider_device.description, CONCAT(IF(dst_device_user.id IS NULL, '', IF((LENGTH(dst_device_user.first_name ) > 0 AND (LENGTH(dst_device_user.last_name) > 0)), CONCAT(dst_device_user.first_name, ' ', dst_device_user.last_name), IF((LENGTH(dst_device_user.first_name) > 0), dst_device_user.first_name, IF((LENGTH(dst_device_user.last_name) > 0), dst_device_user.last_name, dst_device_user.username)))), '/', dst_provider_device.host))) AS 'provider'"

        if !options[:current_user].is_manager? || (options[:current_user].is_manager? && !options[:current_user].authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_rate))
          s << SqlExport.replace_dec_round("(IF(calls.provider_rate IS NULL, 0, #{SqlExport.admin_provider_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
        end

        if !options[:current_user].is_manager? || (options[:current_user].is_manager? && !options[:current_user].authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_price))
          s << SqlExport.replace_dec_round("(IF(calls.provider_price IS NULL, 0, #{SqlExport.admin_provider_price_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_price')
        end
      end

      s << "IF(users.first_name = '' and users.last_name = '', users.username, (#{SqlExport.nice_user_sql('users', false)})) as 'user'"

      if cdr_template_id || automatic_cdr_export
        v3_columns = get_v3_columns
        v3_swapped_columns = v3_swap
        s << SqlExport.column_escape_null('calls.id', 'id')
        s << SqlExport.column_escape_null('calls.uniqueid', 'uniqueid')
        s << SqlExport.column_escape_null('calls.src', 'src') unless s.join(', ').include? 'AS src,'
        s << SqlExport.column_escape_null('calls.clid', 'clid') unless s.join(', ').include? 'AS clid,'
        s << SqlExport.column_escape_null('calls.dst', 'dst_original')
        s << SqlExport.column_escape_null('calls.billsec', 'billsec')
        s << SqlExport.column_escape_null('calls.duration', 'duration') if column_options[:show_duration].blank?
        s << SqlExport.column_escape_null('calls.src_device_id', 'src_device_id')
        s << SqlExport.column_escape_null('calls.dst_device_id', 'dst_device_id')
        s << SqlExport.column_escape_null('calls.server_id', 'server_id')
        s << SqlExport.column_escape_null('calls.hangupcause', 'hangupcause')
        s << SqlExport.column_escape_null("IF(calls.hangupcause = 312, 'CANCEL', calls.disposition)", 'disposition')
        s << SqlExport.column_escape_null(v3_swapped_columns[:originator_ip], 'originator_ip')
        s << SqlExport.column_escape_null(v3_swapped_columns[:terminator_ip], 'terminator_ip')
        s << SqlExport.column_escape_null('calls.real_duration', 'real_duration')
        s << SqlExport.column_escape_null('calls.real_billsec', 'real_billsec')
        s << SqlExport.column_escape_null('calls.provider_billsec', 'provider_billsec')
        s << SqlExport.column_escape_null('calls.dst_user_id', 'dst_user_id')
        s << SqlExport.column_escape_null(SqlExport.nice_date('calls.answer_time', {:format => format, :offset => time_offset}), "answer_time") if column_exists?(:answer_time)
        s << SqlExport.column_escape_null(SqlExport.nice_date('calls.end_time', {:format => format, :offset => time_offset}), "end_time") if column_exists?(:end_time)
        s << SqlExport.column_escape_null('calls.terminated_by', 'terminated_by') if column_exists?(:terminated_by)
        s << SqlExport.column_escape_null('calls.src_user_id', 'src_user_id') if column_exists?(:src_user_id)
        s << SqlExport.replace_dec_round('calls.pdd', options[:column_dem], 'pdd') if column_exists?(:pdd)
        s << SqlExport.column_escape_null('destinations.name', 'destination_name')
        s << SqlExport.column_escape_null('directions.name', 'direction_name')
        s << SqlExport.column_escape_null(v3_swapped_columns[:originator_codec], 'originator_codec') if column_exists?(:originator_codec)
        s << SqlExport.column_escape_null(v3_swapped_columns[:terminator_codec], 'terminator_codec') if column_exists?(:terminator_codec)
        s << SqlExport.column_escape_null('calls.pai', 'pai_number') if column_exists?(:pai)

        v3_columns.each do |col|
          if col.include?('ip')
            s << SqlExport.column_escape_null(int_to_ip_sql(col), col)
          elsif col.include?('codec')
            next
          else
            s << SqlExport.column_escape_null('calls.' + col, col)
          end
        end

      else
        s << SqlExport.column_escape_null(SqlExport.nice_date('calls.answer_time', {format: format, offset: time_offset}), 'answer_time') if column_options[:show_answer_time]
        s << SqlExport.column_escape_null(SqlExport.nice_date('calls.end_time', {format: format, offset: time_offset}), 'end_time') if column_options[:show_end_time]
        s << SqlExport.column_escape_null('calls.terminated_by', 'terminated_by') if column_options[:show_terminated_by]
        s << SqlExport.replace_dec_round('calls.pdd', options[:column_dem], 'pdd') if column_options[:show_pdd]
      end

      if options[:show_device_and_cid].to_i == 1
        # s << "CONCAT(src_device.device_type, '/', src_device.extension, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') AS nice_src_device"
        s << "CASE WHEN src_device.description IS NULL or src_device.description = '' THEN CONCAT('nice_user', '/', src_device.host, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') ELSE CONCAT(src_device.description, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') END AS nice_src_device"
        jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
      end

      unless options[:hide_finances]
        s << SqlExport.replace_dec_round("(IF(calls.user_rate IS NULL, 0, #{SqlExport.user_rate_sql}) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
        s << SqlExport.replace_dec_round("(IF(calls.user_price IS NULL, 0, #{SqlExport.user_price_sql}) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
      end
    end

    if options[:current_user].show_billing_info == 1 && !options[:hide_finances]
      if options[:current_user].usertype == 'user'

        # When simple user is checking calls list page, displayed price should depend on who made a call
        # If user made a call show user_price
        # If someone else made a call trough user's terminator, show provider_price
        s << SqlExport.replace_dec_round("(IF(calls.provider_id = #{options[:current_user].id}, calls.provider_price, calls.user_price) * #{options[:exchange_rate]}) ", options[:column_dem], 'user_price')

        if options[:show_device_and_cid].to_i == 1
          s << "CASE WHEN src_device.description IS NULL or src_device.description = '' THEN CONCAT('nice_user', '/', src_device.host, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') ELSE CONCAT(src_device.description, ' (', SUBSTRING_INDEX(SUBSTRING_INDEX(src_device.callerid, '<', -1), '>', 1), ')') END AS nice_src_device"
          jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls.src_device_id)"
        end
      end
    end

    # setting headers
    options_from = options[:from_no_tz].blank? ? options[:from] : options[:from_no_tz]
    options_till = options[:till_no_tz].blank? ? options[:till] : options[:till_no_tz]
    filename = "Calls_list-#{options[:current_user].id.to_s.gsub(" ", "_")}-#{options_from.gsub(" ", "_").gsub(":", "_")}-#{options_till.gsub(" ", "_").gsub(":", "_")}-#{DateTime.now.strftime('%Q').to_i}"
    sql = 'SELECT /*+ MAX_EXECUTION_TIME(300000) */ * '

    test = options[:test]

    if options[:pdf].to_i == 0 && test != 1 && options[:cdr_template_id].blank?
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            OPTIONALLY ENCLOSED BY '\"'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    # Call.last_calls_parse_params might return "LEFT JOIN destinations ..."
    # if condition below is met, in that case we should not join destinations again
    # it is very important to join tables in this paricular order DO NOT CHANGE IT
    jn << "LEFT JOIN destinations ON destinations.prefix = IFNULL(calls.prefix, '') " if options[:s_country].blank? && options[:destination_group_id].blank?
    jn << 'LEFT JOIN directions ON directions.code = (destinations.direction_code)'

    order_by = options[:order] || 'calldate'
    used_index = calldate_index ? "FORCE INDEX(#{calldate_index})" : ''
    sql += " FROM ((SELECT #{s.join(', ')}
             FROM calls #{used_index} "
    sql += jn.join(' ')
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{order_by.gsub('nice_user', 'user')} )) as C"

    test_content = ''


    if cdr_template_id && !automatic_cdr_export
      BackgroundTask.cdr_export_template(
          {
              template_id: options[:cdr_template_id], user_id: options[:current_user].id,
              sql: sql, from: options[:from], till: options[:till]
          }
      )
      return false
    elsif automatic_cdr_export
      return sql
    elsif test.to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      if options[:pdf].to_i == 1
        filename = Call.find_by_sql(sql)
      else
        # Export MySQL query into outfile without headers
        ActiveRecord::Base.connection.execute(sql)

        # Append headers to first line of .csv file
        one_row = "SELECT #{s.join(', ')} FROM calls #{jn.join(' ')} LIMIT 1"
        columns = ActiveRecord::Base.connection.select_all(one_row).columns
        headers = self.last_calls_csv_headers

        if User.current.usertype.to_s == 'user'
          headers['nice_billsec'] = _('Duration')
          headers.delete('duration')
        end
        headers = columns.map { |name| "#{headers[name] || name}" }

        filename = load_file_through_database(filename) if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
        return filename, test_content if filename.nil?

        file_path_old = "/tmp/#{filename}.csv"
        filename << '_2'
        file_path_new = "/tmp/#{filename}.csv"

        File.open(file_path_new, 'w') do |fo|
          fo.puts "#{headers.join(options[:collumn_separator])}\n"
          File.foreach(file_path_old) do |li|
            fo.puts li
          end
        end
      end
    end


    return filename, test_content
    rescue ActiveRecord::StatementInvalid => e
      if e.to_s.include?("maximum statement execution time exceeded")
        return 'error', _('Query_execution_time_is_too_long_please_select_shorter_period')
      else
        return 'error', 'Mysql Error'
      end
  end

  def Call.calls_for_load_stats(options = {})
    cond = ["(calldate BETWEEN '#{options[:a1]}' AND '#{options[:a2]}')"]
    server_id = options[:s_server]
    user_id = options[:s_user]
    device_id = options[:s_device]
    if server_id.to_i != -1
      cond << "(server_id = #{server_id})"
    end

    if user_id.to_i != -1
      cond << "(user_id = #{user_id})"

      if device_id.to_i != -1
        cond << "(src_device_id = #{device_id})"
      end
    end
    current_user = options[:current_user]
    if current_user.show_only_assigned_users?
      assigned_users = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
      assigned_users = assigned_users.map(&:inspect).join(', ')
      cond << "(user_id IN (#{assigned_users.present? ? assigned_users : 'NULL'}))"
    end

    all_calls = ActiveRecord::Base.connection.select_all("
      SELECT DATE_FORMAT((calldate + INTERVAL #{current_user.time_offset} SECOND), '%H:%i') AS call_minute, COUNT(id) AS calls
      FROM `calls`
      WHERE #{cond.join(' AND ')}
      GROUP BY call_minute ORDER BY call_minute;
    ")

    answered_calls = ActiveRecord::Base.connection.select_all("
      SELECT TIME_TO_SEC(DATE_FORMAT((calldate + INTERVAL #{current_user.time_offset} SECOND), '%H:%i:00')) DIV 60 AS time_index_from,
             ((duration DIV 60) + IF((duration % 60) > 0, 1, 0)) AS minute_duration,
             COUNT(id) AS calls_count
      FROM calls
      WHERE #{cond.join(' AND ')} AND disposition = 'ANSWERED'
      GROUP BY time_index_from, minute_duration
      ORDER BY time_index_from;
    ")

    highest_duration = where("#{cond.join(' AND ')}").where(disposition: 'ANSWERED').maximum(:duration)

    return all_calls, answered_calls, highest_duration
  end

  def self.country_stats_download_table_csv(params, user)
    require 'csv'

    filename = "Country_stats-#{params[:search_time][:from]}-#{params[:search_time][:till]}-#{Time.now.to_i}".gsub(/( |:)/, '_')
    sep, dec = user.csv_params
    table_data = JSON.parse(params[:table_content])

    CSV.open('/tmp/' + filename + '.csv', 'w', {col_sep: sep, quote_char: "\""}) do |csv|
      csv_header = [_('Destination_Group'), _('Calls'), _('Time'), _('ACD'), _('Price')]
      csv_header.push(_('User_price'), _('Profit')) if user.usertype.to_s != 'user'
      csv << csv_header

      table_data.each_with_index do |line|
        csv_lines = [
            line[_('Destination_Group')],
            line[_('Calls')].to_i,
            nice_time(line[_('Time')].to_i),
            nice_time(line[_('ACD')].to_i),
            line[_('Price')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec)
        ]

        if user.usertype.to_s != 'user'
          csv_lines.push(
              line[_('User_price')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec),
              line[_('Profit')].gsub(/(,|;)/, '.').to_f.to_s.gsub('.', dec)
          )
        end

        csv << csv_lines
      end
    end

    return filename
  end

  def Call.analize_cdr_import(name, options)
    CsvImportDb.log_swap('analyze')
    MorLog.my_debug("CSV analyze_file #{name}", 1)
    arr = {}
    current_user = User.current.id
    arr[:calls_in_db] = 0 # Call.where(owner_id: current_user).all.size.to_i
    arr[:clis_in_db] = Callerid.joins('JOIN devices ON (devices.id = callerids.device_id) JOIN users ON (devices.user_id = users.id)').where("users.owner_id = #{current_user}").all.size.to_i

    if options[:step] and options[:step] == 8
      arr[:step] = 8
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 0, nice_error = 0 where id > 0")
    else
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET not_found_in_db = 0, f_error = 0, nice_error = 0 where id > 0")
    end

    if options[:imp_clid] and options[:imp_clid] >= 0
      #set flag on not found and count them
      found_clis = ActiveRecord::Base.connection.select_all("SELECT col_#{options[:imp_clid]} FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', ''))")
      idsclis = ["'not_found'"]
      found_clis.each { |id| idsclis << id["col_#{options[:imp_clid]}"].to_s }
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET not_found_in_db = 1 where col_#{options[:imp_clid]}  not in (#{idsclis.compact.join(',')})")
    end


    # set flag on bad dst | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 3 where replace(replace(col_#{options[:imp_dst]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0  and f_error = 0")
    # set flag on bad calldate | code : 4
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 4 where replace(replace(col_#{options[:imp_calldate]}, '\\r', ''), '
', '') REGEXP '^[0-9 :,./-]+$' = 0 and f_error = 0 ")
    # set flag on bad billsec | code : 5
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 5 where replace(replace(col_#{options[:imp_billsec]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and f_error = 0")
    hangup_cause = options[:imp_hangup_cause]
    if hangup_cause.to_i > -1
      # set flag on bad hangupcause code | code : 14
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 14 where replace(replace(col_#{hangup_cause}, '\\r', ''), '
      ', '') REGEXP '^[0-9]+$' = 0 and f_error = 0")
    end
    if  options[:imp_provider_id].to_i > -1
      # set flag on bad Provider ID | code : 6
      prov_id =
          ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 6 where replace(replace(col_#{options[:imp_provider_id]}, '\\r', ''), '
', '') NOT IN (SELECT devices.id FROM devices where tp_active = 1) and f_error = 0")
    end

    answer_time_col = options[:imp_answer_time]
    end_time_col = options[:imp_end_time]
    date_format = options[:date_format]
    nice_date_format = date_format.gsub('%M', '%i')
    answer_time_presents = answer_time_col && answer_time_col.to_i > 0
    end_time_presents = end_time_col && end_time_col.to_i > 0

    # set flag on bad answer_time | code : 7
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 7 where replace(replace(col_#{options[:imp_answer_time]}, '\\r', ''), '
', '') REGEXP '^[0-9 :,./-]+$' = 0 and f_error = 0 ") if answer_time_presents
    # set flag on bad end_time | code : 8
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 8 where replace(replace(col_#{options[:imp_end_time]}, '\\r', ''), '
', '') REGEXP '^[0-9 :,./-]+$' = 0 and f_error = 0 ") if end_time_presents
    # set flag on bad start time format | code : 11
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 11 where replace(replace(col_#{options[:imp_answer_time]}, '\\r', ''), '
', '') != DATE_FORMAT(replace(replace(col_#{options[:imp_answer_time]}, '\r', ''), '', ''), '#{nice_date_format}') and f_error = 0 ") if answer_time_presents
    # set flag on bad end_time bformat  | code : 12
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 12 where replace(replace(col_#{options[:imp_end_time]}, '\\r', ''), '
', '') != DATE_FORMAT(replace(replace(col_#{options[:imp_end_time]}, '\r', ''), '', ''), '#{nice_date_format}') and f_error = 0 ") if end_time_presents
    # set flag on bad calldate format  | code : 13
    # If we use cdr_import_template, then we use cdr_import_template.date_format
    # If we use simple cdr import, then we use conflines.Date_format
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 13 where replace(replace(col_#{options[:imp_calldate]}, '\\r', ''), '
', '') != DATE_FORMAT(replace(replace(col_#{options[:imp_calldate]}, '\r', ''), '', ''), '#{nice_date_format}') and f_error = 0 ") if options[:template_use]

    #set flag on bad clis and count them
    unless options[:import_user]
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 1 where replace(replace(col_#{options[:imp_clid]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and not_found_in_db = 1")
    end
    cond = options[:import_user] ? " AND user_id = #{options[:import_user]} " : '' #" calls.cli "
    ActiveRecord::Base.connection.execute("UPDATE #{name} JOIN calls ON (calls.calldate = timestamp(replace(col_#{options[:imp_calldate]}, '\\r', '')) ) SET f_error = 1, nice_error = 2 WHERE dst = replace(col_#{options[:imp_dst]}, '\\r', '') and billsec = replace(col_#{options[:imp_billsec]}, '\\r', '')  #{cond} and f_error = 0")

    arr[:cdr_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    arr[:bad_cdrs] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    arr[:bad_clis] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    if options[:step] and options[:step] == 8
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name}  WHERE nice_error != 1 and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.where(device_id: -1).all.size.to_i
    else
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} LEFT JOIN callerids on (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) WHERE nice_error != 1 and callerids.id is null and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.where(device_id: -1).all.size.to_i + arr[:new_clis_to_create].to_i
    end

    arr[:existing_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where not_found_in_db = 0 and f_error = 0").to_i
    arr[:new_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} where not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
    arr[:cdrs_to_insert] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i

    arr
  end

  def Call.insert_cdrs_from_csv(name, options)
    provider = Device.termination_points.where(["id = ?", options[:import_provider]]).first
    if options[:import_user]
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN devices ON (devices.id = #{options[:import_device]}) WHERE f_error = 0 and do_not_import = 0")
    else
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) JOIN devices ON (callerids.device_id = devices.id) WHERE f_error = 0 and do_not_import = 0")
    end

    date_format = options[:date_format]

    imported_cdrs = 0
    res.each do |result|
      billsec = result["col_#{options[:imp_billsec]}"].to_i
      imp_dst = CsvImportDb.clean_value(result["col_#{options[:imp_dst]}"].to_s).gsub(/[^0-9]/, "")
      calldate = options[:template_use] ?
          DateTime.strptime(result["col_#{options[:imp_calldate]}"].to_s, "#{date_format}") : result["col_#{options[:imp_calldate]}"]
      call = Call.new(billsec: billsec, real_billsec: billsec, dst: imp_dst,
                      calldate: calldate, localized_dst: imp_dst)


      # A: Hack for the mess that gets created with speedup.sql
      call.lastapp = '' if call.attributes.has_key? 'lastapp'
      call.lastdata = '' if call.attributes.has_key? 'lastdata'
      call.uniqueid = '' if call.attributes.has_key? 'uniqueid'
      call.channel = '' if call.attributes.has_key? 'channel'
      call.dcontext = '' if call.attributes.has_key? 'dcontext'
      call.dstchannel = '' if call.attributes.has_key? 'dstchannel'
      call.userfield = '' if call.attributes.has_key? 'userfield'
      options_imp_duration = options[:imp_duration]
      duration = CsvImportDb.clean_value(result["col_#{options_imp_duration}"]).to_i
      duration = billsec if duration == 0 or options_imp_duration == -1
      disposition = ""
      options_imp_disposition = options[:imp_disposition]
      disposition = CsvImportDb.clean_value result["col_#{options_imp_disposition}"] if options_imp_disposition > -1
      billsec_present = billsec > 0
      if disposition.length == 0
        disposition = 'ANSWERED' if billsec_present
        disposition = 'FAILED' if billsec == 0
      end

      options_clid = options[:imp_clid]
      options_src_number = options[:imp_src_number]
      call.clid = CsvImportDb.clean_value result["col_#{options_clid}"] if options_clid > -1
      call.clid = '' if call.clid.to_s.length == 0

      call.src = CsvImportDb.clean_value(result["col_#{options_src_number}"]).gsub(/[^0-9]/, "") if options_src_number > -1
      call.src = call.clid.to_s if call.src.to_s.length == 0 && options_clid > -1
      hangup_cause = options[:imp_hangup_cause].to_i
      if hangup_cause > -1
        hangupcause_code = CsvImportDb.clean_value(result["col_#{hangup_cause}"]).to_i
      elsif billsec_present
        hangupcause_code = 16
      else
        hangupcause_code = 0
      end
      call.hangupcause = hangupcause_code
      call.duration = duration
      call.real_duration = duration
      call.disposition = disposition
      #call.accountcode = result['dev_id']
      call.src_device_id = result['dev_id']
      call.user_id = result['user_id']
      options_imp_provider_id = options[:imp_provider_id]
      call.dst_device_id = options_imp_provider_id.to_i > -1 ? CsvImportDb.clean_value(result["col_#{options_imp_provider_id}"]).gsub(/[^0-9]/, "") : provider.id
      call.provider_id = Device.where(id: call.dst_device_id).first.try(:user_id)
      call.dst_user_id = call.provider_id
      imp_answer_time = options[:imp_answer_time]
      imp_end_time = options[:imp_end_time]
      imp_cost = options[:imp_cost]
      call.answer_time = DateTime.strptime(result["col_#{imp_answer_time}"].to_s, "#{date_format}") if imp_answer_time && imp_answer_time.to_i > -1
      call.end_time = DateTime.strptime(result["col_#{imp_end_time}"].to_s, "#{date_format}") if imp_end_time && imp_end_time.to_i > -1


      user = User.find(call.user_id)
      #call.reseller_id = user.owner_id
      call = call.count_cdr2call_details(0, user) if call.valid?
      call.user_price = CsvImportDb.clean_value result["col_#{imp_cost}"].to_d if imp_cost && imp_cost.to_i > -1
      if call.save
        user.balance -= call.user_price.to_d
        user.save
        imported_cdrs += 1
      end
    end

    errors = ActiveRecord::Base.connection.select_all("SELECT * FROM #{name} where f_error = 1")
    return imported_cdrs, errors
  end


  # counts details for the call imported from csv
  #
  # Upgrade: selfcost_tariff_id and user_id can be Tariff or User objects so
  # not to perform find and not to stress database.
  #

  def count_cdr2call_details(selfcost_tariff_id, user_id, user_test_tariff_id = 0)
    @tariffs_cache ||= {}

    if user_id.class == User
      user = user_id
      user_id = user.id
    else
      user = User.includes(:tariff).where("users.id = #{user_id}").first
    end
    #logger.info user.to_yaml

    # testing tariff
    if user_test_tariff_id > 0
      tariff = Tariff.where(id: user_test_tariff_id).first
      CsvImportDb.clean_value "Using testing tariff with id: #{user_test_tariff_id}"
    else
      tariff = device.try(:op_tariff)
    end

    if tariff
      # we will use calls.localized_dst instead of calls.dst, so that we won't need to cut device tech prefix
      # (http://trac.kolmisoft.com/trac/ticket/10200#comment:9)
      dst = CsvImportDb.clean_value self.localized_dst.to_s #.gsub(/[^0-9]/, "")
      device_id = src_device_id
      time = self.calldate.strftime('%H:%M:%S')
      calldatetime = self.calldate.strftime('%Y-%m-%d %H:%M:%S')

      #my_debug ""

      # get daytype
      day = self.calldate.to_s(:db)
      sql = "SELECT (SELECT IF((SELECT daytype FROM days WHERE date = '#{day}') IS NULL, (SELECT IF(WEEKDAY('#{day}') = 5 OR WEEKDAY('#{day}') = 6, 'FD', 'WD')), (SELECT daytype FROM days WHERE date = '#{day}')))   as 'dt' FROM devices  WHERE devices.id = #{device_id} LIMIT 1;"
      res = ActiveRecord::Base.connection.select_one(sql)
      if res and res['device_id'].blank?
        daytype = res['dt']
        #V ticket #8547
        #my_debug sql
        #my_debug "calldate: #{day}, time: #{time}, daytype: #{daytype}, loc_add: #{loc_add}, loc_cut: #{loc_cut}, loc_add: #{loc_add}, src: #{call.src}, dst: #{dst}, tariff_id: #{tariff_id}, self_tariff_id: #{selfcost_tariff_id}"

        # initial values

        price = 0
        max_rate = 0
        user_exchange_rate = 1
        temp_prefix = ''
        user_billsec = 0

        s_prefix = ''
        s_rate = 0
        s_increment = 1
        s_min_time = 0
        s_conn_fee = 0

        s_billsec = 0
        s_price = 0

        origination_point = Device.origination_points.where(id: dst_device_id).first
        tariff_id = origination_point.try(:op_tariff).try(:id)


        #data for selfcost
        dst_array = []
        dst.length.times { |ind| dst_array << dst[0, ind + 1] }
        if dst_array.size > 0
          sql =
              "SELECT A.prefix, ratedetails.rate,   ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee "+
                  "FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' ) AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT rates.* FROM  rates " +
                  "WHERE rates.prefix IN ('#{dst_array.join("', '")}') ORDER BY LENGTH(rates.prefix) DESC) " +
                  "as A ON (A.id = rates.id) WHERE rates.tariff_id = #{tariff_id.to_i} AND (rates.effective_from <= '#{calldatetime}' OR rates.effective_from IS NULL) ORDER BY LENGTH(A.prefix) DESC, rates.effective_from DESC LIMIT 1;"
        end

        #my_debug sql
        res = ActiveRecord::Base.connection.select_one(sql)

        if res
          s_prefix = res['prefix']
          s_rate = res['rate'].to_d
          s_increment = res['increment_s'].to_i
          s_min_time = res['min_time'].to_i
          s_conn_fee = res['connection_fee'].to_d
        end

        s_increment = 1 if s_increment == 0
        if (self.billsec % s_increment == 0)
          s_billsec = (self.billsec / s_increment).floor * s_increment
        else
          s_billsec = ((self.billsec / s_increment).floor + 1) * s_increment
        end
        s_billsec = s_min_time if s_billsec < s_min_time
        s_price = (s_rate * s_billsec) / 60 + s_conn_fee

        #   MorLog.my_debug "PROVIDER's: prefix: #{s_prefix}, rate: #{s_rate}, increment: #{s_increment}, min_time: #{s_min_time}, conn_fee: #{s_conn_fee}, billsec: #{s_billsec}, price: #{s_price}, exchange_rate = #{prov_exchange_rate}"

        #====================== data for USER ==============
        price, max_rate, user_exchange_rate, temp_prefix, user_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, user, calldatetime)
        MorLog.my_debug "USER: call_id: #{self.id}, tariff: #{tariff.id} user_price: #{price}, max_rate: #{max_rate}, exchange_rate: #{user_exchange_rate}, tmp_prefix: #{temp_prefix}, user_billsec: #{user_billsec}"

        #====================== data for RESELLER =============#


        # ========= Calculation ===========


        #new
        self.user_rate = max_rate / user_exchange_rate
        self.user_billsec = user_billsec
        self.user_price = 0

        #call.dst = orig_dst
        #self.dst = dst

        #call.prefix = res[0]["prefix"] if res[0]

        if temp_prefix.to_s.length > s_prefix.to_s.length
          self.prefix = temp_prefix
        else
          self.prefix = s_prefix
        end

        #need to find prefix for error fixing when no prefix is in calls table - this should not happen anyways, so maybe no fix is neccesary?

        if self.disposition == 'ANSWERED'
          #        call.prov_price = s_price
          #        call.price = price

          #new
          self.user_price = price / user_exchange_rate
        end

      else
        MorLog.my_debug "#{Time.now.to_s(:db)}  SQL not found--------------------------------------------"
        MorLog.my_debug sql
      end
    else
      MorLog.my_debug('Origination Point has no tariff assigned, DB integrity should be checked.')
    end
    self
  end


  def count_call_rating_details_for_user(tariff, time, daytype, dst, user, calldatetime = nil)
    @count_call_rating_details_for_user_exchange_rate_cache ||= {}

    #======================= user wholesale ===============

    sql = "SELECT A.prefix,
                  ratedetails.rate,
                  ratedetails.increment_s,
                  ratedetails.min_time,
                  ratedetails.connection_fee as 'cf'
           FROM rates
           JOIN ratedetails ON (ratedetails.rate_id = rates.id
                                AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '')
                                AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time)
           JOIN (SELECT rates.*
                 FROM rates
                 WHERE rates.prefix=SUBSTRING('#{dst}', 1, LENGTH(rates.prefix))
                ) AS A ON (A.id = rates.id)
           WHERE rates.tariff_id = #{tariff.id}
                 AND (rates.effective_from <= '#{calldatetime}' OR rates.effective_from IS NULL)
           ORDER BY LENGTH(rates.prefix) DESC, rates.effective_from DESC
           LIMIT 1;"


    #my_debug sql

    res = ActiveRecord::Base.connection.select_one(sql)

    uw_prefix = ''
    uw_rate = 0
    uw_increment = 1
    uw_min_time = 0
    uw_conn_fee = 0

    if res
      uw_prefix = res['prefix']
      uw_rate = res['rate'].to_d
      uw_increment = res['increment_s'].to_i
      uw_min_time = res['min_time'].to_i
      uw_conn_fee = res['cf'].to_d
    end

    uw_billsec = 0
    uw_price = 0

    uw_increment = 1 if uw_increment == 0

    if (self.billsec % uw_increment == 0)
      uw_billsec = (self.billsec / uw_increment).floor * uw_increment
    else
      uw_billsec = ((self.billsec / uw_increment).floor + 1) * uw_increment
    end
    uw_billsec = uw_min_time if uw_billsec < uw_min_time

    #my_debug (call.billsec.to_d / uw_increment)
    #my_debug (call.billsec.to_d / uw_increment).floor
    #my_debug (call.billsec / uw_increment).floor * uw_increment
    #my_debug uw_billsec

    uw_price = (uw_rate * uw_billsec) / 60 + uw_conn_fee

    price = uw_price
    max_rate = uw_rate
    user_exchange_rate = @count_call_rating_details_for_user_exchange_rate_cache["te_#{tariff.id}".to_sym] ||= tariff.exchange_rate
    temp_prefix = uw_prefix
    user_billsec = uw_billsec

    return price, max_rate, user_exchange_rate, temp_prefix, user_billsec
  end

  def toggle_processed
    self.processed = processed == 0 ? 1 : 0
    save
  end

  def self.find_totals_for_profit(conditions)
    select_total = ["COUNT(*) AS 'total_calls'"]
    select_total << "SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'answered_calls'"
    select_total << "SUM(IF(calls.disposition = 'BUSY', 1, 0)) AS 'busy_calls'"
    select_total << "SUM(IF(calls.disposition = 'NO ANSWER', 1, 0)) AS 'no_answer_calls'"
    select_total << "SUM(IF(calls.disposition = 'FAILED', 1, 0)) AS 'failed_calls'"

    Call.select(select_total.join(", ")).where(conditions.join(" AND ")).joins(SqlExport.left_join_reseler_providers_to_calls_sql)
  end

  def self.find_totals_for_profit_prices(select, conditions)
    Call.select(select.join(', ')).where((conditions + ["disposition = 'ANSWERED'"]).join(' AND '))
        .joins("LEFT JOIN users ON (users.id = calls.user_id) #{SqlExport.left_join_reseler_providers_to_calls_sql}").first
  end

  def termination_device
    Device.where(id: dst_device_id).first
  end

  def user_disposition
    if hangupcause.to_s == '312'
      'CANCEL'
    else
      User.current.show_hangupcause.to_i == 1 ? "#{disposition} (#{hangupcause})" : disposition.to_s
    end
  end

  def call_log_data
    {
        uniqueid: uniqueid,
        caller_id: clid,
        destination: dst,
        device_id: src_device_id,
        originator_ip: originator_ip
    }
  end

  def self.column_exists?(column)
    ActiveRecord::Base.connection.column_exists?(:calls, column.to_sym)
  end

  def calls_list_codecs_status(v3_codec_columns = false)
    if v3_codec_columns
      oc = try(:op_codec).to_s
      tc = try(:tp_codec).to_s
    else
      oc = try(:originator_codec).to_s
      tc = try(:terminator_codec).to_s
    end

    if oc.present? || tc.present?
      if oc == tc || oc.blank? || tc.blank?
        1
      else
        2
      end
    else
      0
    end
  end

  def get_tp_codec(v3_codec_columns = false)
    codec = v3_codec_columns ? try(:tp_codec).to_s : try(:terminator_codec).to_s.strip
    codec = 'unknown' if [1, 3, 4, 8, 9, 18, 97, 98].exclude?(codec.to_i) && v3_codec_columns
    codec
  end

  def get_op_codec(v3_codec_columns = false)
    codec = v3_codec_columns ? try(:op_codec).to_s : try(:originator_codec).to_s.strip
    codec = 'unknown' if [1, 3, 4, 8, 9, 18, 97, 98].exclude?(codec.to_i) && v3_codec_columns
    codec
  end

  def one_codec_is_unknown?(v3_codec_columns = false)
    tp_codec = get_tp_codec(v3_codec_columns)
    op_codec = get_op_codec(v3_codec_columns)
    tp_codec != op_codec && (tp_codec == 'unknown' || op_codec == 'unknown')
  end

  def calls_list_codecs_tooltip(v3_codec_columns = false)
    tooltip = ''
    tooltip << "<b>#{_('Transcoded_Call')}</b><br>" if calls_list_codecs_status(v3_codec_columns) == 2 && !one_codec_is_unknown?(v3_codec_columns)
    if v3_codec_columns
      tooltip << "#{_('Originator_Codec')}: #{nice_op_codec}<br>#{_('Terminator_Codec')}: #{nice_tp_codec}"
    else
      tooltip << "#{_('Originator_Codec')}: #{try(:originator_codec)}<br>#{_('Terminator_Codec')}: #{try(:terminator_codec)}"
    end
  end

  def originator_pdd
    sum_pdd = 0

    if ActiveRecord::Base.connection.select_value("SELECT count(*) from information_schema.partitions WHERE TABLE_SCHEMA='m2' AND TABLE_NAME = 'calls' AND PARTITION_NAME = 'd#{calldate.strftime('%Y%m%d')}';").to_i > 0
      calls = ActiveRecord::Base.connection.select_all("SELECT SUM(pdd) AS sum, COUNT(*) AS count FROM calls PARTITION (d#{calldate.strftime('%Y%m%d')})  WHERE (uniqueid = '#{uniqueid}') LIMIT 1;").first
    else
      calls = Call.select('SUM(pdd) AS sum, COUNT(*) AS count').where("uniqueid = '#{uniqueid}'").first
    end

    if calls.present?
      sum_pdd = calls.try(:[], 'sum')
      count = calls.try(:[], 'count')
    end

    return 0 if sum_pdd.blank? || sum_pdd <= 0
    sum_pdd + (count * 0.001)
  end

  def disposition
    if hangupcause.to_s == '312'
      'CANCEL'
    else
      read_attribute(:disposition)
    end
  end

  def self.get_v3_columns
    Rails.cache.fetch(:calls_v3_columns, expires_in: 10.minutes) do
      new_columns = %w[
        rpid tp_src tp_dst dc op_dc tp_dc routing_attempt
        op_signaling_ip tp_signaling_ip op_media_ip tp_media_ip op_codec
        tp_codec mos mos_packetloss mos_jitter mos_roundtrip
      ]
      # hidden columns: op_user_agent_id, tp_user_agent_id

      # filter out only existing columns
      new_columns.select { |col| column_exists?(col) }
    end
  end

  def self.v3_swap
    {
      originator_codec: new_column_if_present('calls.originator_codec', 'op_codec', &method(:codec_select_sql)),
      terminator_codec: new_column_if_present('calls.terminator_codec', 'tp_codec', &method(:codec_select_sql)),
      originator_ip: new_column_if_present('calls.originator_ip', 'op_signaling_ip', &method(:int_to_ip_sql)),
      terminator_ip: new_column_if_present('calls.terminator_ip', 'tp_signaling_ip', &method(:int_to_ip_sql))
    }
  end

  def self.new_column_if_present(old, new, &transform_f)
    return old if !get_v3_columns.include?(new) || Confline.get_value('M4_Functionality').to_i != 1
    return transform_f.call(new) if transform_f.present?
    new
  end

  def self.int_to_ip_sql(ip)
    "IF(calls.#{ip} = 0, 0, INET_NTOA(calls.#{ip}))"
  end

  def self.codec_select_sql(codec_column)
    "CASE" \
    "   WHEN calls.#{codec_column} = 1 THEN 'G.711 u-law'" \
    "   WHEN calls.#{codec_column} = 3 THEN 'GSM'" \
    "   WHEN calls.#{codec_column} = 4 THEN 'G.723.1'" \
    "   WHEN calls.#{codec_column} = 8 THEN 'G.711 A-law'" \
    "   WHEN calls.#{codec_column} = 9 THEN 'G.722'" \
    "   WHEN calls.#{codec_column} = 18 THEN 'G.729'" \
    "   WHEN calls.#{codec_column} = 97 THEN 'OPUS'" \
    "   WHEN calls.#{codec_column} = 98 THEN 'Speex'" \
    "   ELSE 'unknown' "\
    "END"
  end

  def self.convert_int_to_ip(ip)
    return '' if ip.to_i == 0
    IPAddr.new(ip, Socket::AF_INET).to_s
  end

  def tp_signaling_ip
    Call.convert_int_to_ip(self.read_attribute(:tp_signaling_ip).to_i)
  end

  def op_signaling_ip
    Call.convert_int_to_ip(self.read_attribute(:op_signaling_ip).to_i)
  end

  def op_media_ip
    Call.convert_int_to_ip(self.read_attribute(:op_media_ip).to_i)
  end

  def tp_media_ip
    Call.convert_int_to_ip(self.read_attribute(:tp_media_ip).to_i)
  end

  def nice_tp_codec
    Call.convert_v3_codec[try(:tp_codec).to_s]
  end

  def nice_op_codec
    Call.convert_v3_codec[try(:op_codec).to_s]
  end

  def self.convert_v3_codec
    codec_int_value_map = Hash.new('unknown')
    codec_int_value_map.merge!(
      '1' => 'G.711 u-law',
      '3' => 'GSM',
      '4' => 'G.723.1',
      '8' => 'G.711 A-law',
      '9' => 'G.722',
      '18' => 'G.729',
      '97' => 'OPUS',
      '98' => 'Speex'
    )
  end

  private

  def Call.last_calls_parse_params(options = {})
    current_user = options[:current_user]
    show_all_calls = current_user.try(:usertype).to_s != 'user'

    if show_all_calls
      jn = ['LEFT JOIN devices AS u_src_device ON (u_src_device.id = calls.src_device_id)',
            'LEFT JOIN users ON (u_src_device.user_id = users.id)']
    else
      jn = ['LEFT JOIN users ON (calls.user_id = users.id)']
    end

    cond = ['(calls.calldate BETWEEN ? AND ?)']
    var = [options[:from], options[:till]]
    destination = options[:destination]
    destination_group_id = options[:destination_group_id]

    if options[:call_type] != 'all'
      if %w[answered failed].include?(options[:call_type].to_s)
        cond << Call.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << Call.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else

        if options[:call_type] == 'no answer'
          cond << 'calls.hangupcause != ?'
          var << '312'
        end

        if options[:call_type] == 'Cancel'
          cond << 'calls.hangupcause = ?'
          var << '312'
        else
          cond << 'calls.disposition = ?'
          var << options[:call_type]
        end
      end
    end

    if options[:hgc]
      cond << 'calls.hangupcause = ?'
      var << options[:hgc].code
    end

    unless destination.blank?
      cond << 'localized_dst like ?'
      var << "#{destination}"
    end

    if options[:s_country].present? || destination_group_id.present?
      jn << 'LEFT JOIN destinations ON (calls.prefix = destinations.prefix)'
    end

    if options[:s_country] and !options[:s_country].blank?
      cond << 'destinations.direction_code = ? '; var << options[:s_country]
    end

    if options[:origination_point].present? && options[:origination_point].id
      cond << '(calls.src_device_id = ?)'
      var += [options[:origination_point].id]
    end

    if current_user.show_only_assigned_users?
      assigned_users = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
      cond << '(calls.user_id IN (?) OR u_src_device.user_id IN (?))'
      var += ([assigned_users] * 2)
    end

    if options[:user]
      user_id = options[:user].id
      if current_user.is_user?
        cond << '(calls.user_id = ? OR calls.provider_id = ?)'
        var += ([user_id] * 2)
      else
        jn << 'LEFT JOIN devices AS dst_device ON (dst_device.id = calls.dst_device_id)'
        if show_all_calls
          cond << '(calls.user_id = ? OR u_src_device.user_id = ?)'
          var += ([user_id] * 2)
        else
          cond << '(calls.user_id = ?)'
          var += [user_id]
        end
      end
    end

    if options[:termination_point]
      cond << 'calls.dst_device_id = ?'
      var += [options[:termination_point].id]
    end

    if options[:tp_user]
      cond << '(calls.dst_user_id = ?)'
      var += [options[:tp_user].id]
    end

    if options[:source] and not options[:source].blank?
      cond << '(calls.src LIKE ? OR calls.clid LIKE ?)'
      2.times { var << options[:source] }
    end

    if options[:s_billsec].present?
      cond << "#{Call.nice_billsec_condition} = ?"
      var += [options[:s_billsec]]
    end

    if options[:s_duration].present?
      cond << 'calls.duration = ?'
      var += [options[:s_duration]]
    end

    if options[:s_server].present?
      cond << 'calls.server_id = ?'
      var << options[:s_server]
    end

    if destination_group_id.present?
      jn << 'LEFT JOIN destinationgroups ON (destinationgroups.id = destinations.destinationgroup_id)'
      cond << 'destinationgroups.id = ? '; var << destination_group_id
    end

    if options[:uniqueid].present?
      cond << 'calls.uniqueid LIKE ?'
      var << (options[:uniqueid].size < 32 ? (options[:uniqueid].gsub('%', '') + '%') : options[:uniqueid][0...32])
    end

    return cond, var, jn
  end

  def self.last_calls_csv_headers
    {
        'calldate2' => _('Date'),
        'uniqueid' => _('UniqueID'),
        'src' => _('Source'),
        'clid' => "#{_('Called_from')} (#{_('Source')})",
        'dst' => "#{_('Called_to')} (#{_('Destination')})",
        'prefix' => _('Prefix'),
        'destination' => _('Destination'),
        'nice_billsec' => _('Billsec'),
        'duration' => _('Duration'),
        'dispod' => _('hangup_cause'),
        'provider' => _('Provider'),
        'provider_rate' => _('Provider_rate'),
        'provider_price' => _('Provider_price'),
        'user' => _('User'),
        'user_rate' => _('User_rate'),
        'user_price' => _('User_price'),
        'nice_src_device' => _('Device'),
        'answer_time' => _('Answer_time'),
        'end_time' => _('End_Time'),
        'pdd' => _('PDD'),
        'terminated_by' => _('Terminated_by')
    }
  end

  def self.user_is_user_and_hgc_not_equal_to_sixteen
    ((User.current.usertype.to_s == 'user') &&
        (Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1))
  end

  def self.nice_user(user)
    if user
      nice_name = "#{user.first_name} #{user.last_name}"
      nice_name = user.username.to_s if nice_name.length < 2
      return nice_name
    end
    return ''
  end
end
