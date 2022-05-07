# -*- encoding : utf-8 -*-
module UniversalHelpers

  def nice_user_from_data(username, first_name, last_name, options = {})
    nu = (username.to_s).html_safe
    nu = (first_name.to_s + " " + last_name.to_s).html_safe if first_name.to_s.length + last_name.to_s.length > 0
    if options[:link] and options[:user_id]
      nu = link_to nu, :controller => "users", :action => "edit", :id => options[:user_id].to_i
    end
    nu
  end

  def nice_input_separator(value)
    separator = '.'
    value.to_s.try(:sub, /[.,;]/, separator)
  end

  #  def nice_date(date)
  #    date.strftime("%Y-%m-%d") if date
  #  end
  #
  #  def nice_date_time(time)
  #    time.strftime("%Y-%m-%d %H:%M:%S") if time
  #  end

  def disk_space_usage(folder)
    # This one retrieves remaining space in KB
    space = `df -P '#{folder}' | awk '{print $4}' | tail -n 1`
  end

  def disk_space_usage_percent(folder)
    # This one used to retrieve remaining space in percent
    space = `df -P '#{folder}' | grep -o "[0-9]*%"`
  end

  def add_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << search_value
    end
  end

  def add_contition_and_param_like(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << search_value.to_s
    end
  end

  def add_integer_contition_and_param(value, search_value, search_string, conditions, condition_params)
    if !value.blank?
      conditions << search_string
      condition_params << q(search_value.to_s.gsub(',', '.'))
    end
  end

  def add_integer_contition_and_param_not_negative(value, search_value, search_string, conditions, condition_params)
    if !value.blank? and value.to_i != -1
      conditions << search_string
      condition_params << q(search_value.to_s.gsub(',', '.'))
    end
  end

  def add_contition_and_param_not_all(value, search_value, search_string, conditions, condition_params)
    if value.to_s != _('All')
    conditions << search_string
      condition_params << search_value
    end
  end

  def nice_user(user)
    if user
      nu = user.username.to_s
      nu = user.first_name.to_s + " " + user.last_name.to_s if user.first_name.to_s.length + user.last_name.to_s.length > 0
      return nu
    end
    return ''
  end

  def clear_options(options)
    options.each { |key, value|
      logger.debug "Need to clear search."
      if key.to_s.scan(/^s_.*/).size > 0
        options[key] = nil
        logger.debug "     clearing #{key}"
      end
    }
    return options
  end

=begin
 Loads file to local file system using mysql.
 *Params*
 +filename+ - required param. File name +without+ extension and path.
 +extension+ - file extension. Default - csv
 +path+ - path to file. Default - /tmp/
 *Return*
 +filename+ if load is successful.
 +nil+ - if no file is loaded.
=end

  def load_file_through_database(filename, extension = "csv", path = "/tmp/")
    full_file_path = "#{q(path)}#{q(filename)}.#{q(extension)}"
    logger.debug("  >> load_file_through_database(#{filename})")
    file = ActiveRecord::Base.connection.execute("select LOAD_FILE('#{full_file_path}')") #.fetch_row()[0]
    if file.first[0]
      File.open(full_file_path, 'w') { |f| f.write(file.first[0].force_encoding("UTF-8").encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "?")) }
      logger.debug("  >> load_file_through_database = file")
      return filename
    else
      logger.debug("  << load_file_through_database = nil")
      return nil
    end
  end

=begin rdoc
 Santitizes params for sql input.
