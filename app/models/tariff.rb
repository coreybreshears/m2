# Tariffs model
class Tariff < ActiveRecord::Base
  include CsvImportDb
  include UniversalHelpers
  attr_protected

  has_many :rates
  has_many :users
  has_many :managers
  has_many :origination_points, class_name: 'Device', foreign_key: 'op_tariff_id'
  has_many :termination_points, class_name: 'Device', foreign_key: 'tp_tariff_id'
  has_many :tariff_import_rules, dependent: :destroy
  has_many :tariff_jobs, through: :tariff_import_rules
  has_many :rate_notification_jobs, dependent: :destroy
  belongs_to :owner, class_name: 'User'

  validates_uniqueness_of :name, message: _('Name_must_be_unique'), scope: [:owner_id]
  validates_presence_of :name, message: _('Name_cannot_be_blank')

  def real_currency
    Currency.where(name: currency).first
  end

  # select rates by their countries (directions) first letter for easier management
  def rates_by_st(st, sql_start, per_page)
    Rate.find_by_sql ['SELECT rates.id, rates.tariff_id, rates.destination_id, destinations.direction_code, prefix, destinations.name as destination_name FROM destinations, rates, directions WHERE rates.tariff_id = ? AND destinations.id = rates.destination_id AND directions.code = destinations.direction_code AND directions.name like ? GROUP BY rates.id ORDER BY directions.name ASC, destinations.prefix ASC LIMIT ' + sql_start.to_s + ',' + per_page.to_s, self.id, st.to_s + '%']
  end

  # destinations which have rate assigned for this tariff
  def destinations
    Destination.select('destinations.*')
               .from('destinations, tariffs, rates, directions')
               .where(['rates.tariff_id = ? AND destinations.id = rates.destination_id', id])
               .group('destinations.id')
               .order('destinations.prefix ASC')
  end

  def queries(currency)
    exchange_rate = self.exchange_rate(currency)
    queries = [
        ", MAX(IF(tariffs_#{self.id}_id IS NOT NULL, rate_check_list.rate / #{exchange_rate}, NULL)) AS rate_#{self.id}",
        ", tariffs_#{self.id}.id AS tariffs_#{self.id}_id, CONCAT(tariffs_#{self.id}.id, '_', rates.prefix) AS order_#{self.id}",
        " LEFT JOIN tariffs tariffs_#{self.id} ON (tariffs_#{self.id}.id = rates.tariff_id AND tariffs_#{self.id}.id = #{self.id})",
        "tariffs_#{self.id}.id IS NOT NULL",
        "order_#{self.id}",
        "rate_check_data.order_#{self.id}"
    ]
    queries
  end

  # destinations which haven't rate assigned for this tariff by first letter
  def free_destinations_by_st(st, limit = nil, offset = 0)
    st = st.to_s
    destination_ids = Destination.select('destinations.id')
                                 .joins(:destinationgroup)
                                 .joins(:rates)
                                 .where("destinationgroups.name LIKE '#{st}%' AND rates.tariff_id = #{id} AND destinations.prefix REGEXP '^[0-9]+$' = 1").all.collect(&:id)

    query = Destination.select('destinations.*, destinations.name AS destination_name, directions.name as direction_name')
                       .joins(:destinationgroup)
                       .joins(:direction)
                       .where("destinationgroups.name LIKE '#{st}%' AND destinations.prefix REGEXP '^[0-9]+$' = 1")

    query = query.where("destinations.id NOT IN (#{destination_ids.join(',')})") if destination_ids.present?

    adests = query.order('directions.name ASC, destinations.prefix ASC').limit(limit || 1000000).offset(offset).all

    actual_adest_count = query.to_a.size
    limit ? [adests, actual_adest_count] : adests
  end

  #  Returns destinations that have no assigned rates.
  # *Params*:
  # +direction+ - Direction, or Direction.id
  # *Flash*:
  # +notice+ - messages that are passed through flash[:notice]
  # *Redirect*
  def free_destinations_by_direction(direction, options = {})
    destinations = []
    extra = {}
    extra[:limit] = options[:limit].to_i if options[:limit] and options[:limit].to_i
    extra[:offset] = options[:offset].to_i if options[:offset] and options[:offset].to_i
    if direction.class == String
      destinations = Destination.select("destinations.*, directions.code AS 'dir_code', directions.name AS 'dir_name' ")
                                .joins("LEFT JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN (SELECT * FROM rates where tariff_id = #{self.id}) as rates  ON (rates.destination_id = destinations.id)")
                                .where(["destinations.direction_code = ? AND rates.id IS NULL", code])

    end
    if direction.class == Direction
      destinations = Destination.select("destinations.*, directions.code AS 'dir_code', directions.name AS 'dir_name' ")
                                .joins("LEFT JOIN directions ON (directions.code = destinations.direction_code) LEFT JOIN (SELECT * FROM rates where tariff_id = #{self.id}) as rates  ON (rates.destination_id = destinations.id)")
                                .where(["destinations.direction_code = ? AND rates.id IS NULL", direction.code])
    end

    if direction.class == Direction || direction.class == String
      destinations = if extra.size == 2
                       destinations.limit(extra[:limit]).offset(extra[:offset]).all
                     elsif extra[:limit].present?
                       destinations.limit(extra[:limit]).all
                     elsif extra[:offset].present?
                       estinations.offset(extra[:offset]).all
                     else
                       destinations.all
                     end
    end
    options[:with_count] == true
    destinations
  end

  def add_new_rate(dest_id, rate_value, increment, min_time, connection_fee, ghost_percent = nil, effective_from = nil)
    destination = Destination.where(id: dest_id).first
    rate = Rate.new(
      tariff_id: id,
      destination_id: dest_id,
      ghost_min_perc: ghost_percent,
      prefix: destination.prefix,
      destinationgroup_id: destination.destinationgroup_id,
      effective_from: effective_from
    )

    increment = increment.to_i
    min_time = min_time.to_i
    rate_det = Ratedetail.new
    rate_det.rate = rate_value.to_d
    rate_det.increment_s = (increment < 1) ? 1 : increment
    rate_det.min_time = (min_time < 0) ? 0 : min_time
    rate_det.connection_fee = connection_fee.to_d

    rate.ratedetails << rate_det

    rate.save
  end

  def delete_all_rates
    sql = "DELETE ratedetails, rates FROM ratedetails, rates WHERE ratedetails.rate_id = rates.id AND rates.tariff_id = '#{id}'"
    res = retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }

    # Just in case - sometimes helps after crashed rate import from CSV file
    sql = "DELETE FROM rates WHERE rates.tariff_id = '#{id}'"
    res = retry_lock_error(3) { ActiveRecord::Base.connection.execute(sql) }
  end

  def exchange_rate(cur = nil)
    if cur
      Currency.count_exchange_rate(cur, currency)
    else
      sql = "SELECT exchange_rate FROM currencies, tariffs WHERE currencies.name = tariffs.currency AND tariffs.id = '#{id}'"
      res = ActiveRecord::Base.connection.select_one(sql)
      res['exchange_rate'].to_d
    end
  end

  def generate_user_rates_csv(session)
    sql = "SELECT rates.* FROM rates
            LEFT JOIN destinationgroups on (destinationgroups.id = rates.destinationgroup_id)
            WHERE rates.tariff_id ='#{id}'
            ORDER BY destinationgroups.name ASC"
    rates = Rate.find_by_sql(sql)
    sep = Confline.get_value('CSV_Separator').to_s
    dec = Confline.get_value('CSV_Decimal').to_s


    csv_string = _('Destination') + sep + _('Rate') + '(' + session[:show_currency].to_s + ')' + sep + _('Round') + "\n"

    exrate = Currency.count_exchange_rate(currency, session[:show_currency])
    for rate in rates
      csv_string += !rate.destinationgroup ? "0#{sep}0#{sep}" : "#{rate.destinationgroup.name.to_s.gsub(sep, ' ')}#{sep}"
      csv_string += "0#{sep}0\n"
    end

    csv_string
  end

  def tariffs_api_wholesale
    sql = "SELECT CONCAT('<rate><direction>',REPLACE(directions.name,'&','&amp;'), '</direction> <destination>',
           REPLACE(destinations.name,'&','&amp;')
           ,'</destination> <prefix>',destinations.prefix,'</prefix> <code>',
           directions.code,'</code> <tariff_rate>',ratedetails.rate,'</tariff_rate> <con_fee>',
           ratedetails.connection_fee,'</con_fee> <increment>',ratedetails.increment_s,'</increment> <min_time>',
           ratedetails.min_time,'</min_time> <start_time>',ratedetails.start_time,'</start_time> <end_time>',
           ratedetails.end_time,'</end_time> <daytype>',ratedetails.daytype,'</daytype> </rate>')
           FROM rates
           LEFT JOIN ratedetails ON (rates.id = ratedetails.rate_id)
           LEFT JOIN destinations ON (rates.destination_id = destinations.id)
           LEFT JOIN directions ON (directions.code = destinations.direction_code)
           WHERE rates.tariff_id = #{id}
           ORDER BY directions.name ASC;"
    result = ActiveRecord::Base.connection.exec_query(sql).rows.flatten.join(' ')
    result
  end

  def generate_providers_rates_csv(session, options = {})
    @effective_from_active = (%w[admin manager].include?(session[:usertype]) && ['provider', 'user_wholesale'].include?(purpose))
    default_currency = Confline.get_value('tariff_currency_in_csv_export').to_i
    custom_tariff = options[:custom_tariff].to_i != 0
    custom_tariff_cond = (custom_tariff) ? "OR rates.tariff_id = #{options[:custom_tariff].to_i}" : ''
    sql =   "SELECT destinations.name AS destination, B.*
             FROM (
                SELECT * FROM (
                    SELECT rates.prefix, rates.effective_from, ratedetails.start_time,
                           ratedetails.end_time, ratedetails.rate, ratedetails.connection_fee,
                           ratedetails.increment_s, ratedetails.min_time, ratedetails.daytype,
                           ratedetails.blocked, destination_id, IF(tariffs.purpose = 'user_custom',0,1) AS order_priority
                    FROM rates
                    LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id
                    LEFT JOIN tariffs ON rates.tariff_id = tariffs.id
                    WHERE(effective_from < NOW() OR effective_from IS NULL)
                    AND (rates.tariff_id = #{id} #{custom_tariff_cond})
                    ORDER BY rates.effective_from#{', order_priority' if custom_tariff} DESC) AS A
                GROUP BY #{'order_priority, ' if custom_tariff} prefix) AS B
             LEFT JOIN destinations on B.destination_id = destinations.id
             #{'GROUP BY prefix' if custom_tariff}
             ORDER BY destination, prefix;"

    results = Array(ActiveRecord::Base.connection.select_all(sql))
    sep = options[:for_xlsx] ? ',' : Confline.get_value('CSV_Separator').to_s
    dec = options[:for_xlsx] ? '.' : Confline.get_value('CSV_Decimal').to_s

    # currencies
    exrate = Currency.count_exchange_rate(currency, session[:show_currency])
    currency_name = (default_currency == 0) ? session[:show_currency].to_s : currency.to_s

    csv_string = CSV.generate(col_sep: sep, quote_char: "\'") do |csv|
      csv << [
        _('Destination'), # r["destination"]
        _('Prefix'), # r["prefix"]
        _('Rate') + '(' + currency_name + ')', # rate
        _('Connection_Fee') + '(' + currency_name + ')', # con_fee
        _('Increment'), # r["increment_s"]
        _('Minimal_Time'), # r["min_time"]
        _('Start_Time'), # r["start_time"]
        _('End_Time'), # r["end_time"]
        _('Week_Day'), # r["daytype"]
        @effective_from_active ? _('Effective_from') : "\"\"",
        @effective_from_active ? _('Blocked') : "\"\""
      ]
      results.each do |result|

          if default_currency == 0
            rate, con_fee = Currency.count_exchange_prices(exrate: exrate, prices: [result['rate'].to_d, result['connection_fee'].to_d])
          else
            rate = result['rate'].to_d
            con_fee = result['connection_fee'].to_d
          end

          csv << [
              "\"#{result['destination'].to_s.gsub(sep, ' ')}\"",
              result['prefix'],
              nice_number(rate, session).gsub('.', dec),
              nice_number(con_fee, session).gsub('.', dec),
              result['increment_s'],
              result['min_time'],
              result['start_time'].blank? ? "\"\"" : result['start_time'].strftime('%H:%M:%S'),
              result['end_time'].blank? ? "\"\"" : result['end_time'].strftime('%H:%M:%S'),
              result['daytype'].blank? ? "\"\"" : result['daytype'],
              @effective_from_active ? (nice_date_time_user(result['effective_from'], session).blank? ? "\"\"" : nice_date_time_user(result['effective_from'],session)) : "\"\"",
              (@effective_from_active && result['blocked'].to_i == 1) ? _('Blocked') : "\"\""
          ]
        end
      end
  end

  def generate_personal_wholesale_rates_csv(session)
    sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
    rates = Rate.find_by_sql(sql)
    sep = Confline.get_value('CSV_Separator').to_s
    dec = Confline.get_value('CSV_Decimal').to_s

    csv_string = _('Direction') + sep + _('Prefix') +
            sep + _('Rate') + '(' + (session[:show_currency]).to_s + ')' +
            sep + _('Connection_Fee') + '(' + (session[:show_currency]).to_s + ')' + sep + _('Increment') +
            sep + _('Minimal_Time') + "\n"

    exrate = Currency.count_exchange_rate(currency, session[:show_currency])

    for rate in rates
      rate_details, rate_cur = get_provider_rate_details(rate, exrate)

      csv_string += "#{rate.destination.direction.name.to_s.gsub(sep, ' ')}" if rate.destination && rate.destination.direction
      csv_string += "#{sep}#{rate.destination.prefix}#{sep}" if rate.destination
      csv_string += "0#{sep}0#{sep}0#{sep}" unless rate.destination

      csv_string += "#{rate_cur.to_s.gsub('.', dec)}#{sep}#{rate_details[0]['connection_fee'].to_s.gsub('.', dec)}#{sep}#{rate_details[0]['increment_s'].to_s.gsub('.', dec)}#{sep}" +
          "#{rate_details[0]['min_time'].to_s.gsub('.', dec)}\n" if rate_details.size > 0
      csv_string += "0#{sep}0#{sep}0#{sep}0\n" if rate_details.size == 0
    end

    return csv_string
  end

  def check_types_periods(options = {})
    time_from = options[:time_from]
    if time_from
      from = time_from[:hour].to_s + ':' + time_from[:minute].to_s + ':' + time_from[:second].to_s
      till = options[:time_till][:hour].to_s + ':' + options[:time_till][:minute].to_s + ':' + options[:time_till][:second].to_s
    else
      from = options[:time_from_hour].to_s + ':' + options[:time_from_minute].to_s + ':' + options[:time_from_second].to_s
      till = options[:time_till_hour].to_s + ':' + options[:time_till_minute].to_s + ':' + options[:time_till_second].to_s
    end
    day_type = %w[wd fd].include?(options[:rate_day_type].to_s) ? options[:rate_day_type].to_s : ''
    # In case new rate detail's time and daytype is identical to allready existing rate details it will
    # be updated so we don't think it is a collision
    # In case new rate details time is WD and there already is FD there cannot be time collisions. and vice versa
    # In all other cases we need to check for time colissions. Note bug that was originaly here - function does not
    # work if time wraps around e.g. period is between 23:00 and 01:00
    # UPDATE mor has peculiar way to check for time collisions - if at least a minute is set for all days, no other
    # tariff detail can be set to fd/wd and vice versa
    ratesd = Ratedetail.joins('LEFT JOIN rates ON (ratedetails.rate_id = rates.id)').where(["rates.tariff_id = '#{id}' AND
      CASE
        WHEN daytype = '#{day_type}' AND start_time = '#{from}' AND end_time = '#{till}' THEN 0
        WHEN '#{day_type}' IN ('WD', 'FD') AND daytype IN ('WD', 'FD') AND daytype != '#{day_type}' THEN 0
        WHEN (daytype = '' AND '#{day_type}' != '') OR (daytype IN ('WD', 'FD') AND '#{day_type}' NOT IN ('WD', 'FD')) THEN 1
        ELSE ('#{from}' BETWEEN start_time AND end_time) OR ('#{till}' BETWEEN start_time AND end_time) OR (start_time BETWEEN '#{from}' AND '#{till}') OR (end_time BETWEEN '#{from}' AND '#{till}')
      END != 0"]).all

    notice_2 = ''
    # checking time periods for collisions
    # ticket #5808 -> not checking any more
    # if ratesd and ratesd.size.to_i > 0
    #  notice_2 = _('Tariff_import_incorrect_time').html_safe
    #  notice_2 += '<br /> * '.html_safe + _('Please_select_period_without_collisions').html_safe
    #  # redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
    # end

    ratesd = Ratedetail.select("SUM(IF(daytype = '',1,0)) all_sum, SUM(IF(daytype != '',1,0)) wd_fd_sum ").joins('LEFT JOIN rates ON (ratedetails.rate_id = rates.id)').where(["rates.tariff_id = '#{id}'"]).first
    if ratesd.wd_fd_sum.to_i == 0
      rate_types = [[_('All'), 'all'], [_('Work_Days'), 'wd'], [_('Free_Days'), 'fd']]
    else
      rate_types = [_('Work_Days'), 'wd'], [_('Free_Days'), 'fd']
    end

    return rate_types, notice_2
  end

  def head_of_file(path, n = 1)
    CsvImportDb.head_of_file(path, n)
  end

  def save_file(file, path = "/tmp/")
    CsvImportDb.save_file(id, file, path)
  end

  def load_csv_into_db(tname, sep, dec, fl, path = '/tmp/')
    colums = {}
    colums[:colums] = [{name: 'short_prefix', type: 'VARCHAR(50)', default: ''},
                       {name: 'f_country_code', type: 'INT(4)', default: 0},
                       {name: 'f_error', type: 'INT(4)', default: 0},
                       {name: 'nice_error', type: 'INT(4)', default: 0},
                       {name: 'ned_update', type: 'INT(4)', default: 0},
                       {name: 'not_found_in_db', type: 'INT(4)', default: 0},
                       {name: 'new_effective_from', type: 'INT(4)', default: 0}, # Whether create new or update Rate
                       {name: 'id', type: 'INT(11)', inscrement: ' NOT NULL auto_increment '},
                       {name: 'destination_id', type: 'INT(11)', default: 0},
                       {name: 'destination_group_id', type: 'INT(11)', default: 0},
                       {name: 'destination_name', type: 'VARCHAR(255)', default: ''},
                       {name: 'original_destination_name', type: 'VARCHAR(255)', default: ''}]
    CsvImportDb.load_csv_into_db(tname, sep, dec, fl, path, colums)
  end

  def analize_file(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV analize_file #{name}", 1)
    imp_change = options[:imp_change]
    change = 'AND ' + 'col_' + imp_change.to_s + " != 'DELETE'" if imp_change.to_i > -1
    arr = {}
    arr[:destinations_in_csv_file] = (ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}").to_i - 1).to_s if ActiveRecord::Base.connection.tables.include?(name)
    # arr[:rates_to_update] = Rate.count(:all, :conditions => ['tariff_id = ?', id], :joins => "JOIN destinations ON (rates.destination_id = destinations.id) JOIN #{name} ON (destinations.prefix = col_#{options[:imp_prefix]})")
    arr[:tariff_rates] = Rate.where(tariff_id: id).all.size

    if options[:imp_effective_from].present?
      str = " AND IFNULL(rates.effective_from, '') = CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      str2 = ", col_#{options[:imp_effective_from]}"

      # Formats similiar to '06-01' cannot be interpreted by SQL Date parser, so the mentioned fields have to be
      # pre-parsed by Ruby.
      rows = ActiveRecord::Base.connection.select_all("SELECT id, col_#{options[:imp_effective_from]} AS effective_from FROM #{name} WHERE (length(col_#{options[:imp_effective_from]}) = 5 AND LEFT(col_#{options[:imp_effective_from]}, 3) = '#{options[:date_format][2]}')")
      current_time = Date.current.to_time
      row_updates = []
      rows.each do |row|
        begin
          effective_from_date = row['effective_from']
          effective_from_date = Time.parse(effective_from_date.gsub('-', '/'), current_time).strftime("#{options[:date_format]}")
          row_updates << "UPDATE #{name} SET col_#{options[:imp_effective_from]} = '#{effective_from_date}' WHERE id = #{row['id']}"
        rescue => exception
          # Do nothing.
        end
      end

      # Additionally time format containing dots (.) will be converted into colons (:)
      rows = ActiveRecord::Base.connection.select_all("
        SELECT id,
               col_#{options[:imp_effective_from]} AS effective_from
        FROM #{name}
        WHERE (
               LOCATE('.', SUBSTRING_INDEX(col_#{options[:imp_effective_from]}, ' ', -1)) > 0
               AND SUBSTRING_INDEX(col_#{options[:imp_effective_from]}, ' ', -1) != col_#{options[:imp_effective_from]}
              )
      ")
      rows.each do |row|
        begin
          effective_from = row['effective_from']
          effective_from_splitted = effective_from.split(' ')
          if effective_from_splitted.size == 2
            effective_from = effective_from_splitted[0] + ' ' + effective_from_splitted[1].gsub('.', ':')
          end

          row_updates << "UPDATE #{name} SET col_#{options[:imp_effective_from]} = '#{effective_from}' WHERE id = #{row['id']}"
        rescue
          # Do nothing. (Skip one failed row).
        end
      end
      ActiveRecord::Base.transaction{row_updates.each {|update| ActiveRecord::Base.connection.execute(update)}}
      # CEIL MINUTES
      minutes_sql = "UPDATE #{name} SET col_#{options[:imp_effective_from]} = FROM_UNIXTIME(CEIL(UNIX_TIMESTAMP(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'))/60)*60, '#{options[:date_format]}')"
      minutes_where = "WHERE STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}') IS NOT NULL AND STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}') != '0000-00-00 00:00:00'"
      ActiveRecord::Base.connection.execute("#{minutes_sql} #{minutes_where}")
    else
      str = ' AND rates.effective_from IS NULL'
      str2 = ''
    end

    #  EXCEPTION!!! Since #13397 a setting to ignore the time part has been added.
    #    It allows to match effective from only by date part.
    effective_from_index = options[:imp_effective_from]
    effective_from_manual = options[:manual_effective_from]
    ignore_effective_from_time = options[:ignore_effective_from_time] == 1

    # If effective from is imported straight from the file
    if effective_from_index.present?
      effective_from_column = ', effective_from'
      # If time is ignored do not perform time operations
      effective_from_value =
        if ignore_effective_from_time
          "col_#{effective_from_index}"
        else
          "CONVERT_TZ(STR_TO_DATE(col_#{effective_from_index}, '#{options[:date_format]}'),"\
            " '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
        end
      effective_from_field = ", #{effective_from_value}"
    # If effective from datetime dropdown is selected or default
    elsif effective_from_manual.present?
      effective_from_column = ', effective_from'
      effective_from_value = "'#{effective_from_manual}'"
      effective_from_field = ", #{effective_from_value}"
    end

    effective_from_value = "''" if effective_from_value.blank?

    # Composes effective from matching conditions
    effective_from_condition = ''
    effective_from_condition_identical = ''

    if effective_from_value.present?
      # If time is ignored string only the date part
      if ignore_effective_from_time
        effective_from_condition = "AND (DATE(rates.effective_from) != DATE(#{effective_from_value})"\
          ' OR rates.effective_from IS NULL)'
        effective_from_condition_identical = "AND DATE(rates.effective_from) = DATE(#{effective_from_value})"
      else
        effective_from_condition = "AND (rates.effective_from != #{effective_from_value} OR "\
          'rates.effective_from IS NULL)'
        effective_from_condition_identical = "AND rates.effective_from = #{effective_from_value}"
      end
    end

    # Transform prefixes which stating with '+'
    if ActiveRecord::Base.connection.tables.include?(name)
      retry_lock_error(3) {
        ActiveRecord::Base.connection.execute("
          UPDATE #{name}
          SET col_#{options[:imp_prefix]} = SUBSTR(col_#{options[:imp_prefix]}, 2)
          WHERE col_#{options[:imp_prefix]} LIKE '+%'
          AND f_error = 0
        ")
      }
    end

    # set error flag on not rates if Effective_from is not datetime | code : 16
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 16 WHERE STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}') IS NULL OR STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}') = '0000-00-00 00:00:00'") if ActiveRecord::Base.connection.tables.include?(name) and options[:imp_effective_from].present?

    str3 = str2.present? ? "WHERE col_#{options[:imp_effective_from]} != ''" : ''
    # set error flag on duplicates | code : 12
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 12 WHERE f_error = 0 AND col_#{options[:imp_prefix]} IN (SELECT prf FROM (SELECT col_#{options[:imp_prefix]} AS prf, count(*) AS u FROM #{name} #{str3} GROUP BY col_#{options[:imp_prefix]}#{str2}  HAVING u > 1) AS imf )") if ActiveRecord::Base.connection.tables.include?(name)
       # Set error flag on DELETE action | code : 18
       if imp_change.to_i > -1
         if ActiveRecord::Base.connection.tables.include?(name)
           retry_lock_error(3) {
             ActiveRecord::Base.connection.execute("
               UPDATE #{name}
               SET f_error = 1, nice_error = 18
               WHERE col_#{options[:imp_prefix]} NOT IN (SELECT prefix FROM rates WHERE tariff_id = #{id})
               AND col_#{options[:imp_change]} = 'DELETE'
               AND f_error = 0
               ")
           }
         end
       end
    # set error flag on not int prefixes | code : 13
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 13 WHERE col_#{options[:imp_prefix]} REGEXP '^[0-9]+$' = 0 AND f_error = 0") if ActiveRecord::Base.connection.tables.include?(name)

    # set error flag on bad formated rates | code : 17
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET col_#{options[:imp_rate]} = -1 WHERE col_#{options[:imp_rate]} REGEXP '^blocked$' = 1")   if ActiveRecord::Base.connection.tables.include?(name)
    ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 17 WHERE col_#{options[:imp_rate]} REGEXP '^-?[0-9]+$|^-?[0-9]+[;,.][0-9]+$' = 0 AND f_error = 0")   if ActiveRecord::Base.connection.tables.include?(name)
    # SET error for invalid block/unblock values

    if options[:imp_blocked].to_i > -1
      ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 19 WHERE LOWER(col_#{options[:imp_blocked]}) REGEXP '^(block|unblock|blocked|unblocked)$' = 0 AND col_#{options[:imp_blocked]} != '' AND f_error = 0 AND id != 1") if ActiveRecord::Base.connection.tables.include?(name)
    end

    # SET error for invalid increment value
    if options[:imp_increment_s].to_i > -1 && ActiveRecord::Base.connection.tables.include?(name)
      ActiveRecord::Base.connection.execute("
        UPDATE #{name} SET f_error = 1, nice_error = 20
        WHERE col_#{options[:imp_increment_s]} < 1 AND col_#{options[:imp_increment_s]} != '' AND f_error = 0 AND id != 1
      ")
    end

    # SET error for invalid min_time value
    if options[:imp_min_time].to_i > -1 && ActiveRecord::Base.connection.tables.include?(name)
      ActiveRecord::Base.connection.execute("
        UPDATE #{name} SET f_error = 1, nice_error = 21
        WHERE col_#{options[:imp_min_time]} < 0 AND col_#{options[:imp_min_time]} != '' AND f_error = 0 AND id != 1
      ")
    end

    if options[:imp_cc] != -1
      # set error flag where country_code is not found in DB | code : 11
      # ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN directions ON (col_#{options[:imp_cc]} = directions.code) SET f_error = 1, nice_error = 11 WHERE directions.id IS NULL AND f_error = 0")      if ActiveRecord::Base.connection.tables.include?(name)
    end

    if ActiveRecord::Base.connection.tables.include?(name)
      # ticket #5808 -> since now we dont check for time collisions,
      # just import anything if posible. else user will be notified
      # in the last step about rates that was not posible to import
      # due to time collision.
      day_type = ['wd', 'fd',].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : ''
      start_time = options[:imp_time_from_type]
      end_time = options[:imp_time_till_type]
      ActiveRecord::Base.connection.execute("UPDATE #{name} " +
        "JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition_identical}) JOIN ratedetails ON (ratedetails.rate_id = rates.id) " +
        'SET f_error = 1, nice_error = 15 ' +
        "WHERE rates.tariff_id = '#{id}' AND CASE " +
        "WHEN daytype = '#{day_type}' AND start_time = '#{start_time}' AND end_time = '#{end_time}' THEN 0 " +
        "WHEN '#{day_type}' IN ('WD', 'FD') AND daytype IN ('WD', 'FD') AND daytype != '#{day_type}' THEN 0 " +
        "WHEN (daytype = '' AND '#{day_type}' != '') OR (daytype IN ('WD', 'FD') AND '#{day_type}' NOT IN ('WD', 'FD')) THEN 1 " +
        "ELSE ('#{start_time}' BETWEEN start_time AND end_time) OR ('#{end_time}' BETWEEN start_time AND end_time) OR (start_time BETWEEN '#{start_time}' AND '#{end_time}') OR (end_time BETWEEN '#{start_time}' AND '#{end_time}') " +
        'END != 0')
    end

    # Set new_effective_from if Rate was found, but with not identical Effective From
    if ActiveRecord::Base.connection.tables.include?(name)
      ActiveRecord::Base.connection.execute("
        UPDATE #{name}
        JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition})
        SET new_effective_from = 1
        WHERE rates.tariff_id = #{id}
      ")
    end


    if options[:imp_update_dest_names].to_i == 1 and options[:imp_dst] >= 0
      # set flag on destination name update
      ActiveRecord::Base.connection.execute("UPDATE #{name} join destinations on (col_#{options[:imp_prefix]} = destinations.prefix) SET ned_update = 1 WHERE TRIM(col_#{options[:imp_dst]}) != '' AND (BINARY replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != IFNULL(original_destination_name,destinations.name) OR destinations.name IS NULL)") if ActiveRecord::Base.connection.tables.include?(name)
    end

    # set flag not_found_in_db
    ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix) SET not_found_in_db = 1 WHERE destinations.id IS NULL AND f_error = 0") if ActiveRecord::Base.connection.tables.include?(name)

    # set destination_id if found in DB
    ActiveRecord::Base.connection.execute("UPDATE #{name} LEFT JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix) SET #{name}.destination_id = destinations.id, #{name}.destination_group_id = destinations.destinationgroup_id, #{name}.destination_name = destinations.name WHERE not_found_in_db = 0 AND f_error = 0") if ActiveRecord::Base.connection.tables.include?(name)

    # set flags
    self.csv_import_prefix_analize(name, options) if ActiveRecord::Base.connection.tables.include?(name)
    if ActiveRecord::Base.connection.tables.include?(name)
      begin
        CsvImportDb.create_index_for_prefix(name, options[:imp_prefix])
      rescue
        MorLog.my_debug("Tariff import analysis window refreshed on #{name}", 1)
      end
    end
    if options[:imp_update_directions].to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE #{name} join directions on (col_#{options[:imp_cc]} = directions.code) join destinations on (col_#{options[:imp_prefix]} = destinations.prefix) SET ned_update = ned_update + 4 WHERE destinations.direction_code != directions.code")   if ActiveRecord::Base.connection.tables.include?(name)
    end
    if ActiveRecord::Base.connection.tables.include?(name)
      # Number of high rates (for generating a warning).
      high_rate = options[:high_rate].to_f
      # Rate comparison condition (converts into valid decimal format)
      cmp_cond = SqlExport.cmp_rates(options[:imp_rate], options[:dec], high_rate)
      # Need not check if zero
      unless high_rate.zero?
        arr[:high_rates] = ActiveRecord::Base.connection.select_value(
          "SELECT COUNT(*) FROM #{name} WHERE #{cmp_cond} AND f_error = 0"
        ).to_i
      end
      arr[:bad_destinations] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 1").to_i
      arr[:destinations_to_update] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) AS d_all FROM #{name} WHERE ned_update IN (1, 3, 5, 7)").to_i if options[:imp_update_dest_names].to_i == 1 and options[:imp_dst] >= 0
      arr[:destinations_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_error = 0 AND not_found_in_db = 1").to_i
      arr[:new_rates_to_create] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) AS r_all FROM #{name} LEFT JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix and rates.tariff_id = #{id}) WHERE f_error = 0 AND rates.id IS NULL #{change}").to_i
      arr[:new_destinations_in_csv_file] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE not_found_in_db = 1").to_i
      arr[:rates_to_update] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM (select prefix from rates WHERE tariff_id = #{id} GROUP BY prefix) as rates_new JOIN #{name} ON (col_#{options[:imp_prefix]} = rates_new.prefix) AND f_error = 0 AND not_found_in_db = 0 #{change}")
      arr[:zero_rates] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE col_#{options[:imp_rate]} #{SqlExport.is_zero_condition}").to_i
    end
    arr[:rates_to_delete] = 0
    if options[:imp_delete_unimported_prefix_rates].to_i == 1
      all_tariff_rates = Rate.where(tariff_id: self.id)
      tariff_rates_count = all_tariff_rates.count
      imported_rates = all_tariff_rates
                            .joins("INNER JOIN #{name} ON rates.prefix = #{name}.col_#{options[:imp_prefix]} AND f_error = 0")
                            .count
      arr[:rates_to_delete] = tariff_rates_count - imported_rates
    end
    if imp_change.to_i > -1
      imported_rates_to_delete =
         ActiveRecord::Base.connection.select_value("
           SELECT DISTINCT COUNT(*) AS count
           FROM #{name}
          INNER JOIN rates ON rates.prefix = #{name}.col_#{options[:imp_prefix]}
           WHERE f_error = 0
                 AND #{name}.col_#{imp_change} = 'DELETE'
                 AND tariff_id = #{id}
          ").to_i
      arr[:rates_to_delete] += imported_rates_to_delete
    end
    arr
  end

  def create_deatinations(name, options, _options2)
    CsvImportDb.log_swap('create_destinations_start')
    MorLog.my_debug("CSV create_deatinations #{name}", 1)
    count = 0
    sql = []; ss = []; cc = ''; group_by = []

    ['prefix', 'direction_code', 'name'].each { |col|
      if !options["imp_#{col}".to_sym].blank? and options["imp_#{col}".to_sym].to_i > -1 or ['direction_code'].include?(col)
        case col
          when 'prefix'
            prefix_col = "col_#{(options["imp_#{col}".to_sym])}"
            sql << prefix_col; group_by << prefix_col
          when 'direction_code'
            sbg = 'short_prefix'
            cc << (options[:imp_cc].to_i >= 0 ? "IF(col_#{options[:imp_cc]} IN (SELECT code FROM directions),col_#{options[:imp_cc]},#{sbg})" : "#{sbg}")
            sql << "#{cc}"
          else
            sql << 'col_' + (options["imp_#{col}".to_sym]).to_s
        end
        ss << col
      elsif col == 'name'
        ss << 'name'
        if options[:imp_dst].present? and options[:imp_dst].to_i > -1
          sql << "IF(col_#{options[:imp_dst].to_s} = '',
                CONCAT((SELECT name FROM directions WHERE code = #{sql[1]} LIMIT 1)) ,
                col_#{options[:imp_dst].to_s})"
        else
          sql << " #{name}.destination_name "
        end
      end
    }

    s2 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1").to_i
    num = s2/1000 + 1
    num.times { |index|
      in_rd = "INSERT INTO destinations (#{ss.join(',')})
                SELECT #{sql.join(',')} FROM #{name}
                WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1 #{"GROUP BY #{group_by.join(' ')}" if group_by.present?} LIMIT #{index * 1000}, 1000"
      begin
        Confline.set_value('Destination_create', 1, User.current.id)
        ActiveRecord::Base.connection.execute(in_rd)
        count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 1 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{index * 1000}, 100000").to_i
      ensure
        Confline.set_value('Destination_create', 0, User.current.id)
      end
    }

    if options[:imp_cc] >= 0
      s3 = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1").to_i
      num = s3 / 1000 + 1
      num.times { |index|
        n_rd = "INSERT INTO destinations (#{ss.join(',')})
                  SELECT #{sql.join(',')} FROM #{name}
                  WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1 #{"GROUP BY #{group_by.join(' ')}" if group_by.present?} LIMIT #{index * 1000}, 1000"
        begin
          Confline.set_value('Destination_create', 1, User.current.id)
          ActiveRecord::Base.connection.execute(n_rd)
          count += ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE f_country_code = 0 AND f_error = 0 AND not_found_in_db = 1 LIMIT #{index * 1000}, 1000").to_i
        ensure
          Confline.set_value('Destination_create', 0, User.current.id)
        end
      }
    end
    CsvImportDb.log_swap('create_destinations_end')
    return count
  end

  def update_destinations(name, options, _options2)
    CsvImportDb.log_swap('update_destinations_start')
    MorLog.my_debug("CSV update_destinations #{name}", 1)
    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name} WHERE ned_update IN (1, 3, 5, 7)").to_i

    sql = 'UPDATE destinations' +
        " JOIN #{name} ON (col_#{options[:imp_prefix]} = destinations.prefix) " +
        "SET name = replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') " +
        "WHERE ned_update IN (1, 3, 5, 7) AND replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != ''"
    ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('update_destinations_end')
    return count
  end

  def update_rates_from_csv(name, options, _options2)
    CsvImportDb.log_swap('update_rates_from_csv_start')
    MorLog.my_debug("CSV update_rates_from_csv #{name}", 1)
    # bad_prefix_sql = options2[:bad_destinations].to_i > 0 ? "AND col_#{options[:imp_prefix]} NOT IN (#{options2[:bad_prefixes].join(',')})" : ''
    %w[wd fd].include?(options[:imp_date_day_type].to_s) ? day_type = options[:imp_date_day_type].upcase : day_type = ''
    type_sql = day_type.blank? ? '' : " AND ratedetails.daytype = '#{day_type}' "

    imp_change = options[:imp_change]
    change = 'AND ' + 'col_' + imp_change.to_s + " != 'DELETE'" if imp_change.to_i > -1

    manual_connection_fee = options[:manual_connection_fee]
    manual_increment = options[:manual_increment]
    manual_min_time = options[:manual_min_time]

    if manual_connection_fee && manual_connection_fee.present?
      conection_fee = manual_connection_fee
    elsif options[:imp_connection_fee].present? and options[:imp_connection_fee].to_i > -1
      conection_fee = "replace(col_#{options[:imp_connection_fee]}, '#{options[:dec]}', '.')"
    else
      conection_fee = 'connection_fee'
    end

    if manual_increment && manual_increment.present?
      increment_s = manual_increment
    elsif options[:imp_increment_s].present? and options[:imp_increment_s].to_i > -1
      increment_s = "if(col_#{options[:imp_increment_s]} < 1,1,col_#{options[:imp_increment_s]})"
    else
      increment_s = 'increment_s'
    end

    if manual_min_time && manual_min_time.present?
      min_time = manual_min_time
    elsif options[:imp_min_time].present? and options[:imp_min_time].to_i > -1
      min_time = "col_#{options[:imp_min_time]}"
    else
      min_time = 'min_time'
    end

    if options[:manual_ghost_percent] && options[:manual_ghost_percent].present?
      ghost_percent = options[:manual_ghost_percent]
    elsif options[:imp_ghost_percent].present? and options[:imp_ghost_percent].to_i > -1
      ghost_percent = "col_#{options[:imp_ghost_percent]}"
      ghost_percent = "IF(#{ghost_percent} REGEXP '^[[:digit:].]+$', #{ghost_percent}, 0)"
    else
      ghost_percent = 'NULL'
    end

    blocked = if options[:imp_blocked] && options[:imp_blocked].to_i > -1
                "IF(col_#{options[:imp_blocked]} != '', IF(LOWER(col_#{options[:imp_blocked]}) = 'blocked' OR LOWER(col_#{options[:imp_blocked]}) = 'block', 1, 0), blocked)"
              else
                "IF(col_#{options[:imp_rate]} = -1, 1, 'blocked')"
              end

    #  EXCEPTION!!! Since #13397 a setting to ignore the time part has been added.
    #    It allows to match effective from only by date part.
    effective_from_index = options[:imp_effective_from]
    effective_from_manual = options[:manual_effective_from]
    ignore_effective_from_time = options[:ignore_effective_from_time] == 1

    # If effective from is imported straight from the file
    if effective_from_index.present?
      effective_from_column = ', effective_from'
      # If time is ignored do not perform time operations
      effective_from_value =
        if ignore_effective_from_time
          "col_#{effective_from_index}"
        else
          "CONVERT_TZ(STR_TO_DATE(col_#{effective_from_index}, '#{options[:date_format]}'),"\
            " '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
        end
      effective_from_field = ", #{effective_from_value}"
    # If effective from datetime dropdown is selected or default
    elsif effective_from_manual.present?
      effective_from_column = ', effective_from'
      effective_from_value = "'#{effective_from_manual}'"
      effective_from_field = ", #{effective_from_value}"
    end

    # Composes an effective from matching condition
    effective_from_condition =
      if effective_from_value.present?
        # If time is ignored string only the date part
        if ignore_effective_from_time
          "AND DATE(rates.effective_from) = DATE(#{effective_from_value})"
        else
          "AND rates.effective_from = #{effective_from_value}"
        end
      end

    if options[:imp_prefix].present? && options[:imp_prefix].to_i > -1
      prefix = "col_#{options[:imp_prefix]}"
    end

    rate_name_update = if options[:imp_update_dest_names].to_i == 1 && options[:imp_dst].present? && options[:imp_dst].to_i > -1
                          "IF(replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != '', replace(TRIM(col_#{options[:imp_dst]}), '  ', ' '), IF(destinations.name = '', destination_name, destinations.name))"
                        else
                          'IF(destinations.name = \'\', destination_name, destinations.name)'
                        end

    # count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM (select destination_id, tariff_id from rates GROUP BY destination_id, tariff_id) as rates_new join destinations ON (destinations.id = rates_new.destination_id) JOIN #{name} ON (replace(col_#{options[:imp_prefix]}, '\\r', '') = destinations.prefix) where rates_new.tariff_id = #{id} AND f_error = 0 AND not_found_in_db = 0")

    # If Rate needs to be updated and it does not have any RateDetail at all, then default one will be created
    rates_without_ratedetails = ActiveRecord::Base.connection.select_values(
        "SELECT rates.id AS rate_id
         FROM rates
         JOIN #{name} ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition})
         LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
         WHERE rates.tariff_id = #{id}
               AND f_error = 0
               AND not_found_in_db = 0
               AND ratedetails.id IS NULL"
    )
    rates_without_ratedetails.each { |rate_id| Ratedetail.create(rate_id: rate_id) }

     # Used To update rates with Existing prefixes and EXISTING effective from's
     sql = "UPDATE ratedetails, (SELECT rates.id AS nrate_id, #{name}.* FROM rates JOIN #{name} ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition.to_s}) where rates.tariff_id = #{id} AND f_error = 0 AND not_found_in_db = 0) AS temp
              SET ratedetails.rate = replace(replace(replace(col_#{options[:imp_rate]}, '#{options[:dec]}', '.'), '$', ''), ',', '.'),
                  ratedetails.connection_fee = #{conection_fee},
                  increment_s = #{increment_s},
                  min_time = #{min_time},
                  blocked = #{blocked}
              WHERE ratedetails.rate_id = nrate_id #{type_sql} AND start_time = '#{options[:imp_time_from_type]}' AND end_time = '#{options[:imp_time_till_type]}'"
    rates_updated = ActiveRecord::Base.connection.update(sql)

     # Used To Prevent From Adding Rates With same prefix, and EFFECTIVE FROM, since managing it in Insert Query would require some serious computation and would take more time
     # Sets In Update Used Prefixes to NULL, So they wouldn't get created again.
     sql = "UPDATE rates JOIN #{name} ON (col_#{options[:imp_prefix]} = rates.prefix #{effective_from_condition})
             SET col_#{options[:imp_prefix]} = NULL
             where rates.tariff_id = #{id} AND f_error = 0 AND not_found_in_db = 0"

    ActiveRecord::Base.connection.update(sql) if rates_updated > 0

    rate_names_column = ', name'
    rate_name = if options[:imp_dst].present? && options[:imp_dst].to_i > -1
                  ", IF(replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != '', replace(TRIM(col_#{options[:imp_dst]}), '  ', ' '), destination_name)"
                else
                  ', destination_name'
                end

    sql = "INSERT INTO rates (tariff_id, destination_id, ghost_min_perc, prefix #{effective_from_column}, destinationgroup_id)
      SELECT #{id}, #{name}.destination_id, #{ghost_percent}, TRIM(#{prefix}) #{effective_from_field}, #{name}.destination_group_id  FROM #{name}
      JOIN (select prefix from rates where tariff_id = #{id} GROUP BY prefix) as rates_new  ON (col_#{options[:imp_prefix]} = rates_new.prefix)
      WHERE f_error = 0 AND new_effective_from = 1 #{change}"
    rates_created = retry_lock_error(3) { ActiveRecord::Base.connection.update(sql) }
    CsvImportDb.log_swap('update_rates_from_csv_end')
    return rates_created + rates_updated
  end

  def create_rates_from_csv(name, options, _options2)
    CsvImportDb.log_swap('create_rates_from_csv_start')
    MorLog.my_debug("CSV create_rates_from_csv #{name}", 1)
    imp_change = options[:imp_change]
    change = 'AND ' + 'col_' + imp_change.to_s + " != 'DELETE'" if imp_change.to_i > -1

    if options[:imp_effective_from].present?
      effective_from_column = ', effective_from'
      effective_from_value = ", CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
    elsif options[:manual_effective_from].present?
      effective_from_column = ', effective_from'
      effective_from_value = ",'#{options[:manual_effective_from]}'"
    end

    if options[:manual_ghost_percent] and options[:manual_ghost_percent].present?
      ghost_percent = options[:manual_ghost_percent]
    elsif options[:imp_ghost_percent].present? and options[:imp_ghost_percent].to_i > -1
      ghost_percent = "col_#{options[:imp_ghost_percent]}"
      ghost_percent = "IF(#{ghost_percent} REGEXP '^[[:digit:].]+$', #{ghost_percent}, 0)"
    else
      ghost_percent = 'NULL'
    end

    if options[:imp_prefix].present? && options[:imp_prefix].to_i > -1
      prefix = "col_#{options[:imp_prefix]}"
    end

    rate_name = if options[:imp_dst].present? && options[:imp_dst].to_i > -1
                  ", IF(replace(TRIM(col_#{options[:imp_dst]}), '  ', ' ') != '', replace(TRIM(col_#{options[:imp_dst]}), '  ', ' '), destination_name)"
                else
                  ', destination_name'
                end

    destination_id_column = options[:imp_dst].to_i < 0 ? "#{name}.destination_id " : 'destinations.id '
    destination_group_id_column = options[:imp_dst].to_i < 0 ? "#{name}.destination_group_id " : 'destinations.destinationgroup_id '

    sql = "INSERT INTO rates (tariff_id, destination_id, ghost_min_perc, prefix #{effective_from_column}, destinationgroup_id)
    SELECT #{id}, destinations.id, #{ghost_percent}, TRIM(#{prefix}) #{effective_from_value}, #{destination_group_id_column} FROM #{name}
    JOIN destinations ON (col_#{options[:imp_prefix]} = destinations.prefix)
    LEFT JOIN rates ON (col_#{options[:imp_prefix]} = rates.prefix AND rates.tariff_id = #{id})
    WHERE rates.id IS NULL AND f_error = 0 #{change}"

    rates_created_count = ActiveRecord::Base.connection.update(sql)
    CsvImportDb.log_swap('create_rates_from_csv')

    return rates_created_count
  end

  def insert_ratedetails(name, options, _options2)
    CsvImportDb.log_swap('insert_ratedetails_start')
    MorLog.my_debug("CSV insert_ratedetails #{name}", 1)

    imp_change = options[:imp_change]
    change = 'AND ' + 'col_' + imp_change.to_s + " != 'DELETE'" if imp_change.to_i > -1

    s = []
    ss = []
    collums = %w[rate increment_s min_time connection_fee daytype blocked]
    collums.each do |col|
      case col
        when 'blocked'
          if options[:imp_blocked] && options[:imp_blocked].to_i > -1
            s1 = "IF(LOWER(col_#{options[:imp_blocked]}) = 'blocked' OR LOWER(col_#{options[:imp_blocked]}) = 'block', 1, 0)"
          else
            s1 = "IF(col_#{options[:imp_rate]} = -1, 1, 0)"
          end
        when 'daytype'
          ['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? day_type = options[:imp_date_day_type].upcase : day_type = ''
          s1 = day_type.blank? ? "''" : " '#{day_type.to_s}' "
        when 'connection_fee'
          if options[:manual_connection_fee] && options[:manual_connection_fee].present?
            s1 = options[:manual_connection_fee]
          elsif options[:imp_connection_fee].present? && options[:imp_connection_fee].to_i > -1
            s1 = "replace(col_#{options[:imp_connection_fee]}, '#{options[:dec]}', '.')"
          else
            s1 = 0
          end
        when 'increment_s'
          if options[:manual_increment] && options[:manual_increment].present?
            s1 = options[:manual_increment]
          elsif options[:imp_increment_s].present? && options[:imp_increment_s].to_i > -1
            s1 = "if(col_#{options[:imp_increment_s]} < 1,1,col_#{options[:imp_increment_s]})"
          else
            s1 = 1
          end
        when 'min_time'
          if options[:manual_min_time] && options[:manual_min_time].present?
            s1 = options[:manual_min_time]
          elsif options[:imp_min_time].present? && options[:imp_min_time].to_i > -1
            s1 = "col_#{options[:imp_min_time]}"
          else
            s1 = 0
          end
        when 'rate'
          s1 = "replace(replace(replace(col_#{options[:imp_rate]}, '#{options[:dec]}', '.'), '$', ''), ',', '.')"
        else
          s1 = 'col_' + (options["imp_#{col}".to_sym]).to_s
      end
      s << s1
      ss << col
    end
    # ticket #4845. im not joining ratedetails based only on rate_id table cause it might return more than
    # 1 row for each rate and in that case multiple new rates might be imported. Instead im joining on rate_id,
    # daytype, start/end time to exclude rate details that has to be updated, not inserted as new.
    # Note that i'm relying 100% that checks were made to ensure that after inserting new ratedetails there cannot
    # be any duplications,  we should pray for that.

    if options[:imp_effective_from].present? # effective_from imported straight from file
      effective_from_column = ', effective_from'
      effective_from_value = "CONVERT_TZ(STR_TO_DATE(col_#{options[:imp_effective_from]}, '#{options[:date_format]}'), '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
      effective_from_field = ", #{effective_from_value}"
    elsif options[:manual_effective_from].present? # effective_from datetime dropdown select or default
      effective_from_column = ', effective_from'
      effective_from_value = "'#{options[:manual_effective_from]}'"
      effective_from_field = ", #{effective_from_value}"
    end
    effective_from_value = "''" if effective_from_value.blank?
    effective_from_condition = effective_from_value.present? ? "AND rates.effective_from = #{effective_from_value}" : ''

    count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{name}
    join rates on (col_#{options[:imp_prefix]} = rates.prefix AND rates.tariff_id = #{id} #{effective_from_condition})
    left join ratedetails on (ratedetails.rate_id = rates.id AND ratedetails.daytype = '#{(['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : '')}' AND ratedetails.start_time = '#{options[:imp_time_from_type]}' AND ratedetails.end_time = '#{options[:imp_time_till_type]}')
WHERE ratedetails.id IS NULL AND f_error = 0 #{change}")

    in_rd = "INSERT INTO ratedetails (rate_id, start_time, end_time, #{ss.join(',')})
    SELECT DISTINCT(rates.id), '#{options[:imp_time_from_type]}', '#{options[:imp_time_till_type]}', #{s.join(',')} FROM #{name}
    join rates on (col_#{options[:imp_prefix]} = rates.prefix AND rates.tariff_id = #{id} #{effective_from_condition})
    left join ratedetails on (ratedetails.rate_id = rates.id AND ratedetails.daytype = '#{(['wd', 'fd'].include?(options[:imp_date_day_type].to_s) ? options[:imp_date_day_type].to_s : '')}' AND ratedetails.start_time = '#{options[:imp_time_from_type]}' AND ratedetails.end_time = '#{options[:imp_time_till_type]}')
    WHERE ratedetails.id IS NULL AND f_error = 0 #{change}"

    retry_lock_error(3) { ActiveRecord::Base.connection.execute(in_rd) }
    CsvImportDb.log_swap('insert_ratedetails_end')
    return count
  end

  def delete_unimported_rates(name, options)
    prefix_loc = "col_#{options[:imp_prefix]}"

    # we need rate_id to delete ratedetails, to delete it by one query, because deletint one by one takes too much time
    rates_to_delete = value_not_present_in_importable_file(name, prefix_loc, 'id')
    rates_to_delete_string = rates_to_delete.join("','")
    prefixes_to_delete = value_not_present_in_importable_file(name, prefix_loc, 'prefix').join("','")
    delete_by(prefixes_to_delete, rates_to_delete_string)

    rates_to_delete.size
  end

  def delete_by_action(name, options)
    prefix_loc = "col_#{options[:imp_prefix]}"
    change_action = "col_#{options[:imp_change]}"

    rates_to_delete = value_to_delete_in_action(name, prefix_loc, 'id', change_action)
    rates_to_delete_string = rates_to_delete.join("','")
    prefixes_to_delete = value_to_delete_in_action(name, prefix_loc, 'prefix', change_action).join("','")
    delete_by(prefixes_to_delete, rates_to_delete_string)

    rates_to_delete.size
  end

  def delete_by_effective_from(name, options)
    prefix_loc = "col_#{options[:imp_prefix]}"

    rates_to_delete = value_to_delete_effective_from(name, prefix_loc, 'id', options)
    rates_to_delete_string = rates_to_delete.join("','")
    sql_to_delete_rates = "DELETE FROM rates WHERE id IN ('#{rates_to_delete_string}') AND tariff_id = #{id}"
    sql_to_delete_ratedetails = "DELETE FROM ratedetails WHERE rate_id IN ('#{rates_to_delete_string}')"

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(sql_to_delete_rates)
      ActiveRecord::Base.connection.execute(sql_to_delete_ratedetails)
    end

    rates_to_delete.size
  end

  def delete_by(prefixes_to_delete, rates_to_delete_string)
    sql_to_delete_rates = "DELETE FROM rates WHERE prefix IN ('#{prefixes_to_delete}') AND tariff_id = #{id}"
    sql_to_delete_ratedetails = "DELETE FROM ratedetails WHERE rate_id IN ('#{rates_to_delete_string}')"

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute(sql_to_delete_rates)
      ActiveRecord::Base.connection.execute(sql_to_delete_ratedetails)
    end
  end

  def Tariff.clean_after_import(tname, path = '/tmp/')
    CsvImportDb.clean_after_import(tname, path)
  end


  def csv_import_prefix_analize(name, options)
    MorLog.my_debug("CSV csv_import_prefix_analize #{name}", 1)

    # Retrieve direction_codes to hash
    direction_codes = {}
    res = ActiveRecord::Base.connection.select_all('SELECT direction_code, prefix FROM destinations;')
    res.each { |r| direction_codes[r['prefix']] = r['direction_code'] }

    # Collect already existing destinations
    destination_data = ActiveRecord::Base.connection.select_all('SELECT * FROM destinations')
    present_dsts = Hash[destination_data.map { |row| [row['prefix'].to_s.gsub(/\s/, ''), row] }]

    should_update_destination = options[:imp_dst].to_i < 0 # If false destination names will be gathered from file

    # 0 - empty line - skip
    # 1 - everything ok
    # 2 - cc(country_code) = usa
    # 3 - cc from csv
    # 4 - prefix from shorter prefix
    # ERRORS
    # 10 - no cc from csv - can't create destination
    # 11 - bad cc from csv - can't create destination
    # 12 - duplicate

    short_prefix = ''
    longest_maching_prefix = ''
    unique = ''
    bad = []

    new_destinations = ActiveRecord::Base.connection.select_all("SELECT *, #{name}.id AS i_id FROM #{name} WHERE not_found_in_db = 1 AND f_error = 0;")
    MorLog.my_debug("Use temp table : #{name}")

    config = Rails.configuration.database_configuration
    packed_destinations = {}
    update = {}
    imp_cc = options[:imp_cc]

    # Each prefix that was not found in DB is analysed
    new_destinations.each_with_index do |row, index|
      country_code = row["col_#{imp_cc}"].to_s # country_code
      if country_code.blank? || imp_cc == -1
        # If There is no country code in file or it's not selected, It search for longest maching prefix in database
        prefix = row["col_#{options[:imp_prefix]}"].to_s.strip.gsub(/\s/, '')
        pfound = 0
        plength = prefix.length
        j = 1
        while j < plength && pfound == 0
          tprefix = prefix[0, plength - j]
          pfound = 1 if present_dsts[tprefix].present?
          j += 1
        end

        if pfound == 1
          longest_maching_prefix = tprefix.to_s
          short_prefix = direction_codes[longest_maching_prefix]

          dest = present_dsts[longest_maching_prefix]

          if update[longest_maching_prefix].blank?
            update[longest_maching_prefix] = {}
            update[longest_maching_prefix][unique] = [row['i_id']]
          else
            if update[longest_maching_prefix][unique].blank?
              update[longest_maching_prefix][unique] = [row['i_id']]
            else
              update[longest_maching_prefix][unique] << row['i_id']
            end
          end

          update[longest_maching_prefix][:direction_code] = short_prefix
          update[longest_maching_prefix][:destination_group_id] = dest['destinationgroup_id'].to_i

          if should_update_destination # new destination will be created from file
            update[longest_maching_prefix][:destination_id] = dest['id'].to_i
            update[longest_maching_prefix][:name] = dest['name'].to_s
          end
        else
          bad << row['i_id']
        end
     end
      MorLog.my_debug(index.to_s + ' status/update_rate counted', 1) if index % 1000 == 0
    end

    update.each do |longest_prefix, values_object|
      values_object.except(:destination_id, :name, :destination_group_id, :direction_code).keys.each do |unique|
        table_count = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables WHERE table_schema = '#{config[Rails.env]['database']}' AND table_name = '#{name}' LIMIT 1")

        if table_count.first['a'] > 0
          # If destination name is not selected in file
          retry_lock_error(3) { ActiveRecord::Base.connection.execute(Tariff.generate_sql_for_update(update, longest_prefix, unique, name, should_update_destination)) }
        else
          flash[:notice] = _('Tariff_import_failed_please_try_again')
          (redirect_to controller: :tariffs, action: :list) && (return false)
        end
      end
    end

    if bad && bad.size.to_i > 0
      table_count = ActiveRecord::Base.connection.select_all("SELECT COUNT(*) AS a FROM information_schema.tables  WHERE table_schema = '#{config[Rails.env]['database']}' AND table_name = '#{name}' LIMIT 1")
      if table_count.first['a'] > 0
        # set error flag on not int prefixes | code : 13
        ActiveRecord::Base.connection.execute("UPDATE #{name} SET f_error = 1, nice_error = 10 WHERE id IN (#{bad.join(',')})")
      else
        flash[:notice] = _('Tariff_import_failed_please_try_again')
        (redirect_to controller: :tariffs, action: :list) && (return false)
      end
    end
  end

  def able_to_delete?
    # check for OP
    origination_points = Device.where(
      "((op_tariff_inter = #{id} OR op_tariff_indeter = #{id} OR op_tariff_intra = #{id}) AND us_jurisdictional_routing = 1)"\
      " OR op_tariff_id = #{id}"
    )

    opts = origination_points.count
    if opts > 0
      message = _("It_is_used_by_Origination_Points")
      message_content = []
      origination_points.each do |op|
        message_content << " <a href='#{Web_Dir}/devices/device_edit/#{op.id}'>#{op.nice_device_description_with_user}</a>"
      end
      message << message_content.join(',')
      errors.add(:origination_points_error, message)
    end
    # check for TP
    termination_points = Device.where(
      "((tp_tariff_inter = #{id} OR tp_tariff_indeter = #{id} OR tp_tariff_intra = #{id}) AND tp_us_jurisdictional_routing = 1)" \
      " OR tp_tariff_id = #{id}"
    )

    tpts = termination_points.count
    if tpts > 0
      message = _('It_is_used_by_Termination_Points')
      message_content = []
      termination_points.each do |tp|
        message_content << " <a href='#{Web_Dir}/devices/device_edit/#{tp.id}'>#{tp.nice_device_description_with_user}</a>"
      end
      message << message_content.join(',')
      errors.add(:termination_points_error, message)
    end
    # Check for Tariff Jobs
    if tariff_jobs.exists?
      errors.add(:tariff_jobs_exists, _('Assigned_Tariff_Jobs_exists'))
    end
    errors.messages.empty?
  end

  def self.tariff_name_validation(tariff_name, object)
    # name validation
    if tariff_name.blank?
      object.errors.add(:tariff_name_cannot_be_blank, _('tariff_name_cannot_be_blank'))
    elsif Tariff.pluck(:name).include?(tariff_name)
      object.errors.add(:tariff_name_must_be_unique, _('tariff_name_must_be_unique'))
    end
  end

  def self.tariff_profit_margin_validation(tariff_profit_margin, tariff_to_bg_task)
    # profit margin validation
    if tariff_profit_margin.blank?
      tariff_to_bg_task.errors.add(:tariff_profit_margin_cannot_be_blank, _('tariff_profit_margin_cannot_be_blank'))
    elsif not (/^-?[\d]+(\.[\d]+){0,1}$/ === tariff_profit_margin.sub(/[\,\.\;]/, '.'))
      tariff_to_bg_task.errors.add(:tariff_profit_margin_must_be_numerical, _('tariff_profit_margin_must_be_numerical'))
    elsif tariff_profit_margin.to_d > 200
      tariff_to_bg_task.errors.add(:tariff_profit_margin_cannot_be_higher, _('tariff_profit_margin_cannot_be_higher'))
    elsif tariff_profit_margin.to_d < -100
      tariff_to_bg_task.errors.add(:tariff_profit_margin_cannot_be_lower, _('tariff_profit_margin_cannot_be_lower'))
    end
  end

  def self.tariff_do_not_add_profit_margin_validation(tariff_profit_margin, tariff_to_bg_task)
    # profit margin validation
    if tariff_profit_margin.blank?
      tariff_to_bg_task.errors.add(:tariff_profit_margin_cannot_be_blank, _('Tariff_do_not_add_a_Profit_Margin_if_Rate_more_than_value_cannot_be_blank'))
    elsif not (/^-?[\d]+(\.[\d]+){0,1}$/ === tariff_profit_margin.sub(/[\,\.\;]/, '.'))
      tariff_to_bg_task.errors.add(:tariff_profit_margin_must_be_numerical, _('Tariff_do_not_add_a_Profit_Margin_if_Rate_more_than_value_must_be_numerical'))
    end
  end

  # generates sql for update destination_id, destination_group_id and destination_name fields in temp rates import table
  def self.generate_sql_for_update(update, s_prefix, unique, name, update_destination = true)
    all_id = update[s_prefix][unique].map { |id| id }.join ','
    base_update = "UPDATE #{name} SET f_country_code = 1, short_prefix = '#{update[s_prefix][:direction_code]}', destination_group_id = #{update[s_prefix][:destination_group_id]}"

    if update_destination # If update destination is false, information will be gathered from file
      destination_name = ActiveRecord::Base.connection.quote(update[s_prefix][:name])
      base_update += ", destination_id = #{update[s_prefix][:destination_id]}, destination_name = #{destination_name}"
    end

    base_update += " WHERE id IN (#{all_id})"
    base_update
  end

  # Retrieves high rates from a temporary import table
  def self.imp_high_rates(h_rate, opt)
    conn = ActiveRecord::Base.connection
    tabl = opt[:table]
    # Rate comparison condition (converts into valid decimal format)
    cond = SqlExport.cmp_rates(opt[:rate_col], opt[:dec], h_rate)

    return [] unless conn.tables.include?(tabl)
    conn.select("SELECT * FROM #{tabl} WHERE #{cond} AND f_error = 0")
  end

  def rate_total
    Rate.select(:id).where(tariff_id: self.id).count
  end

  def rate_total_user(custom_tariff_id = 0)
    condition = "rates.tariff_id = #{id}"
    condition = "(#{condition} OR rates.tariff_id = #{custom_tariff_id})" if custom_tariff_id != 0

    total_count_sql = "
      SELECT COUNT(*) FROM (
        SELECT id
        FROM (
              SELECT rates.id, rates.prefix, tariffs.purpose
              FROM rates
              LEFT JOIN tariffs ON rates.tariff_id = tariffs.id
              WHERE #{condition} AND (effective_from < NOW() OR effective_from IS NULL)
              ORDER BY rates.effective_from DESC, tariffs.purpose ASC, id DESC
        ) AS tmp_table_active
        GROUP BY prefix
      ) AS tmp_table_count
    "

    ActiveRecord::Base.connection.select_value(total_count_sql).to_i
  end

  def name_with_currency
    "#{name} (#{currency.to_s.upcase})"
  end

  def changes_present_set_1
    update_column(:changes_present, 1)
    update_column(:last_change_datetime, Time.now)
    #update_column(:last_change_datetime, nil)
  end

  def self.all_for_rate_notification_list(current_user)
    sql = "
    SELECT aggr_tariff_id, tariffs.name AS 'aggr_tariff_name',
           aggr_user_id, (IF(LENGTH(TRIM(CONCAT(users.first_name, ' ', users.last_name))) > 0, TRIM(CONCAT(users.first_name, ' ', users.last_name)), users.username)) AS 'aggr_user_nicename',
           CONCAT(aggr_tariff_id, '-', aggr_user_id) AS 'uniq_assoc',
           latest_rate_notification_jobs.created_at AS 'rnj_last_datetime',
           tariffs.last_change_datetime
    FROM (
          SELECT op_tariff_id AS 'aggr_tariff_id', user_id AS 'aggr_user_id'
          FROM devices
          WHERE op_tariff_id > 0
          UNION ALL
          SELECT op_match_tariff_id AS 'aggr_tariff_id', user_id AS 'aggr_user_id'
          FROM devices
          WHERE op_match_tariff_id > 0
          UNION ALL
          SELECT op_tariff_intra AS 'aggr_tariff_id', user_id AS 'aggr_user_id'
          FROM devices
          WHERE op_tariff_intra > 0
          UNION ALL
          SELECT op_tariff_inter AS 'aggr_tariff_id', user_id AS 'aggr_user_id'
          FROM devices
          WHERE op_tariff_inter > 0
          UNION ALL
          SELECT op_tariff_indeter AS 'aggr_tariff_id', user_id AS 'aggr_user_id'
          FROM devices
          WHERE op_tariff_indeter > 0
    ) AS tariff_users
    LEFT JOIN tariffs on tariffs.id = tariff_users.aggr_tariff_id
    LEFT JOIN users on users.id = tariff_users.aggr_user_id
    LEFT JOIN (
               SELECT tariff_id, user_id, MAX(created_at) AS 'created_at'
               FROM rate_notification_jobs
               GROUP BY tariff_id, user_id
              ) AS latest_rate_notification_jobs ON (
                                           tariff_users.aggr_tariff_id = latest_rate_notification_jobs.tariff_id
                                           AND tariff_users.aggr_user_id = latest_rate_notification_jobs.user_id
                                                    )
    WHERE users.usertype = 'user'
          AND users.owner_id = #{current_user.get_corrected_owner_id}
          #{"AND users.responsible_accountant_id = #{current_user.id}" if current_user.show_only_assigned_users?}
          AND (
               latest_rate_notification_jobs.created_at IS NULL
               AND tariffs.last_change_datetime IS NOT NULL
               OR tariffs.last_change_datetime > latest_rate_notification_jobs.created_at
              )
    GROUP BY aggr_tariff_id, aggr_user_id
    ORDER BY aggr_tariff_name, aggr_user_nicename
    ;
    "
    # Show only non-notified Tariffs
    #            Tariff <-> Job      ->
    # --------------------------------------------
    #              NULL <-> None     -> Hide
    #          Datetime <-> None     -> Show
    #              NULL <-> Datetime -> Hide
    #  Datetime (lower) <-> Datetime -> Hide
    # Datetime (higher) <-> Datetime -> Show

    ActiveRecord::Base.connection.select_all(sql)
  end

  def create_copy
    tariff_copy = self.dup
    tariff_copy.id = nil

    while_index = 1
    tariff_copy.name = "[TEMPORARY SYSTEM COPY (#{while_index})] #{name}"
    while Tariff.where(name: tariff_copy.name).first.present?
      while_index += 1
      tariff_copy.name = "[TEMPORARY SYSTEM COPY (#{while_index})] #{name}"
    end

    tariff_copy.save
    tariff_copy_id = tariff_copy.id

    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("UPDATE rates SET old_id = id WHERE tariff_id = #{id}")
    }

    rate_columns = Rate.column_names - %w[id tariff_id old_id]
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        INSERT INTO rates (tariff_id, old_id, #{rate_columns.join(', ')})
        SELECT #{tariff_copy.id}, rates.old_id, #{rate_columns.map { |column_name| "rates.#{column_name}"}.join(', ')}
        FROM rates
        WHERE rates.tariff_id = #{id}
      ")
    }

    ratedetails_columns = Ratedetail.column_names - %w[id rate_id]
    retry_lock_error(5) {
      ActiveRecord::Base.connection.execute("
        INSERT INTO ratedetails (rate_id, #{ratedetails_columns.join(', ')})
        SELECT new_rates_copy.id, #{ratedetails_columns.map { |column_name| "ratedetails.#{column_name}"}.join(', ')}
        FROM ratedetails
        JOIN rates ON (rates.id = ratedetails.rate_id AND rates.tariff_id = #{id})
        JOIN rates AS new_rates_copy ON (new_rates_copy.old_id = rates.id AND new_rates_copy.tariff_id = #{tariff_copy.id})
      ")
    }

    tariff_copy_id
  end

  def self.provider_tariffs_for_list(user_id, owner_id, cond, tp_count, op_count, incl)
    user = User.where(id: user_id).first
    return [] if user.present? && user.is_manager? && user.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_vendors_tariffs, ac: 2)
    Tariff.providers_tariffs(user_id, owner_id, cond, tp_count, op_count, incl)
  end

  def self.providers_tariffs(user_id, owner_id, cond, tp_count, op_count, incl)
    in_use = Tariff.tariffs_in_use(user_id).join(',')
    in_use_sql = in_use.present? ? "AND tariffs.id IN (#{in_use})" : ''
    Tariff.select("*, #{tp_count}")
          .select(op_count.to_s)
          .where("purpose = 'provider' AND owner_id = '#{owner_id}' #{cond} #{in_use_sql}")
          .includes(incl)
          .order('name ASC')
          .group('tariffs.id')
          .all
  end

  def self.users_tariffs_for_list(user_id, owner_id, cond, tp_count, op_count, incl)
    user = User.where(id: user_id).first
    return [] if user.present? && user.is_manager? && user.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_users_tariffs, ac: 2)
    Tariff.user_wholesale_tariffs(user_id, owner_id, cond, tp_count, op_count, incl)
  end

  def self.user_wholesale_tariffs(user_id, owner_id, cond, tp_count, op_count, incl)
    in_use = Tariff.tariffs_in_use(user_id, 'op').join(',')
    in_use_sql = in_use.present? ? "AND tariffs.id IN (#{in_use})" : ''
    Tariff.select("*, #{tp_count}")
          .select(op_count.to_s)
          .where("purpose = 'user_wholesale' AND owner_id = '#{owner_id}'#{cond} #{in_use_sql}")
          .includes(incl)
          .order('name ASC')
          .group('tariffs.id')
          .all
  end

  def self.tariffs_for_tariff_generator(user_id, owner_id)
    user = User.where(id: user_id).first
    hide_op_tariffs = user.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_users_tariffs, ac: 2)
    hide_tp_tariffs = user.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_vendors_tariffs, ac: 2)
    hide_cond_op = hide_op_tariffs ? "purpose != 'user_wholesale'" : ''
    hide_cond_tp = hide_tp_tariffs ? "purpose != 'provider'" : ''
    usable_tariffs = Tariff.usable_tariffs(user_id)

    Tariff.where("owner_id = #{owner_id} AND (#{usable_tariffs[0]} OR #{usable_tariffs[1]})")
          .where.not(purpose: :user_custom)
          .where(hide_cond_op)
          .where(hide_cond_tp)
          .order(:name)
  end

  def self.tariffs_for_change_tariff(user_id, owner_id)
    user = User.where(id: user_id).first
    hide_op_tariffs = user.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_users_tariffs, ac: 2)
    hide_tp_tariffs = user.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_vendors_tariffs, ac: 2)
    hide_cond_op = hide_op_tariffs ? "purpose != 'user_wholesale'" : ''
    hide_cond_tp = hide_tp_tariffs ? "purpose != 'provider'" : ''
    usable_tariffs = Tariff.usable_tariffs(user_id)

    Tariff.where("owner_id = #{owner_id} AND (#{usable_tariffs[0]} OR #{usable_tariffs[1]})")
          .where(hide_cond_op)
          .where(hide_cond_tp)
  end


  def self.usable_tariffs(user_id)
    tp_tariffs = Tariff.tariffs_in_use(user_id).join(',')
    op_tariffs = Tariff.tariffs_in_use(user_id, 'op').join(',')
    tp_tariffs = tp_tariffs.present? ? "tariffs.id IN (#{tp_tariffs}) AND purpose = 'provider'" : "purpose = 'provider'"
    op_tariffs = op_tariffs.present? ? "tariffs.id IN (#{op_tariffs}) AND purpose = 'user_wholesale'" : "purpose = 'user_wholesale'"
    [tp_tariffs, op_tariffs]
  end

  def self.tariffs_in_use(user_id, tariff_type = 'tp')
    user = User.where(id: user_id).first
    tariffs_in_use = []
    funcionality = (tariff_type == 'tp') ? 'vendors' : 'users'
    if user && user.is_manager? && user.authorize_manager_fn_permissions_with_access_level({fn: "billing_tariffs_#{funcionality}_tariffs".to_sym, ac: 1})
      tariffs_in_use = Device.joins("LEFT JOIN users ON users.responsible_accountant_id = #{user_id}")
                             .where('devices.user_id = users.id')
                             .pluck("#{tariff_type}_tariff_id".to_sym)
                             .uniq
      tariffs_in_use = [-1] if tariffs_in_use.blank?
    end
    tariffs_in_use
  end

  def is_purpose_user_custom?
    purpose == 'user_custom'
  end

  def rates_destination_first_letters
    destinations_first_letters = ActiveRecord::Base.connection.select_values("
      SELECT SUBSTRING(destinations.name, 1, 1) AS name
      FROM rates
      LEFT JOIN destinations ON rates.destination_id = destinations.id
      WHERE (rates.tariff_id = #{id}) AND name REGEXP '^[A-Za-z]'
      GROUP BY SUBSTRING(destinations.name, 1, 1)
      ORDER BY destinations.name ASC
    ")

    non_letters_presence = ActiveRecord::Base.connection.select_value("
      SELECT rates.id FROM rates
      LEFT JOIN destinations ON rates.destination_id = destinations.id
      WHERE (rates.tariff_id = #{id}) AND name NOT REGEXP '^[A-Za-z]'
      LIMIT 1
    ")
    destinations_first_letters.push('#') if non_letters_presence

    destinations_first_letters
  end

  private

  def nice_number(number, session)
    unless session[:nice_number_digits]
      confline = Confline.get_value('Nice_Number_Digits')
      session[:nice_number_digits] ||= confline.to_i if confline and confline.to_s.length > 0
      session[:nice_number_digits] ||= 2 if !session[:nice_number_digits]
    end
    session[:nice_number_digits] = 2 if session[:nice_number_digits] == ""
    n = ""
    n = sprintf("%0.#{session[:nice_number_digits]}f", number.to_d) if number
    if session[:change_decimal]
      n = n.gsub('.', session[:global_decimal])
    end
    n
  end

  def get_provider_rate_details(rate, exrate)
    rate_details = Ratedetail.where(rate_id: rate.id).order('rate DESC').all

    if rate_details.size > 0
      rate_increment_s = rate_details[0]['increment_s']
      rate_cur, rate_free = Currency.count_exchange_prices({exrate: exrate, prices: [rate_details[0]['rate'].to_d, rate_details[0]['connection_fee']]})
    end

    return rate_details, rate_cur
  end

  def local_tz_for_import
    Time.now.formatted_offset
  end

  def self.tariffs_for_device(current_user_id)
    Tariff.where("purpose = 'provider' OR purpose = 'user_wholesale' AND owner_id = #{current_user_id}")
          .order('name ASC').all
  end

  def value_not_present_in_importable_file(name, prefix_loc, return_value)
    sql = "SELECT rates.#{return_value}
           FROM rates
           LEFT JOIN #{name} ON rates.prefix = #{name}.#{prefix_loc}
           WHERE #{name}.#{prefix_loc} IS NULL AND rates.tariff_id = #{id}"
    ActiveRecord::Base.connection.select_values(sql)
  end

  def value_to_delete_in_action(name, prefix_loc, return_value, action_loc)
    sql = "SELECT rates.#{return_value}
           FROM rates
           LEFT JOIN #{name} ON rates.prefix = #{name}.#{prefix_loc}
           WHERE #{name}.#{action_loc} = 'DELETE' AND rates.tariff_id = #{id}"
    ActiveRecord::Base.connection.select_values(sql)
  end

  def value_to_delete_effective_from(name, prefix_loc, return_value, options)
    effective_from_index = options[:imp_effective_from]
    effective_from_manual = options[:manual_effective_from]
    ignore_effective_from_time = options[:ignore_effective_from_time] == 1

    if effective_from_index.present?
      effective_from_value =
        if ignore_effective_from_time
          "col_#{effective_from_index}"
        else
          "CONVERT_TZ(STR_TO_DATE(col_#{effective_from_index}, '#{options[:date_format]}'),"\
            " '#{options[:current_user_tz]}', '#{local_tz_for_import}')"
        end
    elsif effective_from_manual.present?
      effective_from_value = "'#{effective_from_manual}'"
    end

    effective_from_condition =
      if effective_from_value.present?
        if ignore_effective_from_time
          "DATE(rates.effective_from) > DATE(#{effective_from_value})"
        else
          "rates.effective_from > #{effective_from_value}"
        end
      end

    sql = "SELECT rates.#{return_value}
           FROM #{name}
           LEFT JOIN rates ON rates.prefix = #{name}.#{prefix_loc}
           WHERE #{effective_from_condition} AND rates.tariff_id = #{id}"
    ActiveRecord::Base.connection.select_values(sql)
  end

  def self.tariff_rates_effective_from_cache(params)
    `/usr/local/m2/m2_rates_effective_from_cache #{params}`
  end
end
#module ActiveRecord
#  module ConnectionAdapters
#    class MysqlAdapter
#      private
#      def connect_with_local_infile
#        @connection.options(Mysql::OPT_LOCAL_INFILE, 1)
#        connect_without_local_infile
#      end
#      alias_method_chain :connect, :local_infile
#    end
#  end
#end
