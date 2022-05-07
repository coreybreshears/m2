# Old Call model
class OldCall < ActiveRecord::Base
  include SqlExport
  include CsvImportDb
  belongs_to :user
  belongs_to :device, foreign_key: 'accountcode'
  belongs_to :server

  validates_presence_of :calldate, message: _('Calldate_cannot_be_blank')

  attr_accessible :calldate

  def self.table_name
    'calls_old'
  end

  attr_protected

  def nice_billsec
    billsec = self.billsec
    billsec = self.real_billsec.ceil if billsec == 0 && self.real_billsec > 0
    billsec
  end

  def self.nice_billsec_condition
    if User.current.is_user? && Confline.get_value('Invoice_user_billsec_show', User.current.owner.id).to_i == 1
      'CEIL(user_billsec)'
    else
      'IF((billsec = 0 AND real_billsec > 1), CEIL(real_billsec), billsec)'
    end
  end

  def self.nice_billsec_sql
    nice_billsec_condition << " as 'nice_billsec'"
  end

  def self.nice_answered_cond_sql(search_not = true)
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      if search_not
        " (calls_old.disposition='ANSWERED' AND calls_old.hangupcause='16') "
      else
        " (calls_old.disposition='ANSWERED' OR (calls_old.disposition='ANSWERED' AND calls_old.hangupcause!='16') ) "
      end
    else
      " calls_old.disposition='ANSWERED' "
    end
  end

  def self.nice_failed_cond_sql
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " (calls_old.disposition='FAILED' OR (calls_old.disposition='ANSWERED' and calls_old.hangupcause!='16')) "
    else
      " calls_old.disposition='FAILED' "
    end
  end

  def self.nice_disposition
    if User.current.usertype.to_s == 'user' and Confline.get_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users').to_i == 1
      " IF(calls_old.disposition  = 'ANSWERED',IF((calls_old.disposition='ANSWERED' AND calls_old.hangupcause='16'), 'ANSWERED', 'FAILED'),disposition)"
    else
      " IF(calls_old.hangupcause = '312', 'CANCEL', calls_old.disposition)"
    end
  end


  def reseller
    res = nil
    # res = User.where("id = #{self.reseller_id}").first if self.reseller_id.to_i > 0
    res
  end

  def destinations
    de = nil
    de = Destination.find(self.prefix) if self.prefix and self.prefix.to_i > 0
    de
  end

  def OldCall::total_calls_by_direction_and_disposition(start_date, end_date, users = [])
    # parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    # returns - array of hashs. total call count for incoming and outgoing, answered, not answered,
    #  busy and failed calls grouped by disposition and direction originated or received by
    #  specified users. if no users were specified - for all users
    OldCall.total_calls_by([], {outgoing: true, incoming: true}, start_date, end_date, {direction: true, disposition: true}, users)
  end

  def OldCall::answered_calls_day_by_day(start_date, end_date, users = [])
    # parameters:
    #  start_date - min date for filtering out calls, expected to be date/datetime
    #    instance or date/datetime as string
    #  end_date - max date for filtering out calls, expected to be date instance or date as
    #    string.
    #  users - array of user id's
    # returns answered call count, total billsec, and average billsec for everyday in datetime
    # interval for specified users or if no user is specified - for all users
    day_by_day_stats = OldCall.total_calls_by(['ANSWERED'], {outgoing: true, incoming: true}, start_date, end_date, {date: true}, users)

    start_date = (start_date.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db)
    end_date = (end_date.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db)

    start_date = Date.strptime(start_date, '%Y-%m-%d').to_date
    end_date = Date.strptime(end_date, '%Y-%m-%d').to_date
    date = []
    calls = []
    billsec = []
    avg_billsec = []
    index = 0
    i = 0
    start_date.upto(end_date) do |day|
      day_stats = day_by_day_stats[i]
      if day_stats and day_stats['calldate'] and day.to_date == day_stats['calldate'].to_date
        date[index] = day_stats['calldate'].strftime('%Y-%m-%d')
        calls[index] = day_stats['total_calls'].to_i
        billsec[index] = day_stats['total_billsec'].to_i
        avg_billsec[index] = day_stats['average_billsec'].to_i
        i += 1
      else
        date[index] = day
        calls[index] = 0
        billsec[index] = 0
        avg_billsec[index] = 0
      end
      index += 1
    end

    calls << day_by_day_stats.last['total_calls']
    billsec << day_by_day_stats.last['total_billsec']
    avg_billsec << day_by_day_stats.last['average_billsec']

    return date, calls, billsec, avg_billsec
  end

  def OldCall::total_calls_by(disposition, direction, start_date, end_date, group_options = [], users = [])
    # parameters:
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
    # returns:
    #  whatever Calls.find returns, and the last element in array will be totals/averages of all fetched values
    select = []
    select << "COUNT(*) AS 'total_calls'"
    select << "SUM(calls_old.billsec) AS 'total_billsec'"
    select << "AVG(calls_old.billsec) AS 'average_billsec'"

    condition = []
    condition << "calls_old.calldate BETWEEN '#{start_date.to_s}' AND '#{end_date.to_s}'"
    # if disposition is not specified or it is all 4 types(answered, failed, busy, no answer),
    # there is no need to filter it
    condition << "calls_old.disposition IN ('#{disposition.join(', ')}')" if !disposition.empty? and disposition.length < 4

    join = []
    if users.empty?
      if direction.include?(:incoming) and direction.include?(:outgoing)
        condition << 'calls_old.user_id IS NOT NULL'
      else
        condition << 'calls_old.user_id != -1 AND calls_old.user_id IS NOT NULL' if direction.include?(:outgoing)
        condition << 'calls_old.user_id = -1' if direction.include?(:incoming)
      end
    else
      # no mater weather we are allready checking devices for user_id, call.user_id might still be NULL, else we would select
      # to many failed calls
      condition << 'calls_old.user_id IS NOT NULL;'
      if direction.include?(:outgoing) and direction.include?(:incoming)
        condition << "(dst_devices.user_id IN (#{users.join(', ')}) OR src_devices.user_id IN (#{users.join(', ')}))"
      end
      if direction.include?(:incoming)
        join << 'LEFT JOIN devices dst_devices ON calls_old.dst_device_id = dst_devices.id'
        condition << "dst_devices.user_id IN (#{users.join(', ')}" if !direction.include?(:outgoing)
      end
      if direction.include?(:outgoing)
        join << 'LEFT JOIN devices src_devices ON calls_old.src_device_id = src_devices.id'
        condition << "src_devices.user_id IN (#{users.join(', ')})" if !direction.include?(:incoming)
      end
    end

    # dont group at all, group by date, direction and/or disposition
    # accordingly, we should select those fields from table
    group = []
    if group_options[:date]
      select << "(calls_old.calldate) AS 'calldate'"
      if Time.zone.now().utc_offset.to_i == 0
        group << 'FLOOR((UNIX_TIMESTAMP(calls_old.calldate)) / 86400)' # grouping by intervals of exact 24 hours
      else
        group << 'year(calldate), month(calldate), (day(calldate) + FLOOR(HOUR(calldate) / 24)) ORDER BY calldate ASC'
      end
    end
    if group_options[:disposition]
      select << 'calls_old.disposition'
      group << 'calls_old.disposition' if group_options[:disposition]
    end

    if group_options[:direction]
      if users.empty?
        select << "IF(calls_old.user_id  = -1, 'incoming', 'outgoing') AS 'direction'"
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

    if group_options[:date]
      statistics = OldCall.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
      statistics.each do |st|
        st.calldate = (st.calldate.to_time + Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_s(:db) if !st.calldate.blank?
      end
    else
      statistics = OldCall.select(select.join(', ')).joins(join.join(' ')).where(condition.join(' AND ')).group(group.join(', ')).all
    end

    # calculating total billsec, total calls and average billsec
    total_calls = 0
    total_billsec = 0
    statistics.each do |stats|
      total_calls += stats['total_calls'].to_i
      total_billsec += stats['total_billsec'].to_i
    end
    average_billsec = total_calls == 0 ? 0 : total_billsec/total_calls

    # return array of hashs, bet we should definetly return some sort of Statistics class
    statistics << {'total_calls' => total_calls, 'total_billsec' => total_billsec, 'average_billsec' => average_billsec}
  end

  def OldCall.calls_order_by(params, options)
    case options[:order_by].to_s.strip
      when 'time' then
        order_by = 'calls_old.calldate'
      when 'src' then
        order_by = 'calls_old.src'
      when 'dst' then
        order_by = 'calls_old.dst'
      when 'nice_billsec' then
        order_by = 'nice_billsec'
      when 'hgc' then
        order_by = 'calls_old.hangupcause'
      when 'server' then
        order_by = 'calls_old.server_id'
      when 'p_name' then
        order_by = 'providers.name'
      when 'p_rate' then
        order_by = 'calls_old.provider_rate'
      when 'p_price' then
        order_by = 'calls_old.provider_price'
      when 'reseller' then
        order_by = 'nice_reseller'
      when 'user' then
        order_by = 'nice_user'
      when 'u_rate' then
        order_by = 'calls_old.user_rate'
      when 'u_price' then
        order_by = 'calls_old.user_price'
      when 'prefix' then
        order_by = 'calls_old.prefix'
      when 'direction' then
        order_by = 'destinations.direction_code'
      when 'destination' then
        order_by = 'destinations.name'
      when 'duration' then
        order_by = 'duration'
      when 'answered_calls' then
        order_by = 'answered_call'
      when 'total_calls' then
        order_by = 'total_calls'
      when 'asr' then
        order_by = 'asr'
      when 'acd' then
        order_by = 'acd'
      when 'markup' then
        order_by = 'markup'
      when 'margin' then
        order_by = 'margin'
      when 'user_price' then
        order_by = 'user_price'
      when 'provider_price' then
        order_by = 'provider_price'
      when 'profit' then
        order_by = 'profit'
      when 'termination_name' then
        order_by = 'nice_device'
      else
        order_by = options[:order_by]
    end

    order_by += (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC') if order_by.present?
    return order_by
  end


  def call_log
    CallLog.where(uniqueid: self.uniqueid).first
  end

  def OldCall.last_calls(options = {})
    cond, var, jn = OldCall.last_calls_parse_params(options)
    select = ["calls_old.*", OldCall.nice_billsec_sql]
    select << SqlExport.nice_user_sql
    select << OldCall.nice_disposition + ' AS disposition'
    select << "#{SqlExport.nice_device_sql} "

    if options[:current_user].usertype == 'user'
      select << "(IF(calls_old.user_id = #{options[:current_user].id}, #{SqlExport.calls_old_user_price_sql}) * #{options[:exchange_rate]} ) AS user_price_exrate"
      select << "(#{SqlExport.calls_old_user_rate_sql} * #{options[:exchange_rate]}) AS user_rate_exrate"
    else
      select << "(#{SqlExport.calls_old_user_price_sql} * #{options[:exchange_rate]}) AS user_price_exrate"
      select << "(#{SqlExport.calls_old_admin_user_rate_sql} * #{options[:exchange_rate]}) AS user_rate_exrate"
      select << "(#{SqlExport.calls_old_admin_provider_rate_sql} * #{options[:exchange_rate]}) AS provider_rate_exrate "
      select << "(#{SqlExport.calls_old_admin_provider_price_sql} * #{options[:exchange_rate]}) AS provider_price_exrate"
    end

    # Termination Points
    jn << 'LEFT JOIN devices ON devices.id = calls_old.dst_device_id'
    offset = (options[:page].to_i-1)*options[:items_per_page].to_i

    OldCall.select(select.join(", \n")).where([cond.join(" \nAND "), *var]).joins(jn.join(" \n")).
        order(options[:order]).limit(options[:items_per_page]).offset(offset)
  end

  def OldCall.last_calls_total_stats(options = {})
    options[:exchange_rate] ||= 1
    cond, var, jn = OldCall.last_calls_parse_params(options)

    if options[:current_user].usertype == 'reseller'
      prov_price = "(SUM(#{SqlExport.calls_old_reseller_provider_price_sql}) * #{options[:exchange_rate].to_d}) as total_provider_price"
      user_price = SqlExport.calls_old_user_price_sql
    else
      prov_price = "(SUM(#{SqlExport.calls_old_admin_provider_price_sql}) * #{options[:exchange_rate].to_d}) as total_provider_price"
      user_price = SqlExport.calls_old_user_price_sql
    end

    if User.current.is_user? and Confline.get_value('Invoice_user_billsec_show', User.current.owner.id).to_i == 1
      billsec_sql = "CEIL(user_billsec)"
    else
      billsec_sql = "IF((billsec = 0 AND real_billsec > 0), CEIL(real_billsec), billsec)"
    end

    OldCall.select(" COUNT(*) AS total_calls,
                     SUM(#{billsec_sql}) AS total_duration,
                     SUM(#{user_price}) * #{options[:exchange_rate].to_d} AS total_user_price,
                   " + prov_price)
           .where([cond.join(' AND '), *var])
           .joins(jn.join(" \n")).first
  end

  def OldCall.last_calls_csv(options = {})
    cond, var, jn = OldCall.last_calls_parse_params(options)
    sql_cond = []
    format = Confline.get_value('Date_format', options[:current_user].owner_id).gsub('M', 'i')
    csv_full_src = true if options[:show_full_src].to_i == 1
    #calldate2 - because something overwites calldate when changing date format
    time_offset = options[:current_user].time_offset
    sql_cond << SqlExport.column_escape_null(SqlExport.nice_date('calls_old.calldate', {format: format, offset: time_offset}), 'calldate2')
    unless csv_full_src
      sql_cond << SqlExport.column_escape_null("calls_old.src", "src")
    end
    if csv_full_src or options[:pdf].to_i == 1
      sql_cond << SqlExport.column_escape_null("calls_old.clid", "clid")
    end
    options[:current_user].usertype == 'user' ? sql_cond << SqlExport.hide_dst_for_user_sql(options[:current_user], 'csv', SqlExport.column_escape_null('calls_old.localized_dst'), {as: 'dst'}) : sql_cond << SqlExport.column_escape_null('calls_old.localized_dst', 'dst')
    sql_cond << SqlExport.column_escape_null('calls_old.prefix', 'prefix')
    sql_cond << "CONCAT(#{SqlExport.column_escape_null("directions.name")}, ' ', #{SqlExport.column_escape_null("destinations.name")}) as destination"
    sql_cond << OldCall.nice_billsec_sql
    sql_cond << 'calls_old.duration as duration'

    if options[:current_user].usertype != 'user'
      sql_cond << "IF(calls_old.hangupcause = '312', 'CANCEL', CONCAT(#{SqlExport.column_escape_null("calls_old.disposition")}, '(', #{SqlExport.column_escape_null("calls_old.hangupcause")}, ')')) AS dispod"
    else
      sql_cond << SqlExport.column_escape_null(OldCall.nice_disposition, 'dispod')
    end
    if options[:current_user].usertype == 'admin'
      unless options[:hide_finances]
        sql_cond << SqlExport.replace_dec("(IF(providers.user_id > 0, 0, IFNULL(#{SqlExport.calls_old_admin_provider_rate_sql}, 0)) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_rate')
        sql_cond << SqlExport.replace_dec("(IF(providers.user_id > 0, 0, IFNULL(#{SqlExport.calls_old_admin_provider_price_sql}, 0)) * #{options[:exchange_rate]} )", options[:column_dem], 'provider_price')
      end

      unless options[:hide_finances]
        sql_cond << SqlExport.replace_dec("(IFNULL(#{SqlExport.calls_old_user_rate_sql}, 0) * #{options[:exchange_rate]} )", options[:column_dem], 'user_rate')
        sql_cond << SqlExport.replace_dec("(IFNULL(#{SqlExport.calls_old_user_price_sql}, 0) * #{options[:exchange_rate]} ) ", options[:column_dem], 'user_price')
      end
    end

    filename = "Last_calls_old-#{options[:current_user].id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
    sql = "SELECT * "
    if options[:pdf].to_i == 0 and options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    # OldCall.last_calls_parse_params might return "LEFT JOIN destinations ..."
    # if condition below is met, in that case we should not join destinations again
    # it is very important to join tables in this paricular order DO NOT CHANGE IT
    jn << "LEFT JOIN destinations ON destinations.prefix = IFNULL(calls_old.prefix, '') " if options[:s_country].blank?
    jn << 'LEFT JOIN directions ON directions.code = (destinations.direction_code)'

    one_row = "SELECT #{sql_cond.join(', ')} FROM calls_old #{jn.join(' ')} LIMIT 1"
    columns = ActiveRecord::Base.connection.select_all(one_row).columns

    headers = self.last_calls_csv_headers
    headers = columns.map { |name| "'#{headers[name] || name}' AS  '#{name}'" }
    header_sql = 'SELECT ' + headers.join(', ') + ' UNION ALL ' if options[:csv]

    sql += " FROM (#{header_sql.to_s} (SELECT #{sql_cond.join(', ')}
             FROM calls_old FORCE INDEX (calldate)"
    sql += jn.join(' ')
    sql += "WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} ORDER BY #{options[:order]} )) as C"

    test_content = ''
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      # MorLog.my_debug(sql)
      # MorLog.my_debug("------------------------------------------------------------------------")
      # MorLog.my_debug(mysql_res.inspect.to_s)
      test_content = mysql_res.to_a.to_json
    else
      if options[:pdf].to_i == 1
        filename = OldCall.find_by_sql(sql)
      else
        ActiveRecord::Base.connection.execute(sql)
      end

    end
    return filename, test_content
  end

  def OldCall.country_stats(options = {})
    cond = [[], []]

    if options[:user_id]
      if options[:user_id] != '-1'
        cond << 'calls_old.user_id = ? '
        var << options[:user_id]
      end
    end

    user_price = SqlExport.replace_price(SqlExport.admin_user_price_sql)
    provider_price = SqlExport.replace_price(SqlExport.calls_old_admin_provider_price_sql)

    cond << "calls_old.calldate BETWEEN ? AND ?"
    var += ["#{options[:a1]}", "#{options[:a2]}"]

    cond << 'calls_old.disposition = "ANSWERED"'

    calls_all = OldCall.where([cond.join(' AND ').to_s] + var)
                       .select("COUNT(*) as 'calls_old', SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) )) as 'billsec', SUM(#{provider_price}) as 'selfcost', SUM(#{user_price}) as 'price', SUM(#{user_price}-#{provider_price}) as calls_profit")
                       .joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}").first

    calls = OldCall.where([cond.join(' AND ').to_s] + var)
                   .select("destinations.direction_code as 'direction_code', destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', COUNT(*) as 'calls', SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) )) as 'billsec', SUM(#{provider_price}) as 'selfcost', SUM(#{user_price}) as 'price'")
                   .joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}")
                   .group('destinationgroups.id')
                   .order('destinationgroups.name ASC').to_a

    calls_for_pie_graph = OldCall.where([cond.join(' AND ').to_s] + var)
                                 .select("destinationgroups.name as 'dg_name',SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) )) as 'billsec'")
                                 .joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}")
                                 .group('destinationgroups.id')
                                 .order('billsec desc').to_a

    calls_for_price = OldCall.where([cond.join(' AND ').to_s] + var)
                                 .select("destinationgroups.name as 'dg_name', SUM(#{user_price}) as 'price'")
                                 .joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}")
                                 .group('destinationgroups.id')
                                 .order('price desc').to_a

    calls_for_profit = OldCall.where([cond.join(' AND ').to_s] + var)
                                 .select("destinationgroups.name as 'dg_name', SUM(#{user_price}-#{provider_price}) as calls_profit",)
                                 .joins("LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}")
                                 .group('destinationgroups.id')
                                 .order('calls_profit desc').to_a

    # ---------- Graphs ------------
    #    Countries times for pie
    all = 0
    country_times_pie = "\""
    if calls_for_pie_graph and calls_for_pie_graph.size.to_i > 0
      calls_for_pie_graph.each_with_index do |c, i|
        pull = (i == 1) ? 'true' : 'false'
        if i < 6
          country_times_pie += c.dg_name.to_s + ';' + (c.billsec.to_i / 60).to_s + ';' + pull + "\\n"
        else
          all += c.billsec
        end
      end
      country_times_pie += _('Others') + ';' + (all.to_i / 60).to_s + ";false\\n"
    else
      country_times_pie += _('No_result') + ";1;false\\n"
    end
    country_times_pie += "\""

    # ------- Countries profit graph ----------
    all = 0
    countries_profit_pie = "\""
    if calls_for_profit and calls_for_profit.size.to_i > 0
      calls_for_profit.each_with_index do |c, i|
        pull = (i == 1) ? 'true' : 'false'
        if i < 6
          countries_profit_pie += c.dg_name.to_s + ';' + (Email.nice_number(c.calls_profit.to_d)).to_s + ';' + pull + "\\n"
        else
          all += c.calls_profit.to_d
        end
      end
      countries_profit_pie += _('Others') + ';' + Email.nice_number(all.to_d > 0.to_d ? all.to_d : 0).to_s + ";false\\n"
    else
      countries_profit_pie += _('No_result') + ";1;false\\n"
    end
    countries_profit_pie += "\""

    # ------- Countries incomes graph ----------
    all = 0
    countries_incomes_pie = "\""
    if calls_for_price and calls_for_price.size.to_i > 0
      calls_for_price.each_with_index do |c, i|
        pull = i == 1 ? 'true' : 'false'
        if i < 6
          countries_incomes_pie += c.dg_name.to_s + ';' + Email.nice_number(c.price.to_d).to_s + ';' + pull + "\\n"
        else
          all += c.price.to_d
        end
      end
      countries_incomes_pie += _('Others') + ';' + Email.nice_number(all.to_d).to_s + ";false\\n"
    else
      countries_incomes_pie += _('No_result') + ";1;false\\n"
    end
    countries_incomes_pie += "\""

    return calls, country_times_pie, countries_profit_pie, countries_incomes_pie, calls_all

  end

  def OldCall.hangup_cause_codes_stats(options = {})
    cond = []
    var = []

    if options[:user_id].to_i != -1
      cond << 'calls_old.user_id = ? '; var << options[:user_id]
    end

    if options[:device_id].to_i != -1
      cond << "(calls_old.src_device_id = ? OR calls_old.dst_device_id = ?)"
      var += [options[:device_id].to_i, options[:device_id].to_i]
    end

    des = ''
    if options[:country_code] and !options[:country_code].blank?
      cond << "destinations.direction_code = ? "; var << options[:country_code]
      des = 'LEFT JOIN destinations ON (calls_old.prefix = destinations.prefix)'
    end

    # if options[:current_user].usertype == "reseller"
    #   cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
    #   var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
    # end

    cond << "calls_old.calldate BETWEEN ? AND ?"
    var += [options[:a1].to_s, options[:a2].to_s]

    sql = "SELECT calls_hc.hc_code, calls_hc.calls, hangupcausecodes.id, hangupcausecodes.code, hangupcausecodes.description FROM(
              SELECT calls_old.hangupcause AS 'hc_code', count(calls_old.id) AS 'calls' FROM calls #{des} WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} GROUP BY hc_code) AS calls_hc
           LEFT JOIN hangupcausecodes ON (calls_hc.hc_code = hangupcausecodes.code) ORDER BY hc_code ASC"

    calls = OldCall.find_by_sql(sql)

    sql2 = "SELECT calls_hc.hc_code, calls_hc.calls, hangupcausecodes.id, hangupcausecodes.code, hangupcausecodes.description FROM(
              SELECT calls_old.hangupcause AS 'hc_code', count(calls_old.id) AS 'calls' FROM calls #{des} WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} GROUP BY hc_code) AS calls_hc
           LEFT JOIN hangupcausecodes ON (calls_hc.hc_code = hangupcausecodes.code) ORDER BY calls DESC"

    code_calls = OldCall.find_by_sql(sql2)

    format = Confline.get_value('Date_format', options[:current_user].owner_id).gsub('%H:%M:%S', '')

    date_period = []
    a1 = !options[:a1].blank? ? options[:a1] : '2004'
    a2 = !options[:a2].blank? ? options[:a2] : Date.today.to_s
    a2 = a1 if a1.to_date > a2.to_date
    a1.to_date.upto(a2.to_date) do |date|
      date_period << "select '#{date.to_s}' as call_date2"
    end

    day_calls = OldCall.find_by_sql(
        "SELECT * FROM (SELECT * FROM (SELECT * FROM (#{date_period.join(" UNION ")}) AS v) AS d) AS u
        LEFT JOIN (SELECT DATE(calldate) as call_date, #{SqlExport.nice_date('DATE(calldate)', {reference: 'call_date_formated', format: format, tz: options[:current_user].time_offset})}, SUM(IF(calls_old.hangupcause = '16', 1,0)) as 'calls', SUM(IF(calls_old.hangupcause != '16', 1,0)) as 'b_calls' FROM calls
                    LEFT JOIN hangupcausecodes ON (calls_old.hangupcause = hangupcausecodes.code ) #{des}
                    WHERE #{ ActiveRecord::Base.sanitize_sql_array([(cond+["calls_old.hangupcause != ''"]).join(' AND '), *var])}
                    GROUP BY call_date ) AS p ON (u.call_date2 = DATE(p.call_date) )")

    # ---------- Graphs ------------
    #    Hangup causes codes for pie
    all = 0
    hcc_pie = "\""
    calls_size = 0
    if code_calls and code_calls.size.to_i > 0
      code_calls.each_with_index do |call, i|
        pull = (i == 1) ? 'true' : 'false'
        if i < 6
          hcc_pie += call.hc_code.to_s + ';' + (call.calls.to_i).to_s + ';' + pull + "\\n"
        else
          all += call.calls.to_i
        end
        calls_size += call.calls.to_i
      end
      hcc_pie += _('Others') + ';' + all.to_s + ";false\\n"
    else
      hcc_pie += _('No_result') + ";1;false\\n"
    end
    hcc_pie += "\""

    # Hangup causes codes for line
    hcc_graph = []
    day_calls.each_with_index { |call, i| hcc_graph << call.call_date_formated.to_s + ';' + call.calls.to_i.to_s + ';' + call.b_calls.to_i.to_s }

    return calls, hcc_pie, hcc_graph.join("\\n"), calls_size
  end

  def OldCall.country_stats_csv(options = {})

    cond = ["calls_old.calldate BETWEEN ? AND ?  AND calls_old.disposition = 'ANSWERED' "]
    var = [options[:from].to_s + ' 00:00:00', options[:till].to_s + ' 23:59:59']
    jn = ['LEFT JOIN destinations ON (destinations.prefix = calls_old.prefix)', "JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id)#{SqlExport.calls_old_left_join_reseler_providers_to_calls_sql}"]
    if options[:s_user].to_i != -1
      cond << 'calls_old.user_id = ? '; var << options[:s_user]
    end

    # if options[:current_user].usertype == 'reseller'
      # cond << "(calls_old.reseller_id = ? OR calls_old.user_id = ? OR calls_old.dst_user_id = ?)"
      # var += [options[:current_user].id, options[:current_user].id, options[:current_user].id]
      # user_price = SqlExport.replace_price(SqlExport.calls_old_user_price_sql)
      # provider_price = SqlExport.replace_price(SqlExport.calls_old_reseller_provider_price_sql)
    # else
    user_price = SqlExport.replace_price(SqlExport.calls_old_admin_user_price_sql)
    provider_price = SqlExport.replace_price(SqlExport.calls_old_admin_provider_price_sql)
    # end
    s = []

    s << SqlExport.replace_sep("destinationgroups.name", options[:collumn_separator], nil, "dg_name")
    s << SqlExport.column_escape_null("COUNT(*)", 'calls')
    s << SqlExport.column_escape_null("SUM(IF(calls_old.billsec > 0, calls_old.billsec, CEIL(calls_old.real_billsec) ))", 'billsec')
    unless options[:hide_finances]
      s << SqlExport.column_escape_null("SUM(#{provider_price})", 'selfcost')
      s << SqlExport.column_escape_null("SUM(#{user_price})", 'price')
      s << SqlExport.column_escape_null("SUM(#{user_price} - #{provider_price})", 'profit')
    end


    filename = "Country_stats-#{options[:from].gsub(' ', '_').gsub(':', '_')}-#{options[:till].gsub(' ', '_').gsub(':', '_')}-#{Time.now().to_i}"
    sql = "SELECT * "
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{options[:collumn_separator]}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    sql += " FROM (SELECT #{s.join(', ')} FROM calls #{jn.join(' ')}  WHERE #{ ActiveRecord::Base.sanitize_sql_array([cond.join(' AND '), *var])} GROUP BY destinationgroups.id ORDER BY destinationgroups.name ASC) as C"

    test_content = ''
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      MorLog.my_debug(sql)
      MorLog.my_debug('------------------------------------------------------------------------')
      MorLog.my_debug(mysql_res.to_yaml)
      test_content = mysql_res.to_json
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename, test_content
  end

  def OldCall.analize_cdr_import(name, options)
    CsvImportDb.log_swap('analyze')
    MorLog.my_debug("CSV analyze_file #{name}", 1)
    arr = {}
    current_user = User.current.id
    arr[:calls_in_db] = 0 # Call.where(reseller_id: current_user).all.size.to_i
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


    #set flag on bad dst | code : 3
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 3 where replace(replace(col_#{options[:imp_dst]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0  and f_error = 0")
    #set flag on bad calldate | code : 4
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 4 where replace(replace(col_#{options[:imp_calldate]}, '\\r', ''), '
', '') REGEXP '^[0-9 :-]+$' = 0 and f_error = 0 ")
    #set flag on bad billsec | code : 5
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 5 where replace(replace(col_#{options[:imp_billsec]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and f_error = 0")

    #set flag on bad clis and count them
    unless options[:import_user]
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 1 where replace(replace(col_#{options[:imp_clid]}, '\\r', ''), '
', '') REGEXP '^[0-9]+$' = 0 and not_found_in_db = 1")
    end
    cond = options[:import_user] ? " AND user_id = #{options[:import_user]} " : '' #" calls.cli "
    ActiveRecord::Base.connection.execute("UPDATE #{name} JOIN calls ON (calls_old.calldate = timestamp(replace(col_#{options[:imp_calldate]}, '\\r', '')) ) SET f_error = 1, nice_error = 2 WHERE dst = replace(col_#{options[:imp_dst]}, '\\r', '') and billsec = replace(col_#{options[:imp_billsec]}, '\\r', '')  #{cond} and f_error = 0")

    arr[:cdr_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    arr[:bad_cdrs] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    arr[:bad_clis] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 1").to_i
    if options[:step] and options[:step] == 8
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name}  WHERE nice_error != 1 and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.where(device_id: -1).size.to_i
    else
      arr[:new_clis_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} LEFT JOIN callerids on (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) WHERE nice_error != 1 and callerids.id is null and not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
      arr[:clis_to_assigne] = Callerid.where(device_id: -1).size.to_i + arr[:new_clis_to_create].to_i
    end

    arr[:existing_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where not_found_in_db = 0 and f_error = 0").to_i
    arr[:new_clis_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(col_#{options[:imp_clid]})) FROM #{name} where not_found_in_db = 1").to_i if options[:imp_clid] and options[:imp_clid] >= 0
    arr[:cdrs_to_insert] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} where f_error = 0").to_i
    return arr
  end

  def OldCall.insert_cdrs_from_csv(name, options)
    provider = Provider.includes(:tariff).where("providers.id = #{options[:import_provider]}").first if options[:imp_provider_id].to_i < 0

    if options[:import_user]
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN devices ON (devices.id = #{options[:import_device]}) WHERE f_error = 0 and do_not_import = 0")
    else
      res = ActiveRecord::Base.connection.select_all("SELECT *, devices.id as dev_id FROM #{name} JOIN callerids ON (callerids.cli = replace(col_#{options[:imp_clid]}, '\\r', '')) JOIN devices ON (callerids.device_id = devices.id) WHERE f_error = 0 and do_not_import = 0")
    end

    imported_cdrs = 0
    for one_res in res
      billsec = one_res["col_#{options[:imp_billsec]}"].to_i
      call = OldCall.new(billsec: billsec, dst: CsvImportDb.clean_value(one_res["col_#{options[:imp_dst]}"].to_s).gsub(/[^0-9]/, ""), calldate: one_res["col_#{options[:imp_calldate]}"])

      # A: Hack for the mess that gets created with speedup.sql
      call.lastapp = '' if call.attributes.has_key? 'lastapp'
      call.lastdata = '' if call.attributes.has_key? 'lastdata'
      call.uniqueid = '' if call.attributes.has_key? 'uniqueid'
      call.channel = '' if call.attributes.has_key? 'channel'
      call.dcontext = '' if call.attributes.has_key? 'dcontext'
      call.dstchannel = '' if call.attributes.has_key? 'dstchannel'
      call.userfield = '' if call.attributes.has_key? 'userfield'

      duration = CsvImportDb.clean_value(one_res["col_#{options[:imp_duration]}"]).to_i
      duration = billsec if duration == 0 or options[:imp_duration] == -1
      disposition = ''
      disposition = CsvImportDb.clean_value one_res["col_#{options[:imp_disposition]}"] if options[:imp_disposition] > -1
      if disposition.length == 0
        disposition = 'ANSWERED' if billsec > 0
        disposition = 'NO ANSWER' if billsec == 0
      end

      call.clid = CsvImportDb.clean_value one_res["col_#{options[:imp_clid]}"] if options[:imp_clid] > -1
      call.clid = '' if call.clid.to_s.length == 0

      call.src = CsvImportDb.clean_value(one_res["col_#{options[:imp_src_number]}"]).gsub(/[^0-9]/, "") if options[:imp_src_number] > -1
      call.src = call.clid.to_i.to_s if call.src.to_s.length == 0
      call.src = '' if call.src.to_s.length == 0

      call.duration = duration

      call.disposition = disposition
      call.accountcode = one_res['dev_id']
      call.src_device_id = one_res['dev_id']
      call.user_id = one_res['user_id']
      call.provider_id = options[:imp_provider_id].to_i > -1 ? CsvImportDb.clean_value(one_res["col_#{options[:imp_provider_id]}"]).gsub(/[^0-9]/, "") : provider.id

      user = User.find(call.user_id)

      # call.reseller_id = user.owner_id
      call = call.count_cdr2call_details(options[:imp_provider_id].to_i > -1 ? call.provider.tariff_id : provider.tariff_id, user) if call.valid?

      if call.save
        user.balance -= call.user_price
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
    @prov_exchange_rate_cache ||= {}
    @tariffs_cache ||= {}

    if user_id.class == User
      user = user_id
      user_id = user.id
    else
      user = User.includes(:tariff).where(['users.id = ?', user_id]).first
    end
    # logger.info user.to_yaml

    # testing tariff
    if user_test_tariff_id > 0
      tariff = Tariff.where(id: user_test_tariff_id).first
      CsvImportDb.clean_value "Using testing tariff with id: #{user_test_tariff_id}"
    else
      tariff = user.tariff
    end
    dst = CsvImportDb.clean_value self.dst.to_s #.gsub(/[^0-9]/, "")
    device_id = self.accountcode
    time = self.calldate.strftime('%H:%M:%S')

    if selfcost_tariff_id.class == Tariff
      prov_tariff = selfcost_tariff_id
      selfcost_tariff_id = prov_tariff.id
      @tariffs_cache["t_#{selfcost_tariff_id}".to_sym] ||= prov_tariff
    else
      prov_tariff = @tariffs_cache["t_#{selfcost_tariff_id}".to_sym] ||= Tariff.find(selfcost_tariff_id)
    end

    prov_exchange_rate = @prov_exchange_rate_cache["p_#{prov_tariff.id}".to_sym] ||= prov_tariff.exchange_rate

    # my_debug ""

    # get daytype and localization settings
    day = self.calldate.to_s(:db)
    sql = "SELECT (SELECT IF((SELECT daytype FROM days WHERE date = '#{day}') IS NULL, (SELECT IF(WEEKDAY('#{day}') = 5 OR WEEKDAY('#{day}') = 6, 'FD', 'WD')), (SELECT daytype FROM days WHERE date = '#{day}')))   as 'dt' FROM devices WHERE devices.id = #{device_id} ORDER BY LENGTH(cut) DESC LIMIT 1;"
    res = ActiveRecord::Base.connection.select_one(sql)
    if res and res['device_id'].blank?
      daytype = res['dt']

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

      # data for selfcost
      dst_array = []
      dst.length.times { |i| dst_array << dst[0, i + 1] }
      if dst_array.size > 0
        sql =
            "SELECT A.prefix, ratedetails.rate,   ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee "+
                "FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype = '#{daytype}' OR ratedetails.daytype = '' ) AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations " +
                "WHERE destinations.prefix IN ('#{dst_array.join("', '")}') ORDER BY LENGTH(destinations.prefix) DESC) " +
                "as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{selfcost_tariff_id} ORDER BY LENGTH(A.prefix) DESC LIMIT 1;"
      end

      # my_debug sql
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

      # MorLog.my_debug "PROVIDER's: prefix: #{s_prefix}, rate: #{s_rate}, increment: #{s_increment}, min_time: #{s_min_time}, conn_fee: #{s_conn_fee}, billsec: #{s_billsec}, price: #{s_price}, exchange_rate = #{prov_exchange_rate}"

      # ====================== data for USER ==============
      price, max_rate, user_exchange_rate, temp_prefix, user_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, user)
      MorLog.my_debug "USER: call_id: #{self.id}, user_price: #{price}, max_rate: #{max_rate}, exchange_rate: #{user_exchange_rate}, tmp_prefix: #{temp_prefix}, user_billsec: #{user_billsec}"

      # ====================== data for RESELLER ==============

      # if self.reseller_id.to_i > 0

      #   reseller = User.where(id: self.reseller_id.to_i).first
      #   tariff = @tariffs_cache["t_#{reseller.tariff_id.to_i}".to_sym] ||= Tariff.where(id: reseller.tariff_id.to_i).first if reseller

      #   if reseller and tariff
      #     res_price, res_max_rate, res_exchange_rate, res_temp_prefix, res_billsec = self.count_call_rating_details_for_user(tariff, time, daytype, dst, reseller)
      #     MorLog.my_debug "RESELLER: call_id: #{self.id}, user_price: #{res_price}, max_rate: #{res_max_rate}, exchange_rate: #{res_exchange_rate}, tmp_prefix: #{res_temp_prefix}, user_billsec: #{res_billsec}"
      #   end

      # end

      # ========= Calculation ===========

      # new
      self.provider_rate = s_rate / prov_exchange_rate
      self.user_rate = max_rate / user_exchange_rate

      self.provider_billsec = s_billsec
      self.user_billsec = user_billsec

      self.provider_price = 0
      self.user_price = 0

      # call.dst = orig_dst

      # call.prefix = res[0]["prefix"] if res[0]

      if temp_prefix.to_s.length > s_prefix.to_s.length
        self.prefix = temp_prefix
      else
        self.prefix = s_prefix
      end

      # if !res_temp_prefix.blank? and self.prefix
      #   if self.reseller_id.to_i > 0 and res_temp_prefix.to_s.length > self.prefix.to_s.length
      #     self.prefix = res_temp_prefix
      #   end
      # end

      # need to find prefix for error fixing when no prefix is in calls table - this should not happen anyways, so maybe no fix is neccesary?

      if self.disposition == 'ANSWERED'
        #        call.prov_price = s_price
        #        call.price = price

        # new
        self.provider_price = s_price / prov_exchange_rate
        self.user_price = price / user_exchange_rate

        # if self.reseller_id.to_i > 0
        #   self.reseller_price = res_price / res_exchange_rate
        # end

      end
    else
      MorLog.my_debug "#{Time.now.to_s(:db)}  SQL not found--------------------------------------------"
      MorLog.my_debug sql
    end
    self
  end

  def count_call_rating_details_for_user(tariff, time, daytype, dst, user)
    @count_call_rating_details_for_user_exchange_rate_cache ||= {}

    # ======================= user wholesale ===============

    sql = "SELECT A.prefix, ratedetails.rate, ratedetails.increment_s, ratedetails.min_time, ratedetails.connection_fee as 'cf' FROM  rates JOIN ratedetails ON (ratedetails.rate_id = rates.id  AND (ratedetails.daytype =  '#{daytype}' OR ratedetails.daytype = '' )  AND '#{time}' BETWEEN ratedetails.start_time AND ratedetails.end_time) JOIN (SELECT destinations.* FROM  destinations WHERE destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) ORDER BY LENGTH(destinations.prefix) DESC) as A ON (A.id = rates.destination_id) WHERE rates.tariff_id = #{tariff.id} LIMIT 1;"

    # my_debug sql

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

    # my_debug (call.billsec.to_d / uw_increment)
    # my_debug (call.billsec.to_d / uw_increment).floor
    # my_debug (call.billsec / uw_increment).floor * uw_increment
    # my_debug uw_billsec

    uw_price = (uw_rate * uw_billsec) / 60 + uw_conn_fee

    price = uw_price
    max_rate = uw_rate
    user_exchange_rate = @count_call_rating_details_for_user_exchange_rate_cache["te_#{tariff.id}".to_sym] ||= tariff.exchange_rate
    temp_prefix = uw_prefix
    user_billsec = uw_billsec

    return price, max_rate, user_exchange_rate, temp_prefix, user_billsec
  end

  def termination_device
    Device.where(id: dst_device_id).first
  end

  private

  def OldCall.last_calls_parse_params(options = {})
    jn = ['LEFT JOIN users ON (calls_old.user_id = users.id)',
          SqlExport.calls_old_left_join_reseler_providers_to_calls_sql
    ]
    cond = ["(calls_old.calldate BETWEEN ? AND ?)"]
    var = [options[:from], options[:till]]
    jn << "LEFT JOIN devices AS src_device ON (src_device.id = calls_old.src_device_id)"
    if options[:call_type] != "all"
      if ['answered', 'failed'].include?(options[:call_type].to_s)
        cond << OldCall.nice_answered_cond_sql if options[:call_type].to_s == 'answered'
        cond << OldCall.nice_failed_cond_sql if options[:call_type].to_s == 'failed'
      else
        if options[:call_type] == 'no answer'
          cond << 'calls_old.hangupcause != ?'
          var << '312'
        end

        if options[:call_type] == 'Cancel'
          cond << 'calls_old.hangupcause = ?'
          var << '312'
        else
          cond << 'calls_old.disposition = ?'
          var << options[:call_type]
        end
      end
    end

    if options[:hgc]
      cond << 'calls_old.hangupcause = ?'
      var << options[:hgc].code
    end

    unless options[:destination].blank?
      cond << 'localized_dst like ?'
      var << "#{options[:destination]}%"
    end

    if options[:s_country] and !options[:s_country].blank?
      cond << 'destinations.direction_code = ? '; var << options[:s_country]
      jn << 'LEFT JOIN destinations ON (calls_old.prefix = destinations.prefix)'
    end

    if options[:device]
      cond << '(calls_old.dst_device_id = ? OR calls_old.src_device_id = ?)'
      var += [options[:device].id, options[:device].id]
    end

    if options[:user]
      if options[:current_user].usertype == 'reseller'
        cond << '(calls_old.user_id = ?)'
        var += [options[:user].id]
      else
        jn << 'LEFT JOIN devices AS dst_device ON (dst_device.id = calls_old.dst_device_id)'
        cond << '(src_device.user_id = ?)'
        var += [options[:user].id]
      end
    end

    if options[:tp_user]
      cond << '(calls_old.dst_user_id = ?)'
      var += [options[:tp_user].id]
    end

    current_user = options[:current_user]
    if current_user.show_only_assigned_users?
      assigned_users = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
      cond << '(src_device.user_id IN (?))'
      var += [assigned_users]
    end

    if options[:provider]
      c = ''
      c << '(' if options[:provider]
      c << 'calls_old.provider_id = ?' if options[:provider]
      c << ' or ' if options[:provider]
      c << ')' if options[:provider]
      cond << c
      var += [options[:provider].id] if options[:provider]
    end
    opt_origination_point = options[:origination_point]
    opt_termination_point = options[:termination_point]

    if opt_origination_point.present? && opt_origination_point.id
      cond << '(calls_old.src_device_id = ?)'
      var += [opt_origination_point.id]
    end

    if opt_termination_point
      cond << 'calls_old.dst_device_id = ?'
      var += [opt_termination_point.id]
    end

    # if options[:reseller]
    #   cond << 'calls_old.reseller_id = ?'
    #   var << options[:reseller].id
    # end

    if options[:source] and not options[:source].blank?
      cond << 'calls_old.src LIKE ?'
      var << '%' + options[:source] + '%'
    end

    if options[:s_duration].present?
      cond << "#{OldCall.nice_billsec_condition} = ?"
      var += [options[:s_duration]]
    end

    return cond, var, jn
  end

  def self.last_calls_csv_headers
    {
      'calldate2' => _('Date'),
      'Source' => _('Called_from'),
      'clid' => "#{_('Called_from')} (#{'Source'})",
      'dst' => "#{_('Called_to')} (#{'Destination'})",
      'prefix' => _('Prefix'),
      'destination' => _('Destination'),
      'nice_billsec' => _('Billsec'),
      'duration' => _('duration'),
      'dispod' => _('hangup_cause'),
      'provider_rate' => _('Provider_rate'),
      'provider_price' => _('Provider_price'),
      'user_rate' => _('User_rate'),
      'user_price' => _('User_price')
    }
  end
end