=end

  def q(str)
    str.class == String ? ActiveRecord::Base.connection.quote_string(str) : str
  end

  def nice_number_with_separator(number, digits = Confline.get_value('Nice_Number_Digits'), decimal = Confline.get_value('Global_Number_Decimal'))
    return _('Infinity') if number == 'inf'

    digits = 2 if digits.to_i == 0
    number ||= 0

    num = sprintf("%.#{digits}f", number.to_f.round(digits.to_i))
    num = num.gsub('.', decimal) unless ['', '.'].include?(decimal.to_s)
    num
  end

  def nice_number_with_separator_for_invoice(number, digits = Confline.get_value('Nice_Number_Digits'), decimal = Confline.get_value('Global_Number_Decimal'))
    return _('Infinity') if number == 'inf'

    number ||= 0

    num = sprintf("%.#{digits}f", number.to_f.round(digits.to_i))
    num = num.gsub('.', decimal) unless ['', '.'].include?(decimal.to_s)
    num
  end

  # Convert date back from nice_time format
  def back_from_nice_date(date)
    date_format = Confline.get_value('Date_format', 0)
    date_format = '%Y-%m-%d' if date_format.blank?
    date_format = date_format.split(' ').first
    if date_format != '%Y-%m-%d'
      return Time.strptime(date, date_format).strftime('%Y-%m-%d')
    else
      return date
    end
  end

  # format time from seconds
  def nice_time(time, options = {})
    time_format = options[:time_format] if options[:time_format]
    time_format ||= User.current ? Confline.get_value('time_format', User.current.owner.id) : '%M:%S'
    time = begin time.to_i rescue 0 end

    return '' if time == 0 && !options[:show_zero]

    # Handle negative time correctly
    sign = time < 0 ? '-' : ''
    time = time.abs

    if time_format.to_s == "%M:%S"
      h = time / 3600
      m = (time - (3600 * h)) / 60
      s = time - (3600 * h) - (60 * m)
      "#{sign}#{good_date(m + h * 60)}:#{good_date(s)}"
    else
      h = time / 3600
      m = (time - (3600 * h)) / 60
      s = time - (3600 * h) - (60 * m)
      "#{sign}#{good_date(h)}:#{good_date(m)}:#{good_date(s)}"
    end
  end

  def inv_nice_total_time(total_time)
    time_format = Confline.get_value('Duration_Format').to_s
    time_format ||= 'H:M:S'
    return nice_time_in_minutes_decimal(total_time, Confline.get_value('Duration_Format_Minute_Precision')) if time_format == 'M'
    (time_format.to_s == 'M:S') ? nice_time_in_minits(total_time) : nice_time(total_time, time_format: time_format)
  end

  def nice_time_in_minutes_decimal(time, precision)
    time = time.to_i
    return "" if time == 0
    m = time / 60
    s = (time % 60).to_d / 60
    precision = 2 if precision.blank?
    nice_number_with_separator_for_invoice(m + s, precision)
  end

  # format time from seconds
  def invoice_nice_time(time, type)
    if type.to_i == 0
      nice_time(time)
    else
      nice_time_in_minits(time)
    end
  end

  def nice_time_in_minits(time)
    time = time.to_i
    return '' if time == 0
    m = time / 60
    s = time - (60 * m)
    good_date(m) + ":" + good_date(s)
  end

  def nice_time_from_date(date)
    date ? good_date(date.hour) + ":" + good_date(date.min) + ":" + good_date(date.sec) : ""
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = "0" + dd if dd.length<2
    dd
  end

  def nice_day(string)
    string.to_i < 10 ? "0" + string : string
  end

  def curr_price(price = 0)
    price * User.current.currency.exchange_rate.to_f
  end

  def round_to_cents(amount)
    ((amount.to_f * 100).ceil.to_d / 100)
  end

  def format_money(amount, currency = nil)
    [sprintf("%.2f", round_to_cents(amount.to_f)), currency].compact.join(" ")
  end

  def floor2(amount, exp = 0)
    multiplier = 10 ** exp
    ((amount * multiplier).floor).to_d/multiplier.to_d
  end

  def page_select_header(page, total_pages, page_select_params = {}, options = {}, return_type = "table")
    page = page.to_i
    letter = 'A'
    letter = page_select_params[:st].upcase if page_select_params.try(:st)
    ret = []
    if total_pages.to_i > 1
      opts= {:id_prefix => "page_", :wrapper => true}.merge(options)

      page_select_params = {} if page_select_params.class != Hash
      keys = [:page]
      page_select_params = page_select_params.reject { |k, v| keys.include?(k || k.to_sym) }
      pstart = page - 10
      pstart = 1 if pstart < 1
      pend = page + 10
      pend = total_pages if pend > total_pages

      back10 = page - 20
      if back10.to_i <= 0
        back10 = 1 if pstart > 1
        back10 = nil if pstart == 1
      end
      forw10 = page + 20
      if forw10 > total_pages
        forw10 = total_pages if pend < total_pages
        forw10 = nil if pend == total_pages
      end

      back100 = page - 100
      if back100.to_i < 0
        back100 = 1 if back10.to_i > 1 if back10
        if (back10.to_i <= 1) or (not back10)
          back100 = nil
        end
      end

      forw100 = page + 100
      if forw100.to_i > total_pages
        forw100 = total_pages if forw10 < total_pages if forw10
        forw100 = nil if forw10 == total_pages or not forw10
      end
      case return_type
        when "table"
          ret = ["<div align='center'>\n<table class='page_title2' width='100%'>\n<tr>"] if opts[:wrapper] == true
          ret << "    <td align = 'center' id='#{opts[:id_prefix]}#{page.to_i}'>"
          ret << " "+link_to("<<", {:action => params[:action], :page => back100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-100"}) if back100
          ret << " "+link_to("<", {:action => params[:action], :page => back10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-20"}) if back10
          for p in pstart..pend
            ret << "<b>" if p == page
            ret << " "+link_to(p, {:action => params[:action], :page => p, :st => letter, :search_on => params[:search_on]}.merge(page_select_params))
            ret << "</b> " if p == page
          end
          ret << " "+link_to(">", {:action => params[:action], :page => forw10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+20"}) if forw10
          ret << " "+link_to(">>", {:action => params[:action], :page => forw100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+100"}) if forw100
          ret << "   </td>\n</tr>\n</table>\n</div>\n<br>" if opts[:wrapper] == true
        when "div"
          ret = ["<div>"] if opts[:wrapper] == true
          ret << link_to("<<", {:action => params[:action], :page => back100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-100", :class => "pagination_link"}) if back100
          ret << link_to("<", {:action => params[:action], :page => back10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "-20", :class => "pagination_link"}) if back10
          for p in pstart..pend
            if p == page
              ret << "<span class='current'>#{p}</span>"
            else
              ret << link_to(p, {:action => params[:action], :page => p, :search_on => params[:search_on]}.merge(page_select_params), {:class => "pagination_link"})
            end
          end
          ret << link_to(">", {:action => params[:action], :page => forw10, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+20", :class => "pagination_link"}) if forw10
          ret << link_to(">>", {:action => params[:action], :page => forw100, :search_on => params[:search_on]}.merge(page_select_params), {:title => "+100", :class => "pagination_link"}) if forw100
          ret << "</div>" if opts[:wrapper] == true
        when "array"
          ret << ["&lt;&lt;", back100] if back100
          ret << ["&lt;", back10] if back10
          for p in pstart..pend
            ret << (p == page ? [p, nil] : [p, p])
          end
          ret << ["&gt;", forw10] if forw10
          ret << ["&gt;&gt;", forw100] if forw100
      end
    end
    case return_type
      when "table" then
        return ret.join("\n").html_safe
      when "div" then
        return ret.join("\n").html_safe
      when "array" then
        return ret
    end
    return nil
  end

  # Executes the given block +retries+ times (or forever, if explicitly given nil),
  # catching and retrying SQL Deadlock errors.
  def retry_lock_error(retries = 3, &block)
    yield
    rescue ActiveRecord::StatementInvalid => err
      message = err.message
      if (message =~ /Deadlock found when trying to get lock/ ||
          message =~ /ErrorLock wait timeout exceeded/) &&
          (retries.nil? || retries > 0)
        retry_lock_error(retries ? retries - 1 : nil, &block)
      else
        MorLog.my_debug("#{message}")
        message
      end
  end

  def nice_date_time_user(time, session, offset = 1)
    current_user = User.current
    if time
      format = (session and !session[:date_time_format].to_s.blank?) ? session[:date_time_format].to_s : "%Y-%m-%d %H:%M:%S"
      t = time.respond_to?(:strftime) ? time : time.to_time

      if offset.to_i == 1
        d = (session and current_user) ? current_user.user_time(t).strftime(format.to_s) : t.strftime(format.to_s)
      else
        d = t.strftime(format.to_s)
      end
    else
      d=''
    end
    return d
  end

  def default_formatting_options(user)
    user = User.first if user.blank?
    options = {}

    number_digits = Confline.get_value('Nice_Number_Digits')
    options[:number_digits] = number_digits.to_i <= 0 ? 2 : number_digits

    number_decimal = Confline.get_value('Global_Number_Decimal').to_s
    options[:number_decimal] = ['.', ',', ';'].include?(number_decimal) ? number_decimal : '.'

    exchange_rate = user.try(:currency).try(:exchange_rate).to_d
    options[:exchange_rate] = exchange_rate == 0 ? 1 : exchange_rate

    options[:time_format] = Confline.get_value('time_format', user.try(:owner_id).to_i)
    date_format = Confline.get_value('date_format', user.try(:owner_id).to_i).split(' ')[0]
    options[:date_format] = date_format.present? ?
        date_format.gsub('%Y', 'yyyy').gsub('%m', 'MM').gsub('%d', 'dd') : 'yyyy-MM-dd'

    options[:usertype] = user.try(:usertype).to_s

    options
  end

  def uptime_from_seconds(seconds)
    days = (seconds / 86400).to_s
    time = '%02d:%02d' % [seconds / 3600 % 24, seconds / 60 % 60]
    days << (days == '1' ? ' day' : ' days')
    "#{days}, #{time}"
  end

  # Checks if a given time has already come in a User's time zone
  def usertime_over?(user, time)
    # User time offset from UTC
    user_offset = ActiveSupport::TimeZone[user.time_zone].try(:formatted_offset, false)
    # Convert User time to Server time
    in_server_time = Time.parse(time.strftime('%Y-%m-%d %H:%M:%S') << " #{user_offset}")
    # Check if the time is over
    in_server_time <= Time.now
  end

  def nice_rate_attr(rate_change)
    rate_change.to_s.sub('increment_s', 'increment')
               .sub('ghost_min_perc', 'ghost_percent')
               .sub('price', 'rate')
               .sub('artype', 'type')
  end

  def pretty_rate_change(model_changes)
    cols = []
    olds = []
    news = []

    model_changes.each do |key, val|
     cols << nice_rate_attr(key)
     olds << format_rate_change_pair(key, val[0])
     news << format_rate_change_pair(key, val[1])
    end

    {cols: cols.join('; '), olds: olds.join('; '), news: news.join('; ')}
  end

  def format_rate_change_pair(key, val)
    return nice_number_with_separator(val) if %w(rate connection_fee increment_s).include?(key)

    time_format = Confline.get_value('time_format')
    time_format = '%H:%M:%S' if time_format.blank?
    return val.strftime(time_format) if key == 'end_time'

    val
  end

  def hex_to_bytes(hex_str)
    hex_str.to_s.scan(/.{2}/).map { |unit| unit.to_i(16) }.pack('C*')
  end

  # Tries to determine a decimal separator from an array of rows
  # +file+:: file as an array of rows
  # +col_sep+:: a column separator for csv
  def find_decimal_separator(file, col_sep)
    return unless file

    seps = []
    file[0..4].each do |row|
      seps +=
        row.gsub(/[\s"']+/, '')
           .split(col_sep)
           .select { |col| col =~ /\A[\+\-]?\d*[^\d]\d+?\z/ }
           .map { |dec_col| dec_col.gsub(/[\d+\+\-]/, '') }
    end

    sep = seps.max_by { |sep| seps.count(sep) }
    sep.blank? ? nil : sep
  end

  # Converts an XLSX to a PDF
  # +working_dir+:: directory to work with
  # +file_name+:: file_name without a extension
  def convert_xlsx_to_pdf(working_dir, file_name)
    file_path = "#{working_dir}/#{file_name}.pdf"
    # Do not convert to a PDF if it already exists
    unless File.exists?(file_path)
      locale = case Confline.get_value('Global_Number_Decimal').to_s
                 when ','
                   # ','
                   'ru_RU.UTF-8'
                 else
                   # '.'
                   'en_EN.UTF-8'
               end
      # For libre office to be ran by apache it is necessary to set a
      #   home path and change the working directory to it (permissions).
      system(
        "export HOME=#{working_dir}; export LANG=#{locale} && cd $HOME && libreoffice --headless " \
        "--convert-to pdf #{working_dir}/#{file_name}.xlsx --outdir #{working_dir}"
      )
    end
  end

  def convert_via_libreoffice(working_dir, file_name, file_type, convert_type)
      locale = case Confline.get_value('Global_Number_Decimal').to_s
                 when ','
                   # ','
                   'ru_RU.UTF-8'
                 else
                   # '.'
                   'en_EN.UTF-8'
               end
      # For libre office to be ran by apache it is necessary to set a
      #   home path and change the working directory to it (permissions).
      # system("export HOME=#{working_dir}; export LANG=#{locale} && cd $HOME && libreoffice --headless --convert-to xls #{working_dir}/#{file_name}.csv --outdir #{working_dir}")
      system(
          "export HOME=#{working_dir}; export LANG=#{locale} && cd $HOME && libreoffice --headless " \
        "--convert-to #{convert_type} #{working_dir}/#{file_name}.#{file_type} --outdir #{working_dir}"
      )
  end

  # Sends a converted PDF file
  # +working_dir+:: directory to work with
  # +file_name+:: file_name without a extension
  # +fail_action+:: failure callback
  def send_xlsx_as_pdf(working_dir, file_name, fail_action)
    convert_xlsx_to_pdf(working_dir, file_name)
    return if send_pdf("#{working_dir}/#{file_name}.pdf")

    flash[:notice] = _('File_does_not_exist_in_a_file_system')
    redirect_to(action: fail_action) && (return false)
  end

  # Returns data from a converted PDF file
  # +working_dir+:: directory to work with
  # +file_name+:: file_name without a extension
  def read_xlsx_as_pdf(working_dir, file_name)
    convert_xlsx_to_pdf(working_dir, file_name)
    send_pdf("#{working_dir}/#{file_name}.pdf", true)
  end

  # Downloads a PDF file on a given file_path
  # +file_path+:: file path to download
  def send_pdf(file_path, only_bytes = false)
    return unless File.exists?(file_path)
    File.open(file_path, 'r') do |file|
      file_name = file_path.split('/').last
      bytes = file.read.force_encoding('BINARY')
      only_bytes ? bytes : send_data(bytes, filename: file_name, type: 'application/pdf')
    end
  end

  def normalize_validates_message_attribute(name)
    name.to_s.downcase.gsub(' ', '_')
  end

  # Returns formatted html of tariff select
  # +tariffs+:: array with tariffs, ex.: [[name, id]]
  # +tarrif_id+:: id of selected tariff
  # +select_id+:: select element id
  def tariff_select_tag(tariffs, tarrif_id, select_id)
    select_id_html = select_id.gsub('[', '_').delete(']')
    span_id = select_id_html + '_edit_link'

    code = [select_tag(select_id,
      options_for_select(
        tariffs,
        tarrif_id
      )
    )]

    code << "&nbsp;<span id='#{span_id}'></span>".html_safe
    if admin? || (manager? && authorize_manager_permissions({controller: :tariffs, action: :list, no_redirect_return: 1}))
      code << "<script type='text/javascript'>".html_safe
      code << "jQuery(document).ready(function () {".html_safe
      code << "var selection = jQuery('##{select_id_html}');".html_safe
      code << "var selection_edit_link = jQuery('##{span_id}');".html_safe
      code << "var selection_edit_link_url = '/tariffs/edit/';".html_safe
      code << "var false_values = ['0'];".html_safe

      code << "selection.on('change', function() {".html_safe
      code << "  change_selection_edit_link(selection, selection_edit_link, selection_edit_link_url, false_values);".html_safe
      code << "});".html_safe
      code << "selection.trigger('change');".html_safe
      code << "});".html_safe
      code << "</script>".html_safe

    end
    return code.join("\n").html_safe
  end

  def is_us_routing_module_enabled?
    Confline.get_value('us_jurisdictional_routing_module_enabled').to_i == 1
  end

  def adjust_country_name(country)
    country.to_s.gsub(/Republic Of /, '').gsub('United States Of America', 'United States').gsub('Russia', 'Russian Federation')
  end

  def prefixes_input_decomposition(prefixes = '')
    # Replace newlines to commas; remove all spaces and split into chunks separated by commas
    all_prefixes = prefixes.gsub("\r\n", ',').gsub("\n", ',').gsub(' ', '').split(',')

    # Accept only supported formats
    #   370, 370% (at least one digit before %), 370-380
    good_prefixes = all_prefixes.reject { |prefix| (prefix =~ /^(\d+%?|\d+-{1}\d+)$/).nil? }

    # Accept only supported formats of P1-P2
    good_prefixes.reject! do |prefix|
      next unless prefix.include?('-')
      !prefix_range_for_decomposition_valid?(prefix)
    end

    bad_prefixes = (all_prefixes - good_prefixes)

    good_prefixes.map! do |prefix|
      prefix.include?('-') ? prefix_range_decomposition_for_mysql(prefix, safeguard: false) : prefix
    end

    good_prefixes = good_prefixes.flatten.uniq

    [good_prefixes, bad_prefixes]
  end

  # P1-P2 prefix range decomposition
  # Example: 231-318
  #   231 232 233 234 235 236 237 238 239
  #   24_ 25_ 26_ 27_ 28_ 29_
  #   30_
  #   310 311 312 313 314 315 316 317 318 318
  def prefix_range_decomposition_for_mysql(prefix_range, sub_prefix: '', safeguard: true)
    return prefix_range if safeguard && !prefix_range_for_decomposition_valid?(prefix_range)

    prefix1, prefix2 = prefix_range.gsub(' ', '').split('-')
    prefix1_int, prefix2_int = prefix1.to_i, prefix2.to_i
    prefix_length = prefix1.size

    decomposed_prefixes = []

    return [] if prefix_length == 0

    if prefix_length == 1
      return ["#{sub_prefix}_"] if (prefix1_int - prefix2_int) == -9

      until (prefix1_int > prefix2_int) || (prefix1_int % 10 == 0) do
        decomposed_prefixes << "#{sub_prefix}#{prefix1_int}"
        prefix1_int += 1
      end

      # To get nice sequence in last output, 'tmp' for reversing
      tmp = []
      until (prefix2_int < prefix1_int) || (prefix2_int % 10 == 9) do
        tmp << "#{sub_prefix}#{prefix2_int}"
        prefix2_int -= 1
      end
      decomposed_prefixes.concat(tmp.reverse)

      return decomposed_prefixes
    end


    prefix1_zeros = prefix1[1..-1].to_i == 0
    prefix2_nines = prefix2[1..-1] == ''.rjust(prefix_length-1, '9')

    if (prefix1[0].to_i < prefix2[0].to_i) || (prefix1_zeros && prefix2_nines)
      unless prefix1_zeros
        decomposed_prefixes.concat(
            prefix_range_decomposition_for_mysql(
                "#{prefix1[1..-1]}-#{''.rjust(prefix_length-1, '9')}",
                sub_prefix: "#{sub_prefix}#{prefix1[0]}",
                safeguard: false
            )
        )
      end

      if (prefix1[0].to_i + (prefix1_zeros ? 0 : 1)) <= prefix2[0].to_i
        ((prefix1[0].to_i + (prefix1_zeros ? 0 : 1))..(prefix2[0].to_i - (prefix2_nines ? 0 : 1))).each do |prefix_0|
          decomposed_prefixes << "#{sub_prefix}#{prefix_0.to_s.ljust(prefix_length, '_')}"
        end
      end

      unless prefix2_nines
        decomposed_prefixes.concat(
            prefix_range_decomposition_for_mysql(
                "#{''.rjust(prefix_length-1, '0')}-#{prefix2[1..-1]}",
                sub_prefix: "#{sub_prefix}#{prefix2[0]}",
                safeguard: false
            )
        )
      end
    else
      decomposed_prefixes.concat(
          prefix_range_decomposition_for_mysql(
              "#{prefix1[1..-1]}-#{prefix2[1..-1]}",
              sub_prefix: "#{sub_prefix}#{prefix1[0]}",
              safeguard: false
          )
      )
    end

    decomposed_prefixes
  end

  # Check only supported formats of P1-P2, where
  #  P char length not greater than 20
  #  P1 and P2 char length must be the same
  #  P2 must be higher integer than P1
  def prefix_range_for_decomposition_valid?(prefix_range)
    return false if (prefix_range.gsub(' ', '').to_s =~ /^(\d+-{1}\d+)$/).nil?

    prefix1, prefix2 = prefix_range.gsub(' ', '').split('-')
    return false if (prefix1.size > 20) ||
        (prefix1.size != prefix2.size) ||
        (prefix1.to_i > prefix2.to_i)

    true
  end
end
