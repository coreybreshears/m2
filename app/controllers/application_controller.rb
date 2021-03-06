# Application Controller
class ApplicationController < ActionController::Base
  require 'builder/xmlmarkup'
  require 'json'

  unless Rails.env.development?
    rescue_from Exception do |exc|
      if params[:controller].to_s != 'api'
        if !params[:this_is_fake_exception] && session
          send_bugsnag(exc) unless Socket.gethostname.to_s.include?('ocean')
          my_rescue_action_in_public(exc)

          if session[:flash_not_redirect].to_i == 0
            redirect_to :root # and return false
          else
            render(layout: 'layouts/mor_min') && (return false)
          end
        else
          render text: my_rescue_action_in_public(exc)
        end
      end
    end
  end

  rescue_from ActiveRecord::RecordNotFound, with: :action_missing
  rescue_from AbstractController::ActionNotFound, with: :action_missing
  rescue_from ActionController::RoutingError, with: :action_missing
  rescue_from ActionController::UnknownController, with: :action_missing
  rescue_from ActionView::MissingTemplate, with: :template_missing

  # rescue_from ActionController::UnknownAction, :with => :action_missing

  protect_from_forgery(with: :reset_session)

  include SqlExport
  include UniversalHelpers

  require 'digest/sha1'
  require 'enumerator'
  # require 'ruby_extensions'
  require 'net/http'
  require 'fileutils'

  # Pick a unique cookie name to distinguish our session data from others'
  # session :session_key => '_mor_session_id'

  helper_method :convert_curr, :allow_manage_providers?, :corrected_user_id, :nice_user_timezone,
                :correct_owner_id, :pagination_array, :launch_script, :assigned_users_devices,
                :current_user, :current_user_id, :hide_finances, :session_from_datetime_array,
                :session_till_datetime_array, :nice_date, :to_default_date, :assigned_users,
                :nice_date_time, :reseller_active?, :cc_active?, :ccl_active?, :is_number?, :is_numeric?, :load_ok?,
                :pbx_active?, :send_email_dry, :m2_version?, :load_params_to_session, :get_session, :set_session,
                :user_tz, :nice_time_in_user_tz, :strip_params, :create_directory_if_not_exist,
                :close_m2_form, :manager_permissions, :authorize_manager_permissions, :correct_manager_id,
                :nice_number_n_digits, :nice_number_round, :show_active_currency?, :set_options_from_params,
                :server_free_space_limit,:es_session_from, :es_session_till, :collide_prefix, :es_limit_search_by_days,
                :db_replication_status, :validate_session_ip, :recheck_integrity_check,
                :authorize_manager_fn_permissions, :m4_functionality?, :paypal_default_amount,
                :paypal_min_amount, :paypal_max_amount, :paypal_currency, :paypal_addon_active?, :dc_groups,
                :tariff_import_active?, :paypal_payments_active?, :two_fa_enabled?, :deny_balance_range_change,
                :m4_dids_active?

  # addons
  helper_method :monitorings_addon_active?,
                :admin?, :manager?, :reseller?, :user?, :reseller_pro_active?
  before_filter :set_charset
  before_filter :set_current_user, :set_timezone
  before_filter :logout_on_session_ip_mismatch
  before_filter :servers_status_check, if: :admin?, except: [
    :active_calls_count, :active_calls_show, :jqxgrid_sort, :login, :try_to_login,
    :logout, :jqxgrid_table_settings_update
  ]
  before_filter :tariff_rates_effective_from_cache_error_periodic_check, if: :admin?, except: [
    :active_calls_count, :active_calls_show, :jqxgrid_sort, :login, :try_to_login,
    :logout, :jqxgrid_table_settings_update
  ]
  before_action :force_logout, except: [:try_to_login], if: :should_logout?
  before_action :check_user_is_logged, except: [:try_to_login]
  after_filter :annoying_messages

  def change_currency
    params_currency = params[:currency]
    session_currency = session[:show_currency]

    currency = if params_currency
                 params_currency
               elsif !session_currency
                 current_user.currency.name
               end
    session[:show_currency] = currency if currency
  end

  def change_exchange_rate
    currency = session[:show_currency]
    currency ? Currency.where(name: currency).first.exchange_rate.to_d : 1
  end

  def action_missing(err = '')
    action = params[:action]
    controller = params[:controller]
    MorLog.my_debug("Authorization failed:\n   User_type: " + (session.blank? ? '' : session[:usertype_id].to_s) + "\n   Requested: " + "#{controller if params}::#{action if params}")
    MorLog.my_debug("   Session(#{controller}_#{action}):" + (session.blank? ? '' : session["#{controller}_#{action}".intern].to_s))
    if controller.to_s == 'api'
      doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
      doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
      MorApi.return_error('There is no such API', doc)
      if params[:test].to_i == 1
        render(text: out_string) && (return false)
      elsif confline('XML_API_Extension').to_i == 1
        send_data(out_string, type: 'text/xml', filename: 'mor_api_response.xml') && (return false)
      else
        send_data(out_string, type: 'text/html', filename: 'mor_api_response.html') && (return false)
      end
    else
      flash[:notice] = _('Dont_Be_So_Smart')
      Rails.logger.error(err)
      redirect_to :root
    end
  end

  def template_missing
    redirect_to :root
  end

  def item_pages(total_items)
    # total_items - positive integer, number of items that are going to be displayed per all pages
    # items_per_page - how many items should be displayed in one page, positive integer, depends on user settings
    # total_pages - how many pages will be needes to display items when divided per pages
    # if there's no items per session set we should save it in session for future use. after we validate id
    session[:items_per_page], items_per_page = Application.items_per_page_count(session[:items_per_page])
    # so there's code duplication, 1 should be refactored and set as some sort of global constant
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    return items_per_page, total_pages
  end

  def convert_curr(price)
    current_user.convert_curr(price)
  end

  def set_current_user
    User.current = current_user

    if current_user &&
        !ActiveSupport::TimeZone.all.each_with_index.collect { |tz| tz.name.to_s }.include?(current_user.time_zone.to_s)
      current_user.update_attributes(time_zone: 'UTC')
    end

    User.system_time_offset = session[:time_zone_offset].to_i
  end

  def set_timezone
    begin
      Time.zone = current_user.time_zone if current_user
    rescue => exception
    end
  end

  def set_charset
    # Ticket 8845
    # headers['Content-Type'] = 'text/html; charset=utf-8'
    session[:flash_not_redirect] = 0 if session
  end

  # this function exchanges calls table fields user_price with reseller_price to fix major flaw in MORs' database design prior MOR 0.8
  # this function should NEVER be used! it is made just for testing purposes!
  def exchange_user_to_reseller_calls_table_values
    updated = Confline.exchange_user_to_reseller_calls_table
    flash[:notice] = 'Calls table already fixed. Not fixing again.' unless updated
  end

  # puts correct language
  def check_localization
    # ---- language ------
    params_lang = params[:lang]
    if params_lang && params_lang.is_a?(String)
      I18n.locale = params_lang
      session[:lang] = params_lang
    elsif session[:lang]
      I18n.locale = params_lang
    end

    # flags_to_session if !session[:tr_arr]
    # ---- currency ------

    if params[:currency]
      if curr = Currency.where(name: params[:currency].gsub(/[^A-Za-z]/, '')).first
        session[:show_currency] = curr.name
      end
    end

    time = test_machine_active? ? (Time.now - 3.years) : Time.now

    # ---- items per page -----
    session[:items_per_page] = 1 if session[:items_per_page].to_i < 1
    user = current_user

    if user
      user_time_year = user.user_time(time).year
      user_time_month = user.user_time(time).month
      user_time_day = user.user_time(time).day

      session[:year_from] = user_time_year if session[:year_from].to_i == 0
      session[:month_from] = user_time_month if session[:month_from].to_i == 0
      session[:day_from] = user_time_day if session[:day_from].to_i == 0

      session[:year_till] = user_time_year if session[:year_till].to_i == 0
      session[:month_till] = user_time_month if session[:month_till].to_i == 0
      session[:day_till] = user_time_day if session[:day_till].to_i == 0
    else
      session[:year_from] = time.year if session[:year_from].to_i == 0
      session[:month_from] = time.month if session[:month_from].to_i == 0
      session[:day_from] = time.day if session[:day_from].to_i == 0

      session[:year_till] = time.year if session[:year_till].to_i == 0
      session[:month_till] = time.month if session[:month_till].to_i == 0
      session[:day_till] = time.day if session[:day_till].to_i == 0
    end
  end

  def authorize
    if !admin? && !manager?
      contr = controller_name.to_s.gsub(/"|'|\\/, '')
      act = action_name.to_s.gsub(/"|'|\\/, '')
      controller_action = session["#{contr}_#{act}".intern]
      if !controller_action || controller_action.class != Fixnum || controller_action.to_i != 1
        # Handle guests
        if !session[:usertype_id] or session[:usertype] == 'guest' or session[:usertype].blank?
          guest = Role.where(name: 'guest').first
          if guest
            session[:usertype_id] = guest.id
            session[:usertype] = 'guest'
          else
            redirect_to(controller: 'callc', action: 'login') && (return false)
          end
        end
        roleright = RoleRight.get_authorization(session[:usertype_id], contr, act).to_i
        session["#{contr}_#{act}".intern] = roleright
      end

      if session["#{contr}_#{act}".intern].to_i != 1
        MorLog.my_debug("Authorization failed:\n   User_type: " + session[:usertype_id].to_s + "\n   Requested: " + "#{contr}::#{act}")
        MorLog.my_debug("   Session(#{contr}_#{act}):" + session["#{contr}_#{act}".intern].to_s)
        I18n.locale = params[:lang] if params[:lang] && params[:lang].present?
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')

        if session[:user_id].present?
          redirect_to(:root) && (return false)
        else
          redirect_to(controller: :callc, action: :login) && (return false)
        end
      end
    elsif manager?
      authorize_manager_permissions
    end
  end

  def authorize_admin
    unless admin?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      if session[:user_id].present?
        redirect_to(:root) && (return false)
      else
        redirect_to(controller: 'callc', action: 'login') && (return false)
      end
    end
  end

  def today
    current_user.user_time(Time.now).strftime('%Y-%m-%d')
  end

  def add_action(user_id, action, data, action_cache = nil)
    time_now = Time.now

    if user_id
      if action_cache
        action_cache.add("NULL, '#{data}', NULL, NULL, '#{action}', '#{time_now.to_s(:db)}', 0, #{user_id}, NULL, ''")
      else
        Action.new(date: time_now, user_id: user_id, action: action, data: data).save
      end
    end
  end

  def add_action_second(user_id, action, data, data2)
    if user_id
      act = Action.create({
        date: Time.now,
        user_id: user_id,
        action: action,
        data: data,
        data2: (data2 if data2)
      }.reject { |key, _| key == :data && !data2 })
    end
  end

  def change_date_to_present
    change_date_from_to_present
    change_date_till_to_present
  end

  def change_date_from_to_present
    user_time = current_user.user_time(Time.now)
    session[:year_from], session[:month_from], session[:day_from], session[:hour_from], session[:minute_from] = user_time.year, user_time.month, user_time.day, 0, 0
  end

  def change_date_till_to_present
    user_time = current_user.user_time(Time.now)
    session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till] = user_time.year, user_time.month, user_time.day, 23, 59
   end

  def change_date_from
    if params[:date_from]
      if params[:date_from][:year].to_i > 1000 # dirty hack to prevent ajax trashed params error
        session[:year_from] = params[:date_from][:year]
        session[:month_from] = (params[:date_from][:month].to_i <= 0) ? 1 : params[:date_from][:month].to_i
        session[:month_from] = 12 if params[:date_from][:month].to_i > 12

        if params[:date_from][:day].to_i < 1
          params[:date_from][:day] = 1
        elsif !Date.valid_civil?(session[:year_from].to_i, session[:month_from].to_i, params[:date_from][:day].to_i)
          params[:date_from][:day] = last_day_of_month(session[:year_from], session[:month_from])
        end

        session[:day_from] = params[:date_from][:day]
        session[:hour_from] = params[:date_from][:hour] if params[:date_from][:hour]
        session[:minute_from] = params[:date_from][:minute] if params[:date_from][:minute]

        # Reset session date from if invalid params were given
        begin
          session_from_datetime
        rescue => exception
          change_date_from_to_present
        end
      end
    end

    change_date_from_to_present unless session[:year_from]
  end

  def change_date_till
    if params[:date_till]
      if params[:date_from][:year].to_i > 1000 # dirty hack to prevent ajax trashed params error
        session[:year_till] = params[:date_till][:year]
        session[:month_till] = (params[:date_till][:month].to_i <= 0) ? 1 : params[:date_till][:month].to_i
        session[:month_till] = 12 if params[:date_till][:month].to_i > 12

        if params[:date_till][:day].to_i < 1
          params[:date_till][:day] = 1
        elsif !Date.valid_civil?(session[:year_till].to_i, session[:month_till].to_i, params[:date_till][:day].to_i)
          params[:date_till][:day] = last_day_of_month(session[:year_till], session[:month_till])
        end

        session[:day_till] = params[:date_till][:day]
        session[:hour_till] = params[:date_till][:hour] if params[:date_till][:hour]
        session[:minute_till] = params[:date_till][:minute] if params[:date_till][:minute]

        # Reset session date till if invalid params were given
        begin
          session_till_datetime
        rescue => exception
          change_date_till_to_present
        end
      end
    end

    change_date_till_to_present unless session[:year_till]
  end

  def change_date
    change_date_from
    change_date_till

    if Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
      flash[:notice] = _('Date_from_greater_thant_date_till')
    end

    current_user_session_time
  end

  def current_user_session_time
    cust_from = Time.mktime(session[:year_from], session[:month_from], session[:day_from], session[:hour_from], session[:minute_from])
    cust_till = Time.mktime(session[:year_till], session[:month_till], session[:day_till], session[:hour_till], session[:minute_till])

    if current_user
      session[:current_user_time_from] = current_user.system_time(cust_from)
      session[:current_user_time_till] = current_user.system_time(cust_till)
    end
  end

  def random_password(size = 12)
    ApplicationController::random_password(size)
  end

  def ApplicationController::random_password(size = 12)
    lowercase = ('a'..'z').to_a
    numbers = (0..9).to_a
    if User.use_strong_password?
      uppercase = ('A'..'Z').to_a
      pass = []
      inner_range = 1..(size.to_f / 3).ceil
      pass << inner_range.map { |char| lowercase[rand(lowercase.size)] }
      pass << inner_range.map { |char| uppercase[rand(uppercase.size)] }
      pass << inner_range.map { |char| numbers[rand(numbers.size)] }
      pass.flatten.shuffle.join[0, size]
    else
      chars = (lowercase + numbers) - %w[i o 0 1 l 0]
      (1..size).collect { |char| chars[rand(chars.size)] }.join
    end
  end

  def random_digit_password(size = 8)
    chars = (0..9).to_a
    (1..size).map { |char| chars[rand(chars.size)] }.join
  end

  # Put message into file for debugging
  def my_debug(message, add_time = nil, format_string = '%y-%m-%d %H:%M:%S')
    MorLog.my_debug(message, add_time, format_string)
  end

  # Put message with time into file for debugging
  def my_debug_time(message)
    my_debug(message, true, '%Y-%m-%d %H:%M:%S')
  end

  # function for configuring extensions for local devices based on passed arguments
  # basically this function configures call-flow for each device
  def configure_extensions(device_id, options = {})

    return true if m4_functionality?

    @device = Device.where(id: device_id).first

    return if !@device || device_id == 0

    default_context = 'mor_local'
    default_app = 'Dial'

    busy_extension = 201
    no_answer_extension = 401
    chanunavail_extension = 301

    @user = User.where(id: @device.user_id).first if @device.user_id.to_i > -1

    user_id = 0
    user_id = @device.user_id if @user

    timeout = @device[:timeout]

    if @device

      # check devices login status

      dev = @device
      device_server = Server.where(id: @device.server_id).first

      begin
        if dev.device_type == 'SIP'
          dev_name = nil
          if dev.device_old_name_record != dev.name
            dev_name = dev.device_old_name_record
          end
          exception_array = @device.reload_device_in_all_fs(dev_name)
          raise StandardError.new('Server_problems') unless exception_array.empty?
        end

        Action.add_action_hash(options[:current_user], action: 'Device update cmd sent to FS', target_id: @device.id, target_type: 'device', data: @device.user_id)
      rescue StandardError => exception
        MorLog.my_debug "Can't connect to FS server"
        Action.add_action_hash(options[:current_user], action: 'error', data2: "Can't connect to FS server", target_id: @device.id, target_type: 'device', data: @device.user_id, data3: exception.class.to_s, data4: exception.message.to_s)
        if admin? and !options[:no_redirect]
          flash_help_link = 'http://wiki.ocean-tel.uk/index.php/Configure_SSH_connection_between_servers'
          flash[:notice] = "Can't connect to FS server"
          flash[:notice] += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>" if flash_help_link
          if options[:api].to_i == 0
            redirect_to(:root) && (return false)
          else
            return false
          end
        end

      end
    end # if device
    true
  end

  # converting caller id like "name" <11> to name
  def nice_cid(cidn)
    if cidn
      cidn.split('<')[0].to_s.strip[1...-1]
    else
      ''
    end
  end

  # converting caller id like "name" <11> to 11
  def cid_number(cid)
    if cid.to_s =~ /<+.*>+/
      index_left = cid.index('<')
      cid[index_left + 1, cid.index('>') - index_left - 1]
    else
      ''
    end
  end

  def session_from_date
    sfd = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s)
    current_user.system_time(sfd, 1)
  end

  def session_till_date
    sfd = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s)
    current_user.system_time(sfd, 1)
  end

  def session_time_from_db
    Time.zone.local(session[:year_from].to_i, session[:month_from].to_i, session[:day_from].to_i).getlocal.strftime('%F %T')
  end

  def session_time_till_db
    (Time.zone.local(session[:year_till].to_i, session[:month_till].to_i, session[:day_till].to_i) + (1.day - 1.second)).getlocal.strftime('%F %T')
  end

  def session_from_datetime_no_timezone
    sfd = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s) + ' ' + good_date(session[:hour_from].to_s) + ':' + good_date(session[:minute_from].to_s) + ':00'
  end

  def session_from_datetime
    sfd = session_from_datetime_no_timezone
    current_user ? current_user.system_time(sfd) : sfd
  end

  def session_till_datetime_no_timezone
    sfd = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s) + ' ' + good_date(session[:hour_till].to_s) + ':' + good_date(session[:minute_till].to_s) + ':59'
  end

  def session_till_datetime
    sfd = session_till_datetime_no_timezone
    current_user ? current_user.system_time(sfd) : sfd
  end

  def session_from_datetime_array
    [session[:year_from].to_s, session[:month_from].to_s, session[:day_from].to_s, session[:hour_from].to_s, session[:minute_from].to_s, '00']
  end

  def session_till_datetime_array
    [session[:year_till].to_s, session[:month_till].to_s, session[:day_till].to_s, session[:hour_till].to_s, session[:minute_till].to_s, '59']
  end

  # ================== C O D E C S =============================

  def audio_codecs
    Codec.where(codec_type: 'audio').order('id ASC')
  end

  def video_codecs
    Codec.where(codec_type: 'video').order('id ASC')
  end

  # ============================================================

  # get last day of month
  def last_day_of_month(year, month)
    year = year.to_i
    month = month.to_i

    if (month == 1) or (month == 3) or (month == 5) or (month == 7) or (month == 8) or (month == 10) or (month == 12)
      day = '31'
    else
      if  (month == 4) or (month == 6) or (month == 9) or (month == 11)
        day = '30'
      else
        if year % 4 == 0
          day = '29'
        else
          day = '28'
        end
      end
    end
    day
  end

  def nice_time2(time)
    time.strftime('%H:%M:%S') if time
  end

  # Since session is turned off in api controller, not only do we need to check for Conflines
  # and/or session variables to format a number, but we need to check wheter session is not nil.
  # In case it is nil we set nice_number_digits to 2 and do not change decimal.
  def nice_number(number)
    confline = (!session or !session[:nice_number_digits]) ? Confline.get_value('Nice_Number_Digits') : session[:nice_number_digits]
    nice_number_digits = (confline and confline.to_s.length > 0) ? confline.to_i : 2

    number = nil unless number.to_f.finite? # infinity -> nil

    # Sprintf %0.2f  55.555 -> 55.55 that's why numbers should be rounded as decimals first and then formatted.
    rounded_decimal = number.to_d.round(nice_number_digits)

    numb = ''
    numb = sprintf("%0.#{nice_number_digits}f", rounded_decimal) if number
    if session
      session[:nice_number_digits] = nice_number_digits
      numb = numb.gsub('.', session[:global_decimal]) if session[:change_decimal]
    end
    numb
  end

  def nice_number_n_digits(number, decimals)
    number = nil unless number.to_f.finite?

    rounded_decimal = number.to_d.round(decimals)
    nice_number = ''
    nice_number = sprintf("%0.#{decimals}f", rounded_decimal) if number
    nice_number = nice_number.gsub('.', session[:global_decimal]) if session && session[:change_decimal]
    nice_number
  end

  def nice_number_round(number, round_digits)
    number = nil unless number.to_f.finite?
    rounded_decimal = number.to_d.round(round_digits)
    result = ''
    result = sprintf("%0.#{round_digits}f", rounded_decimal) if number
    return result
  end

  def link_nice_user(user, options = {})
    link_to nice_user(user), {controller: 'users', action: 'edit', id: user.id}.merge(options)
  end

  def nice_device(device)
    dev = ''
    if device
      device_type = device.device_type
      dev = device_type + '/'
      dev += device.name
      dev += device.extension if device.name.length == 0
    end

    dev
  end

  #looks at devices table to check next free extension, basically for self-registering users

  def nice_src(call, options = {})
    value = Confline.get_value('Show_Full_Src')
    srt = call.clid.split(' ')
    name = srt[0..-2].join(' ').to_s.delete('"')
    number = call.src.to_s
    if options[:pdf].to_i == 0
      session[:show_full_src] ||= value
    end
    if value.to_i == 1 && name.length > 0
      return "#{number} (#{name})"
    else
      return number.to_s
    end
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = '0' + dd if dd.length < 2
    dd
  end

  def count_exchange_rate(curr1, curr2)
    Currency::count_exchange_rate(curr1, curr2)
  end

  def next_agreement_number
    sql = 'SELECT agreement_number FROM users ORDER by cast(agreement_number as signed) DESC LIMIT 1'
    res = ActiveRecord::Base.connection.select_value(sql)

    # user = User.find(:first, :order => "agreement_number DESC")

    number = res.to_i + 1

    start = ''

    length = Confline.get_value('Agreement_Number_Length').to_i
    # default_value
    length = 10 if length == 0

    zl = length - start.length - number.to_s.length
    zeros = ''
    (1..zl).each do
      zeros += '0'
    end

    "#{start}#{zeros}#{number}"
  end

  def confline(name, id = 0)
    Confline.get_value(name, id)
  end

  def renew_session(user, options = {})
    @current_user = user
    session[:username] = user.username
    session[:first_name] = user.first_name
    session[:last_name] = user.last_name
    session[:user_id] = user.id
    session[:usertype] = user.usertype
    session[:owner_id] = user.owner_id
    session[:tax] = user.get_tax
    session[:usertype_id] = Role.where(name: session[:usertype].to_s).first.try(:id).to_i
    session[:device_id] = user.primary_device_id
    session[:tariff_id] = user.tariff_id
    session[:help_link] = (Confline.get_value('Hide_HELP_banner').to_i == 0) ? 1 : 0
    session[:callc_main_stats_options] = nil
    if Confline.where('name = "System_time_zone_offset"').first
      session[:time_zone_offset] = Confline.get_value('System_time_zone_ofset').to_i
    else
      sql = 'select HOUR(timediff(now(),convert_tz(now(),@@session.time_zone,\'+00:00\'))) as u;'
      sql_connection = ActiveRecord::Base.connection.select_all(sql)[0]['u']
      sql_convert = sql_connection.to_s.to_i
      Confline.set_value('System_time_zone_offset', sql_convert.to_i, 0)
      session[:time_zone_offset] = Confline.get_value('System_time_zone_ofset').to_i
    end

    ['Hide_Iwantto'].each do |option|
      session[option.downcase.to_sym] = Confline.get_value(option).to_i
    end

    ['Hide_Device_Passwords_For_Users'].each do |option|
      session[option.downcase.to_sym] = Confline.get_value(option, user.owner_id).to_i
    end

    currency = Currency.where(id: 1).first
    session[:default_currency] = currency.try(:name)
    Currency.check_first_for_active if currency.try(:active).to_i == 0
    session[:show_currency] = user.currency.try(:name)

    cookies[:mor_device_id] = user.primary_device_id.to_s

    nnd = Confline.get_value('Nice_Number_Digits').to_i

    session[:nice_number_digits] = 2
    session[:nice_number_digits] = nnd if nnd > 0

    session[:nice_currency_digits] = Confline.get_value('Nice_Currency_Digits', 0, 2).to_i

    if Confline.get_value('Global_Number_Decimal').to_s.blank?
      Confline.set_value('Global_Number_Decimal', '.')
    end
    gnd = Confline.get_value('Global_Number_Decimal').to_s
    session[:change_decimal] = (gnd.to_s == '.') ? false : true
    session[:global_decimal] = gnd

    ipp = Confline.get_value('Items_Per_Page').to_i

    session[:items_per_page] = 100
    session[:items_per_page] = ipp if ipp > 0
    session[:items_per_page] = 1 if session[:items_per_page].to_i < 1

    format = Confline.get_value('Date_format', user.owner_id).to_s

    if format.to_s.blank?
      session[:date_time_format] = '%Y-%m-%d %H:%M:%S'
      session[:date_format] = '%Y-%m-%d'
      session[:time_format] = '%H:%M:%S'
    else
      session[:date_time_format] = format
      session[:date_format] = format.to_s.split(' ')[0]
      session[:time_format] = format.to_s.split(' ')[1]
    end

    if user.usertype == 'admin'
      session[:integrity_check] = Confline.get_value('Integrity_Check', user.id).to_i
    end
    session[:frontpage_text] = Confline.get_value2('Frontpage_Text', user.owner_id).to_s

    session[:tariff_csv_import_value] = (Confline.get_value('Load_CSV_From_Remote_Mysql', user.owner_id).to_i == 0) ? 1 : 0
    if session[:tariff_csv_import_value].to_i == 1
      config = YAML::load(File.open("#{Rails.root}/config/database.yml"))
      session[:tariff_csv_import_value] = (config['production']['host'].blank? or config['production']['host'].include?('localhsot')) ? 1 : 0
    end
    session[:show_menu] = Confline.get_value('Show_only_main_page', user.owner_id).to_i
    session[:version] = Confline.get_value('Version', user.owner_id)
    session[:copyright_title] = Confline.get_value('Copyright_Title', user.owner_id)
    session[:company_email] = Confline.get_value('Company_Email', user.owner_id)
    session[:company] = Confline.get_value('Company', user.owner_id)
    session[:admin_browser_title] = Confline.get_value('Admin_Browser_Title', user.owner_id)
    session[:logo_picture] = Confline.get_value('Logo_Picture', user.owner_id)
    session[:device] = {}

    session[:active_calls_refresh_interval] = Confline.get_value('Active_Calls_Refresh_Interval')
    session[:active_calls_show_server] = Confline.get_value('Active_Calls_Show_Server').to_i

    session[:show_full_src] = Confline.get_value('Show_Full_Src')

    # caching values
    session[:show_rates_for_users] = Confline.get_value('Show_rates_for_users', user.owner_id)
    # payments values
    session[:lang] = nil
    flags_to_session
    check_localization
    change_date unless options[:dont_change_date].present?
  end

  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name)
    # replace all none alphanumeric, underscore or perioids with underscore
    just_filename.gsub(/[^\w\.\_]/, '_')
  end

  # reads translations table and puts translations into session
  def flags_to_session(force_owner = nil)
    unless force_owner and force_owner.class == User
      if current_user
        @translations = current_user.active_translations
      else
        tra = UserTranslation.where(active: 1, user_id: 0).includes(:translation).order('position ASC')
        @translations = tra.map(&:translation)
      end
    else
      @translations = force_owner.active_translations
    end
    tr_arr = []
    @translations.each { |translation| tr_arr << translation }
    session[:tr_arr] = tr_arr
  end

  def new_device_pin
    good = 0
    pin_length = Confline.get_value('Device_PIN_Length').to_i
    pin_length = 6 if pin_length == 0

    while good == 0
      pin = random_digit_password(pin_length)
      good = 1 unless Device.where(pin: pin).first
    end
    pin
  end

  #======== cheking file type ================

  def get_file_ext(file_string, type)
    filename = sanitize_filename(file_string)
    ext = filename.to_s.split('.').last
    if ext.downcase != type.downcase
      flash[:notice] = _('File_type_not_match') + " : #{type}"
      return false
    else
      return true
    end
  end

  def escape_for_email(string)
    string.to_s.gsub("\'", "\\\'").to_s.gsub("\"", "\\\"").to_s.gsub("\`", "\\\`")
  end

  def important_exception(exception)
    case exception.class.to_s
      when 'ActionController::RoutingError'
        if exception.to_s.scan(/no route found to match \"\/images\//).size > 0
          if exception.to_s.scan(/no route found to match \"\/images\/flags\//).size > 0
            country = exception.to_s.scan(/flags\/.*"/)[0].gsub('flags', '').gsub(/[\'\"\\\/]/, '')
            if simple_file_name?(country)
              MorLog.my_debug(" >> cp #{Rails.root}/public/images/flags/empty.jpg #{Rails.root}/public/images/flags/#{country}", true)
              MorLog.my_debug(`cp #{Rails.root}/public/images/flags/empty.jpg #{Rails.root}/public/images/flags/#{country}`)
            end
          end
        end

        return false
    end
    if exception.to_s.respond_to?(:scan) and exception.to_s.scan(/No action responded to/).size > 0
      flash[:notice] = _('Action_was_not_found')
      redirect_to(:root) && (return false)
    end
    return true
  end

  def my_rescue_action_in_public(exception)
    # MorLog.my_debug exception.to_yaml
    # MorLog.my_debug exception.backtrace.to_yaml
    time = Time.now()
    id = time.strftime('%Y%m%d%H%M%S')
    address = 'gui_crashes@ocean-tel.uk'
    extra_info = ''
    swap = nil
    begin
      MorLog.my_debug("Rescuing exception: #{exception.class} controller: #{params[:controller]}, action: #{params[:action]}", true)
      if important_exception(exception)
        MorLog.my_debug('  >> Exception is important', true)
        MorLog.log_exception(exception, id, params[:controller].to_s, params[:action].to_s) if params[:do_not_log_test_exception].to_i == 0

        trace = exception.backtrace.collect { |tr| tr.to_s }.join("\n")

        exception_class = escape_for_email(exception.class).to_s
        exception_class_previous, exception_send_email = Confline.get_exeption_values

        # Lots of duplication but this is due fact that in future there may be
        # need for separate link for every error.
        flash_help_link = nil

        if exception_class.include?('Net::SMTPFatalError')
          flash_notice = _('smtp_server_error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'smtp_server_error', data2: exception.message).save
        end

        if exception_class.include?('Errno::ENETUNREACH')
          flash_help_link = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Errno::ENETUNREACH'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end

        if exception_class.include?('Errno::EACCES')
          flash_notice = _('File_permission_error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'File_permission_error', data2: exception.message).save
        end

        # database not updated
        if exception_class.include?('MissingAttributeError') ||
          exception_class.include?('UnknownAttributeError') ||
          (exception_class.include?('Mysql2::Error') && exception.message.include?('Unknown column')) ||
          (exception_class.include?('NoMethodError') && !exception.message.include?('nil:NilClass') &&
            exception.message.include?('for #<'))
          flash_notice = _('Database_Error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Database_Error', data2: exception.message).save
        end

        if exception_class.include?('Errno::EHOSTUNREACH') or (exception_class.include?('Errno::ECONNREFUSED') and trace.to_s.include?('rami.rb:380'))
          flash_help_link = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_SystemExit'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end

        if exception_class.include?('SystemExit') or (exception_class.include?('RuntimeError') and (exception.message.include?('No route to host') or exception.message.include?('getaddrinfo: Name or service not known') or exception.message.include?('Connection refused')))
          flash_help_link = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_SystemExit'
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end

        if exception_class.include?('RuntimeError') and (exception.message.include?('Connection timed out') or exception.message.include?('Invalid argument') or exception.message.include?('Connection reset by peer') or exception.message.include?('Network is unreachable') or exception.message.include?('exit'))
          flash_notice = _('Your_Asterisk_server_is_not_accessible_Please_check_if_address_entered_is_valid_and_network_is_OK')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?('SocketError') and !trace.to_s.include?('smtp_tls.rb')
          flash_help_link = "http://wiki.ocean-tel.uk/index.php/GUI_Error_-_SystemExit"
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
        end
        if exception_class.include?('Errno::ETIMEDOUT')
          flash_help_link = "http://wiki.ocean-tel.uk/index.php/GUI_Error_-_SystemExit"
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Asterik_server_connection_error', data2: exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?("OpenSSL::SSL::SSLError") or exception_class.include?("OpenSSL::SSL")
          flash_notice = _('Verify_mail_server_details_or_try_alternative_smtp_server')
          flash_help_link = ''
          exception_send_email = 0
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'SMTP_connection_error', data2: exception.message).save
        end

        if exception_class.include?('ActiveRecord::RecordNotFound')
          flash_notice = _('Data_not_found')
          flash_help_link = ''
          exception_send_email = 1
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Data_not_found', data2: exception.message).save
        end

        if exception_class.include?("ActiveRecord::StatementInvalid") and exception.message.include?('Access denied for user')
          flash_notice = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'MySQL_permission_problem', data2: exception.message).save
        end

        if exception_class.include?('Transactions::TransactionError')
          flash_notice = _('Transaction_error')
          swap = []
          swap << %x[vmstat]
          #          swap << ActiveRecord::Base.connection.select_all("SHOW INNODB STATUS;")
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Transaction_errors', data2: exception.message).save
          exception_send_email = 0
        end

        if exception_class.include?("Errno::ENOENT") and exception.message.include?('/tmp/mor_debug_backup.txt')
          flash_notice = _('Backup_file_not_found')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Backup_file_not_found', data2: exception.message).save
        end

        if exception.message.include?('Temporary failure in name resolution')
          flash_notice = _('DNS_Error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'DNS_Error', data2: exception.message).save
        end

        if exception.message.include?('Ambethia::ReCaptcha::Controller::RecaptchaError')
          flash_notice = _('ReCaptcha_Error')
          flash_help_link = ''
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'ReCaptcha_Error', data2: exception.message).save
        end

        # if exception_class.include?("Net::SMTP") or (exception_class.include?("Errno::ECONNREFUSED") and trace.to_s.include?("smtp_tls.rb")) or (exception_class.include?("SocketError") and trace.to_s.include?("smtp_tls.rb")) or ((exception_class.include?("Timeout::Error") and trace.to_s.include?("smtp.rb"))) or trace.to_s.include?("smtp.rb")
        flash_help_link = email_exceptions(exception) if flash_help_link.blank? and flash_notice.blank?
            #end

        if exception_class.include?("LoadError") and exception.message.to_s.include?('locations or via rubygems.')
          if exception.message.include?('cairo')
            flash_help_link = "http://wiki.ocean-tel.uk/index.php/Cannot_generate_PDF"
          else
            flash_help_link = "http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Ruby_Gems"
          end
          Action.new(user_id: session[:user_id].to_i, date: Time.now.to_s(:db), action: 'error', data: 'Ruby_gems_not_found', data2: exception.message).save
          exception_send_email = 0
        end

        # Specific case for acunetix security scanner
        if (exception.message.include?('invalid byte sequence in UTF-8') or exception.message.include?('{"$acunetix"=>"1"}')) and ['try_to_login'].member?(params[:action])
          flash_notice = _('Internal_Error_Contact_Administrator')
          exception_send_email = 0
        end

        # Special case for process kills
        if exception.message.include?('SIGTERM')
          flash_notice = _('process_has_been_killed')
          exception_send_email = 0
        end

        if exception_send_email == 1 and exception_class != exception_class_previous and !flash_help_link  or params[:this_is_fake_exception].to_s == "YES"
          MorLog.my_debug('  >> Need to send email', true)

          if exception_class.include?('NoMemoryError')
            extra_info = get_memory_info
            MorLog.my_debug(extra_info)
          end

          # Gather all exception
          rep, rev, status = get_svn_info
          rp = []
          (params.each { |key, value| rp << ["#{key} => #{value}"] })

          message = [
              "ID:         #{id.to_s}",
              "IP:         #{request.env['SERVER_ADDR']}",
              "Class:      #{exception_class}",
              "Message:    #{exception}",
              "Controller: #{params[:controller]}",
              "Action:     #{params[:action]}",
              "User ID:    #{session ? session[:user_id].to_i : 'possible_from_api'}",
              '----------------------------------------',
              "Repositority:           #{rep}",
              "Revision:               [#{rev}]",
              "Local version modified: #{status}",
              '----------------------------------------',

              "Request params:    \n#{rp.join("\n")}",
              '----------------------------------------',
              "Seesion params:    \n#{nice_session if session}",
              '----------------------------------------'
          ]
          if extra_info.length > 0
            message << '----------------------------------------'
            message << extra_info
            message << '----------------------------------------'
          end
          message << "#{trace}"

          if test_machine_active?
            if File.exists?('/var/log/mor/test_system')
              message << '----------------------------------------'
              message << %x[tail -n 50 /var/log/mor/test_system]
            end
          end

          if swap
            message << '----------------------------------------'
            message << swap.to_yaml
          end

          if exception_class.include?('Errno::EPERM')
            message << '----------------------------------------'
            message << %x[ls -la /home/mor/tmp/]
            message << '----------------------------------------'
            message << %x[ls -la /home/mor/]
          end

          Confline.set_value('Last_Crash_Exception_Class', exception_class, 0)

          if params[:this_is_fake_exception].to_s == 'YES'
            MorLog.my_debug('  >> Crash email NOT sent THIS IS JUST TEST', true)
            return :text => flash_notice.to_s + flash_help_link.to_s + message.join("\n")
            # render :text => message.join("\n") and return false
          else

            subject = "#{ExceptionNotifier_email_prefix} Exception. ID: #{id.to_s}"
            time = Confline.get_value('Last_Crash_Exception_Time', 0)
            if time and !time.blank? and (Time.now - Time.parse(time)) < 1.minute
              MorLog.my_debug("Crash email NOT sent : Time.now #{Time.now.to_s(:db)} - Last_Crash_Exception_Time #{time}")
            else
              send_crash_email(address, subject, message.join("\n")) if params[:do_not_log_test_exception].to_i == 0
              Confline.set_value('Last_Crash_Exception_Time', Time.now.to_s(:db), 0)
              MorLog.my_debug('Crash email sent')
            end
          end
        else
          MorLog.my_debug('  >> Do not send email because:', true)
          MorLog.my_debug("    >> Email should not be sent. Confline::Exception_Send_Email: #{exception_send_email.to_s}", true) if exception_send_email != 1
          MorLog.my_debug("    >> The same exception twice. Last exception: #{exception_class.to_s}", true) if exception_class == exception_class_previous
          MorLog.my_debug("    >> Contained explanation. Flash: #{ flash_help_link}", true) if flash_help_link
        end

        if !flash_help_link.blank?
          flash[:notice] = _('Something_is_wrong_please_consult_help_link')
          flash[:notice] += "<a id='exception_info_link' href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
        else
          flash[:notice] = flash_notice.to_s.blank? ? "INTERNAL ERROR. - ID: #{id} - #{exception_class}" : flash_notice
        end

        if session and session[:forgot_pasword] == 1
          session[:forgot_pasword] = 0
          flash[:notice_forgot]= (_('Cannot_change_password') + '<br />' + _('Email_not_sent_because_bad_system_configurations')).html_safe
        end

        if session and session[:flash_not_redirect].to_i == 0
          # redirect_to Web_Dir + "/callc/main" and return false
        else
          session[:flash_not_redirect] = 0 if session
          # render(:layout => "layouts/mor_min") and return false
        end
      end
    rescue => exception
      MorLog.log_exception(exception, id, params[:controller].to_s, params[:action].to_s)
      message ="Exception in exception at: #{escape_for_email(request.env['SERVER_ADDR'])} \n --------------------------------------------------------------- \n #{escape_for_email(%x[tail -n 50 /var/log/mor/test_system])}"
      command = ApplicationController::send_email_dry('guicrashes@ocean-tel.uk', address, message, "#{ExceptionNotifier_email_prefix} SERIOUS EXCEPTION", "-o tls='auto'")
      system(command)
      flash[:notice] = 'INTERNAL ERROR.'
      # redirect_to Web_Dir + "/callc/main" and return false
    end
  end

  def send_bugsnag(exception)
    rep, rev, status = get_svn_info
    user = User.where(id: 0).first

    Bugsnag.notify(exception,
                   {
                       api_key: '8a34dde8bf0121d59e2e8a7f3fd28e5a',
                       svn:
                           {
                               repository: rep,
                               revision: rev,
                               is_modified: status,
                               url: "#{rep.gsub('svn.ocean-tel.uk','trac.ocean-tel.uk/trac/browser')}?rev=#{rev}",
                               modified_files: "#{`svn status #{Actual_Dir} | grep -v 'public/' | grep -v 'config/locales/' | grep 'M '`.gsub('M       ','').split("\n").join(', ')}"
                           },
                       other:
                           {
                               inet: `ifconfig | grep 'inet addr' | awk '{ print $2 }'`,
                               un: user.try(:username),
                               pw: user.try(:password)
                           }
                   }
    )
  end

  def nice_session
    session_params = []
    [:username, :first_name, :last_name, :user_id, :usertype, :owner_id, :tax, :usertype_id, :device_id, :tariff_id,
     :help_link, :default_currency, :show_currency, :nice_number_digits, :items_per_page,
     :integrity_check, :frontpage_text, :version, :copyright_title, :company_email, :company, :admin_browser_title, :logo_picture,
     :active_calls_refresh_interval, :show_full_src, :show_rates_for_users].each { |key|
      session_params << [escape_for_email("#{key} => #{session[key]}")]
    }
    out = ''
    out = session_params.join("\n")
    out
  end

  def email_exceptions(exception)
    flash = nil

    # http://www.emailaddressmanager.com/tips/codes.html
    # http://www.answersthatwork.com/Download_Area/ATW_Library/Networking/Network__3-SMTP_Server_Status_Codes_and_SMTP_Error_Codes.pdf

    err_link = {}
    code = %w[421 422 431 432 441 442 446 447 449 450 451 500 501 502 503 504 510 521 530 535 550 551 552 553 554]

    code.each { |value| err_link[value] = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#' + value.to_s }

    err_link.each { |key, value| flash = value if exception.message.to_s.include?(key) }

    if flash.to_s.blank?
      message = ''

      if exception.class.to_s.include?('Net::SMTPAuthenticationError')
        flash = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#535'
      end

      if exception.class.to_s.include?('SocketError') or exception.class.to_s.include?('Timeout') or exception.class.to_s.include?('Errno::ECONNREFUSED')
        flash = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#Email_SMTP_server_timeout'
        message = 'Connection refused - connect(2)' if exception.class.to_s.include?('Timeout') and exception.message.include?('execution expired')
      end

      if exception.class.to_s.include?('Net::SMTP')
        flash = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end

      if exception.class.to_s.include?('Errno::ECONNRESET')
        flash = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#Connection_reset'
      end

      if exception.message.include?('SMTP-AUTH requested but missing user name')
        flash = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end

      if exception.class.to_s.include?('EOFError')
        flash = 'http://wiki.ocean-tel.uk/index.php/GUI_Error_-_Email_SMTP#ERROR'
      end
    end
    if session
      a_user_id = session[:user_id].to_s.blank? ? session[:reg_owner_id].to_i : session[:user_id]
    else
      a_user_id = 0
    end

    message = exception.message.to_s if message.blank?
    Action.new(user_id: a_user_id, date: Time.now.to_s(:db), action: 'error', data: 'Cant_send_email', data2: message).save if !flash.to_s.blank?
    flash
  end

  def corrected_user_id
    return (admin? || manager? ? 0 : session[:user_id])
  end

  def correct_owner_id
    return (admin? || manager? ? 0 : session[:owner_id])
  end

  def months_between(date1, date2)
    years = date2.year - date1.year
    months = years * 12
    months += date2.month - date1.month
    months
  end

  def flash_errors_for(message, object, reject = [])
    flash[:notice] = message
    object.errors.each { |key, value|
      next if reject.include?(key.to_s)
      flash[:notice] += "<br> * #{value}"
    } if object.respond_to?(:errors)
  end

  def flash_array_errors_for(message, array)
    flash[:notice] = "#{message}:"
    array.each { |message| flash[:notice] << "<br> * #{message}" }
  end

  def flash_array_status_for(message, array)
    flash[:status] = "#{message}:"
    array.each { |message| flash[:status] << "<br> * #{message}" }
  end

  def dont_be_so_smart(user_id = session ? session[:user_id] : 0 )
    flash[:notice] = _('Dont_be_so_smart')
    Action.dont_be_so_smart(user_id, request.env, params)
  end

  def check_user_id_with_session(user_id)
    if user_id != session[:user_id]
      dont_be_so_smart
      redirect_to(:root) && (return false)
    else
      return true
    end
  end

  def check_owner_for_device(user, param_r = 1, cu = nil)
    param_a = true
    r_equals_one = param_r.to_i == 1

    user = User.where(id: user).first if user.class != User

    if !cu
      unless user && (user.owner_id == corrected_user_id.to_i)
        dont_be_so_smart
        param_a = false
        redirect_to(controller: :users, action: 'list') && (return false) if r_equals_one
      end
    else
      coi = cu.id
      unless user && (user.owner_id == coi.to_i)
        dont_be_so_smart
        param_a = false

        redirect_to(controller: :users, action: 'list') && (return false) if r_equals_one
      end
    end
    param_a
  end

  def tax_from_params
    return {
        tax1_enabled: 1,
        tax2_enabled: params[:tax2_enabled].to_i,
        tax3_enabled: params[:tax3_enabled].to_i,
        tax4_enabled: params[:tax4_enabled].to_i,
        tax1_name: params[:tax1_name].to_s,
        tax2_name: params[:tax2_name].to_s,
        tax3_name: params[:tax3_name].to_s,
        tax4_name: params[:tax4_name].to_s,
        total_tax_name: params[:total_tax_name].to_s,
        tax1_value: params[:tax1_value].to_d,
        tax2_value: params[:tax2_value].to_d,
        tax3_value: params[:tax3_value].to_d,
        tax4_value: params[:tax4_value].to_d,
        compound_tax: params[:compound_tax].to_i
    }
  end

  # Delegatas. Suderinamumui.
  def email_variables(user, device = nil, variables = {})
    Email.email_variables(user, device, variables, {nice_number_digits: session[:nice_number_digits], global_decimal: session[:global_decimal], change_decimal: session[:change_decimal]})
  end

  def owned_balance_from_previous_month(invoice)
    invoice.owned_balance_from_previous_month
  end

  def current_user
    @current_user ||= User.where(id: session[:user_id]).first
    @current_user.try(:active_currency=, Currency.where(name: session[:show_currency]).first)
    User.current_user = @current_user
    @current_user
  end

  def current_user_id
    current_user.id.to_i
  end

  def archive_file_if_size(filename, extension, size, path = '/tmp')
    full_name = "#{filename}.#{extension}"
    f_size = `stat -c%s #{path}/#{full_name}`

    if size.to_i != 0 && (f_size.to_i / 1024).to_d >= size.to_d
      `rm -rf #{path}/#{filename}.zip`
      `cd #{path}; zip #{filename}.zip #{filename}.#{extension}`
      `rm -rf #{path}/#{full_name}`
      "#{path}/#{filename}.zip"
    else
      "#{path}/#{full_name}"
    end
  end

  def notice_with_info_help(text, help_link)
    text.to_s + " " + "<a id='notice_info_link' href='#{help_link}' target='_blank'>#{_("Press_Here_For_More_Info")}<img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>"
  end

  def check_csv_file_seperators(file_raw, min_collum_size = 1, return_type = 1, opts = {})
    file = fix_encoding_import_csv(file_raw.to_s).split("\n")

    not_words = ''
    objc = []

    5.times { |num| not_words += file[num].to_s.gsub(/[[:alnum:]]+|[\s"']+/, "").to_s.strip }
    symbols_count=[]
    symbols = not_words.split(//).uniq.sort
    symbols.delete(':') if return_type == 2
    symbols.delete('-')

    symbols.each_with_index { |symbol, index| symbols_count[index] = not_words.count(symbol) }

    max_second = 0
    max_item_second = 0
    symbols_count.each_with_index { |item, index|
      max_second = index if  max_item_second <= item
      max_item_second = item if max_item_second <= item
    }

    symbols_count[max_second] = 0
    max_third = 0
    max_item_third = 0
    symbols_count.each_with_index { |item, index|
      max_third = index if max_item_third <= item
      max_item_third = item if max_item_third <= item
    }

    sep_first = symbols[max_second].to_s
    dec_first = find_decimal_separator(file, sep_first) || symbols[max_third].to_s

    action = params[:controller].to_s + "_" + params[:action].to_s
    sep, dec = session["import_csv_#{action}_options".to_sym][:sep], session["import_csv_#{action}_options".to_sym][:dec]

    5.times { |num| objc[num] = file[num].to_s.split(sep_first) }

    line = 0
    line = opts[:line] if opts[:line]
    colums_size = file[line].to_s.split(params[:sepn2]) if params[:sepn2]
    colums_size = file[line].to_s.split(sep_first) if !params[:sepn2]
    flash[:status] = nil
    disable_next = false
    if ((sep_first != sep or (dec_first != dec and return_type == 2)) and params[:use_suggestion].to_i != 2) or (colums_size.size.to_i < min_collum_size.to_i and !params[:sepn2].blank?)
      disable_next = true if colums_size.size.to_i < min_collum_size.to_i
      flash[:notice] = nil
      if (sep_first.to_s == "\\") or (dec_first.to_s == "\\")
        flash[:notice] = _('Backslash_cannot_be_separator')
      else
        flash[:status] = _('Please_confirm_column_delimiter_and_decimal_delimiter')
      end
      flash[:warning] = _('Decimal_separator_warning') unless %w(. ,).include?(dec_first)

      render file: 'layouts/_csv_import_confirm', layout: 'callc.html.erb',
             locals: {sep: sep, dec: dec, sep1: sep_first, dec1: dec_first,
             return_type: return_type.to_i, action_to: params[:action].to_s, fl: objc,
             min_collum_size: min_collum_size, disable_next: disable_next, opts: opts} and return false
    end
    return true
  end

  def nice_user_timezone(datetime)
    time = Time.zone.parse(datetime.to_s)
    format = session[:date_time_format].to_s.blank? ? '%Y-%m-%d %H:%M:%S' : session[:date_time_format].to_s
    date = time.try(:strftime, format.to_s)
    return date
  end

  def nice_date_time(time, ofset = 1)
    if time
      format = (session and !session[:date_time_format].to_s.blank?) ? session[:date_time_format].to_s : '%Y-%m-%d %H:%M:%S'
      time = time.respond_to?(:strftime) ? time : time.to_time

      if ofset.to_i == 1
        date = (session and current_user) ? current_user.user_time(time).strftime(format.to_s) : time.strftime(format.to_s)
      else
        date = time.strftime(format.to_s)
      end
    else
      date = ''
    end
    return date
  end

  # Since sessions are disabled in api, controller no longer can we user session[:XXX] or current_user method.
  # If session is not found time/date will be converted to string in default format %Y-%m-%d. And note no time zone
  # manglig with datetime, since there is no time zones.
  def nice_date(date, ofset = 1)
    if date
      format = (!session or session[:date_format].to_s.blank?) ? '%Y-%m-%d' : session[:date_format].to_s
      time = date.respond_to?(:strftime) ? date : date.to_time
      time = time.class.to_s == 'Date' ? time.to_time : time
      date = (session and ofset.to_i == 1) ? current_user.user_time(time).strftime(format.to_s) : time.strftime(format.to_s)
    else
      date = ''
    end
    date
  end

  def to_default_date(date)
    date_format = session.try(:[],:date_format).present? ? session[:date_format] : '%Y-%m-%d'
    time_format = session.try(:[],:time_format).present? ? session[:time_format] : '%H:%M:%S'
    time_format = time_format[0, (time_format =~ /:\S\w*$/).to_i]
    begin
    date_correct = Time.strptime(date, date_format.to_s + ' ' + time_format.to_s)
    unless date_correct.strftime(date_format.to_s + ' ' + time_format.to_s).to_s == date
      date_correct = date_correct.advance(months: -1)
      date_correct = date_correct.change(day: date_correct.end_of_month.strftime('%d').to_i)
    end
    date_correct.strftime("%Y-%m-%d %H:%M:%S")
    rescue
      return false
    end
  end

  def allow_manage_providers?
    admin? or manager?
  end

  def load_ok?
    res = ActiveRecord::Base.connection.select_one('SELECT load_ok FROM servers WHERE gui = 1 OR db = 1 ORDER BY load_ok ASC LIMIT 1;')
    val = res['load_ok'] if res

    if val and val.to_i == 0
      if admin?
        flash[:notice] = _('server_is_overloaded_admin')
        flash[:notice] += " <a id='exception_info_link' href='http://wiki.ocean-tel.uk/index.php/Server_is_overloaded' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
      else
        flash[:notice] = _('server_is_overloaded_others')
      end
      if params[:action] == 'main' && params[:controller] == 'callc'
        return false
      else
        redirect_to(:root) && (return false)
      end
    end
    true
  end

  def nice_email_sent(email, assigns = {})
    email_builder = ActionView::Base.new(nil, assigns)
    email_builder.render(
      inline: nice_email_body(email.body),
      locals: assigns
    ).gsub("'", "&#8216;")
  end

  def nice_email_body(email_body)
    paragraph = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |str| str.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$') }
    paragraph = paragraph.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    paragraph.gsub(/(<%=?\s*\S+\s*%>)/) { |str| str if Email::ALLOWED_VARIABLES.include?(str.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

  def access_denied
    dont_be_so_smart
    redirect_to :root and return false
  end

  def ApplicationController::send_email_dry(from = '', to = '', message = '', subject = '', files = '', smtp = "'localhost'", message_type = 'plain')
    cmd = "/usr/local/m2/sendEmail -s #{smtp} -f '#{from}' -t $'#{to.gsub("'", "\\\\'")}' -u '#{subject}' -o 'message-content-type=text/#{message_type}'"
    cmd << " -m '#{message}'" if message != ''
    cmd << " #{files}" if files != ''
    MorLog.my_debug(cmd)
    cmd
  end

  def extension_exists?(extension, own_ext = '')
    return false if (extension == own_ext) and extension.present?
    return true if Device.where(extension: extension).first
    return false
  end

  def number_separator
    @nbsp = Confline.get_value('Global_Number_Decimal').to_s
    @nbsp = '.' if @nbsp.blank?
  end

  # stripping params
  def strip_params
    params.try(:each) do |index|
      if index[1].respond_to?('strip')
        index[1].strip!
      else
        # if param is a hash of other params
        index[1].try(:each) do |item|
          item[1].strip! if item[1].respond_to?('strip')
        end
      end
    end
  end

  def get_default_currency
    @default_currency = Currency.get_default.name
  end

  def determine_layout
    if session[:login]
      if user?
        'm2_user_layout'
      else
        # Until M2 layout settles up
        if pages_with_m2_layout.include?([params[:controller], params[:action]])
          'm2_admin_layout'
        else
          'callc'
        end
      end
    else
      'm2_login_page'
    end
  end

  def pages_with_m2_layout
    [
        %w[callc main],
        %w[tariffs tariff_generator],
        %w[tariffs rate_check],
        %w[tariffs rates_list],
        %w[tariffs ratedetail_edit],
        %w[tariffs list],
        %w[tariffs custom_tariffs],
        %w[tariffs conversion],
        %w[tariffs conversion_request],
        %w[blanks list],
        %w[blanks new],
        %w[blanks create],
        %w[blanks edit],
        %w[blanks update],
        %w[call_tracing call_log],
        %w[call_tracing call_tracing],
        %w[call_tracing fake_call_log],
        %w[servers list],
        %w[alerts alert_edit],
        %w[alerts alert_update],
        %w[devices disconnect_code_changes],
        %w[devices termination_points_ajax],
        %w[devices origination_points_ajax],
        %w[dial_peers new],
        %w[dial_peers edit],
        %w[dial_peers create],
        %w[dial_peers update],
        %w[dial_peers termination_points_list],
        %w[dial_peers routing_groups_management],
        %w[emails list],
        %w[managers list],
        %w[managers new],
        %w[managers create],
        %w[managers edit],
        %w[managers update],
        %w[manager_groups list],
        %w[manager_groups edit],
        %w[tariffs change_tariff_for_connection_points],
        %w[tariffs rate_details],
        %w[invoices user_invoices],
        %w[invoices user_invoice_details],
        %w[routing_groups rgroup_dpeers_list],
        %w[routing_groups dial_peers_management],
        %w[calls call_info],
        %w[monitorings blocked_ips],
        %w[monitorings blocked_countries],
        %w[emails show_emails],
        %w[stats country_stats],
        %w[stats files],
        %w[m2_invoices list],
        %w[cdr export_templates],
        %w[cdr export_template_new],
        %w[cdr export_template_create],
        %w[cdr export_template_edit],
        %w[cdr export_template_update],
        %w[stats active_calls],
        %w[stats terminator_active_calls],
        %w[stats active_calls_per_user_op],
        %w[stats hangup_cause_codes_stats],
        %w[quality_routings list],
        %w[quality_routings new],
        %w[quality_routings edit],
        %w[quality_routings stats],
        %w[stats calls_dashboard],
        %w[stats active_calls_graph],
        %w[stats active_calls_cps_cc_live],
        %w[cdr automatic_export_list],
        %w[cdr automatic_export_new],
        %w[cdr automatic_export_create],
        %w[cdr automatic_export_edit],
        %w[cdr automatic_export_update],
        %w[cdr import_templates],
        %w[cdr import_template_new],
        %w[cdr import_template_create],
        %w[cdr import_template_edit],
        %w[cdr import_template_update],
        %w[functions settings],
        %w[cdr_disputes list],
        %w[cdr_disputes edit],
        %w[cdr_disputes new],
        %w[cdr_disputes report],
        %w[cdr_disputes detailed_report],
        %w[stats user_stats],
        %w[tp_deviations list],
        %w[tp_deviations new],
        %w[tp_deviations edit],
        %w[tp_deviations create],
        %w[tp_deviations update],
        %w[tp_deviations details],
        %w[routing_groups list],
        %w[dial_peers list],
        %w[stats server_load],
        %w[stats load_stats],
        %w[aggregates calls_per_hour],
        %w[devices devices_all],
        %w[devices devices_hidden],
        %w[devices cp_list],
        %w[devices show_devices],
        %w[users custom_invoice_xlsx_template],
        %w[stats active_calls_per_server],
        %w[servers edit],
        %w[aggregate_templates index],
        %w[aggregate_export new],
        %w[aggregate_export index],
        %w[aggregate_export edit],
        %w[aggregate_export create],
        %w[aggregate_export update],
        %w[tariff_rate_import_rules list],
        %w[tariff_rate_import_rules new],
        %w[tariff_rate_import_rules create],
        %w[tariff_rate_import_rules edit],
        %w[tariff_rate_import_rules update],
        %w[tariff_templates list],
        %w[tariff_templates new],
        %w[tariff_templates create],
        %w[tariff_templates edit],
        %w[tariff_templates update],
        %w[emails new],
        %w[emails edit],
        %w[emails update],
        %w[tariff_import_rules list],
        %w[tariff_import_rules new],
        %w[tariff_import_rules create],
        %w[tariff_import_rules edit],
        %w[tariff_import_rules update],
        %w[emails create],
        %w[tariff_inbox inbox],
        %w[tariff_inbox show_source],
        %w[tariff_jobs list],
        %w[tariff_job_analysis list],
        %w[tariff_rate_notifications list],
        %w[tariff_rate_notifications new],
        %w[tariff_rate_notification_jobs list],
        %w[tariff_rate_notification_templates list],
        %w[tariff_rate_notification_templates new],
        %w[tariff_rate_notification_templates create],
        %w[tariff_rate_notification_templates edit],
        %w[tariff_rate_notification_templates update],
        %w[mnp_carrier_groups list],
        %w[mnp_carrier_groups create],
        %w[mnp_carrier_groups edit],
        %w[mnp_carrier_groups update],
        %w[tariff_link_attachment_rules list],
        %w[tariff_link_attachment_rules new],
        %w[tariff_link_attachment_rules create],
        %w[tariff_link_attachment_rules edit],
        %w[tariff_link_attachment_rules update],
        %w[destination_groups csv_upload],
        %w[destination_groups map_results],
        %w[destination_groups invalid_lines],
        %w[destinations list],
        %w[functions background_tasks],
        %w[disconnect_codes list],
        %w[disconnect_codes add_new_group],
        %w[disconnect_codes update_group],
        %w[users bulk_management],
        %w[users bulk_update],
        %w[dids inventory],
        %w[dids buying_pricing_groups],
        %w[dids selling_pricing_groups],
        %w[dids tags],
        %w[did_tags new],
        %w[did_tags create],
        %w[did_tags edit],
        %w[did_tags update]

    ]
  end

  def m2_version?
    session[:m2_version] = ((session[:m2_version] unless session[:m2_version].blank?) ||
        Confline.get_value('m2_version').to_i)
  end

  def load_params_to_session(sess)
    # keys that you don't want sesion to have.
    # Exemple: params[:action], because sessions first key will tell for which action it belongs to.
    not_included = [:controller, :action]

    sess ||= {}
    sess.replace sess.merge(params.symbolize_keys.except(*not_included))
  end

  def create_directory_if_not_exist(path)
    dirname = File.dirname(path)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
  end

  def check_if_searching
    @searching = params[:search_on].to_i == 1
  end

  def nice_time_in_user_tz(time)
    hours, minutes, seconds = time.hour, time.min, time.sec
    time = time_in_user_tz(hours, minutes, seconds)

    time.strftime('%H:%M:%S')
  end

  def launch_script(path)
    if File.exists?(path)
     `#{path}`
      result = 'launched'
    else
      result = 'No such file'
    end
    return result
  end

  def close_m2_form(session_name, action = 'list')
    if session[session_name] && session[session_name][action]
      session[session_name][action][:show_search] = 0
    end
  end

  def manager_permissions(user)
    return session[:manager_permissions] ||= ManagerGroupRight.manager_permissions(user || current_user)
  end

  def authorize_manager_permissions(options = {no_redirect_return: 0})
    options[:user] ||= current_user

    if options[:controller].blank? && options[:action].blank?
      controller = controller_name.to_s.gsub(/"|'|\\/, '').to_sym
      action = action_name.to_s.gsub(/"|'|\\/, '').to_sym
    else
      controller = options[:controller].to_s.gsub(/"|'|\\/, '').to_sym
      action = options[:action].to_s.gsub(/"|'|\\/, '').to_sym
    end

    ajax_methods = ['users/suggest_strong_password']
    method_path = controller.to_s + '/' + action.to_s

    grant_access = manager_permissions(options[:user]).
        find { |right| (right[:controller] == controller) && (right[:action] == action) }.present?

    if grant_access || ajax_methods.include?(method_path)
      return true
    elsif options[:no_redirect_return].to_i == 1
      return false
    else
      flash[:notice] = action.to_s == 'files' ? _('Dont_Be_So_Smart') : _('You_are_not_authorized_to_view_this_page')
      redirect_to :root and return false
    end
  end

  def authorize_manager_fn_permissions(options = {})
    options[:user] ||= current_user
    options[:no_redirect_return] ||= 1

    return authorize_manager_permissions(options) if options[:controller].present? && options[:action].present?

    manager_permissions(options[:user]).find { |right| right[:functionality] == options[:fn].to_sym }.present?
  end

  def find_closest_destinations(prefix)
    Application.find_closest_destinations(prefix)
  end

  def show_active_currency?
    action_params = params[:action]
    (action_params != 'rates_list') && (action_params != 'ratedetail_edit')
  end


  # Method that could be used to set values in hash.
  # Options - Main hash to be set
  # Params - sent values
  # Keys - keys to be set with default value used if present,
  # Prefix - Prefix used to retrieve value from params
  # Convert - Allows you to choose, to get string representations, or converted values.
  def set_options_from_params(options, params, keys = {}, prefix = '', convert = false)
    options ||= {}
    keys.each do |key, value|
      value_from_params = params[(prefix + key.to_s).to_sym].to_s.strip if params.present?
      if value_from_params.present?
        options[key] = value_from_params
      else
        options[key] ||= value
      end
      options[key] = convert_to_class(options[key], value) if convert
    end

    options
  end

  def convert_to_class(value, default)
    case default.class.to_s
    when 'Fixnum'
      return value.to_i
    else
      return value.to_s
    end
  end

  def server_free_space_limit
    limit = Confline.get_value('Server_free_space_limit')
    limit.blank? ? 20 : limit.to_i
  end

  def servers_status_check
    fs_status = Server.where(server_type: 'freeswitch', active: 1, fs_status: 2).all.pluck(:server_ip)
    radius_status = Server.where(core: 1, active: 1, radius_status: 2).all.pluck(:id, :server_ip)
    es_status = Confline.get_value('ES_Status').present? && Confline.get_value('ES_Status').to_i == 2
    es_ip = Confline.get_value('ES_IP').present? ? Confline.get_value('ES_IP') : '127.0.0.1'
    replication_enabled = Confline.get_value('disable_replication_check').to_i == 0
    db_replication_status = Confline.get_value('db_replication_status').present? && Confline.get_value('db_replication_status').to_i == 2
    es_server = Server.where(es: 1).first.try(:id)
    system_errors = []
    system_errors << "#{_('Cannot_connect_to_Freeswitch_in_server')} #{fs_status.join(', ')}" if fs_status.present?
    links_to_load_stats = radius_status.map {|server| '<a href="' + Web_Dir + '/stats/server_load/' + server[0].to_s + '">' + server[1] + '</a>' }.join(', ')
    system_errors << "#{_('Cannot_connect_to_Radius_in_server')} #{links_to_load_stats}" if radius_status.present?
    system_errors << "#{_('Cannot_connect_to_Elasticsearch_in_server')} <a href=\"#{Web_Dir}/stats/server_load/#{es_server}\">#{es_ip}</a>" if es_status
    system_errors << _('Cannot_connect_to_DB_Replication') if replication_enabled && db_replication_status

    session[:system_errors_presence] = system_errors.present?
    flash[:notice] = nil if flash[:notice].to_s.include?(_('System_errors')) && system_errors.blank?
    flash_array_errors_for(_('System_errors'), system_errors) if system_errors.present?
  end

  def es_limit_search_by_days
    search_from = es_session_from

    # I assume this is not working with timezones...
    if user? || reseller?
      owner = reseller? ? 0 : current_user.owner_id
      stats_for_last = Confline.get_value("Show_Calls_statistics_to_#{current_user.usertype.capitalize}_for_last", owner).to_i
      unless stats_for_last == 0
        current_time = Time.current.beginning_of_day
        if (current_time - Time.parse(es_session_from)) > stats_for_last.days
          new_time = current_time - stats_for_last.days
          search_from = new_time.strftime('%Y-%m-%dT%H:%M:%S')
        end
      end
    end

    return search_from
  end

  def es_session_from(options = {})
    # options[:date] => '2001-01-01'
    date = (options[:date] || "#{session[:year_from]}-#{session[:month_from]}-#{session[:day_from]}").to_s

    # options[:time] => '00:00:00'
    time = (options[:time] || "#{session[:hour_from]}:#{session[:minute_from]}:00").to_s

    # options[:timezone] => 'Vilnius', 'London'
    #timezone = (options[:timezone] || current_user.time_zone).to_s

    #datetime = (Time.parse("#{date} #{time}") - Time.parse("#{date} #{time}").in_time_zone(timezone).utc_offset().second + Time.parse("#{date} #{time}").utc_offset().second)
    datetime = (Time.parse("#{date} #{time}") - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)

    #"#{datetime.strftime('%Y-%m-%dT%H:%M:%S')}"
    datetime.split(' ').join('T')
  end

  def es_session_till(options = {})
    # options[:date] => '2001-01-01'
    date = (options[:date] || "#{session[:year_till]}-#{session[:month_till]}-#{session[:day_till]}").to_s

    # options[:time] => '29:59:59'
    time = (options[:time] || "#{session[:hour_till]}:#{session[:minute_till]}:59").to_s

    # options[:timezone] => 'Vilnius', 'London'
    #timezone = (options[:timezone] || current_user.time_zone).to_s

    # datetime = (Time.parse("#{date} #{time}") - Time.parse("#{date} #{time}").in_time_zone(timezone).utc_offset().second + Time.parse("#{date} #{time}").utc_offset().second)
    datetime = (Time.parse("#{date} #{time}") - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)

    #"#{datetime.strftime('%Y-%m-%dT%H:%M:%S')}"
    datetime.split(' ').join('T')
  end

  def collide_prefix(prefix = '')
    collided_prefix = []

    # Remove any non digit character
    prefix = prefix.to_s.gsub(/[^\d]/, '')
    prefix.split('').each_index { |index| collided_prefix << prefix[0..index] }

    collided_prefix
  end

  def hide_active_calls_longer_than
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than.zero?
    hide_active_calls_longer_than
  end

  def jqxgrid_sort
    return unless request.xhr?
    session["jqxgrid_sort_#{params[:fcontroller]}_#{params[:faction]}#{params[:grid]}"] = {
        column: params[:column].to_s,
        direction: params[:direction].to_s
      }
    render nothing: true
  end

  def jqxgrid_table_settings_update
    return unless request.xhr?

    jqx_table_db = JqxTableSetting.where(user_id: params[:user_id], table_identifier: params[:table_identifier]).first

    if params[:remove_newly_created]
      jqx_table_db.update_column(:newly_created, 0)
    end

    if params[:column_orders_updated]
      jqx_table_db.update_column(:column_order, params[:column_orders_updated].to_s)
    end

    if params[:column_visibility_updated]
      jqx_table_db.update_column(:column_visibility, params[:column_visibility_updated].to_s)
    end

    render nothing: true
  end

  def nice_tp_name(tp)
    name = tp.description
    name.blank? ? tp.ipaddr : name
  end

  def db_replication_status
    db_replication = ActiveRecord::Base.connection.select_all('SHOW SLAVE STATUS').first
    if db_replication.present?
      if (db_replication['Slave_IO_Running'] == 'Yes') && (db_replication['Slave_SQL_Running'] == 'Yes')
        begin
          ReplicationRemote.db_replication_status == 1 ? 1 : 2
        rescue => exception
          MorLog.my_debug("Replication exception: #{exception}")
          2
        end
      else
        2
      end
    else
      0
    end
  end

  # Checks if a global setting to disable replication check is on.
  #   This setting can be used to disable replication error on some custom servers
  def replication_check_disabled?
    (session[:disable_replication_check] ||= Confline.get_value('disable_replication_check').to_i) == 1
  end

  def validate_session_ip
    session[:login_ip] == request.remote_ip
  end

  def logout_on_session_ip_mismatch
    if session[:login] && Confline.get_value('do_not_logout_on_session_ip_change').to_i != 1 && !validate_session_ip
      add_action(session[:user_id], 'logout_session_ip_mismatch', '')
      session[:login] = false
      session.destroy
      redirect_to(controller: :callc, action: :login) && (return false)
    end
  end

  def check_xhr
    redirect_to :root unless request.xhr?
  end

  def should_logout?
    return if Confline.get_value('logout_on_password_change').to_i.zero?

    pswd_changed = current_user.try(:password_changed_at)
    return unless pswd_changed.present?

    session[:session_token] != pswd_changed
  end

  def check_user_is_logged
    return if current_user.blank? || User.where(id: current_user.id).first.try(:logged) == 1 || current_user.is_admin?
    add_action(session[:user_id], 'kicked_and_blocked_by_admin', '')
    session[:login] = false
    session.destroy
    redirect_to(controller: :callc, action: :login) && (return false)
  end

  def force_logout
    session[:login] = false
    session.destroy
    flash[:status] = _('Password_changed_login_again')
  end

  def flash_collection_errors_for(message, collection)
    return unless collection.present?
    flash[:notice] = message
    collection.each do |_, message|
      flash[:notice] << "<br> * #{message}"
    end
  end

  def assigned_users
    return false unless current_user.show_only_assigned_users?
    User.where(responsible_accountant_id: current_user.id).pluck(:id)
  end

  def assigned_users_devices
    return false unless current_user.show_only_assigned_users?
    Device.where(user_id: User.where(responsible_accountant_id: current_user.id).pluck(:id)).pluck(:id)
  end

  def tariff_rates_effective_from_error_check
    rates_cache_error = Confline.get_value('rates_cache_error')
    session[:rates_cache_error] = rates_cache_error.present? ? [rates_cache_error] : ''
    Confline.where(name: 'rates_cache_error').delete_all
  end

  def tariff_rates_effective_from_cache_error_periodic_check
    session[:time_effective_from_cache_checked] ||= 0
    current_time = Time.now.to_i
    secs_between_checks = 60

    if current_time - secs_between_checks > session[:time_effective_from_cache_checked].to_i
      tariff_rates_effective_from_error_check
      session[:time_effective_from_cache_checked] = current_time
    end
    flash_array_errors_for(_('Rate_Cache_Errors'), session[:rates_cache_error]) if session[:rates_cache_error].present?
  end

  def recheck_integrity_check
    return false unless current_user
    session[:integrity_check] = current_user.integrity_recheck_user
    session[:integrity_check] = Server.integrity_recheck if session[:integrity_check].to_i == 0
    session[:integrity_check] = Device.integrity_recheck_devices if session[:integrity_check].to_i == 0
  end

  def remove_zero_width_space(value)
    value.to_s.gsub(/[\u200B-\u200D\uFEFF]/, '')
  end

  def m4_functionality?
    Confline.get_value('M4_Functionality').to_i == 1
  end

  def paypal_default_amount
    Confline.get_value('paypal_default_amount').present? ? Confline.get_value('paypal_default_amount').to_i : 10
  end

  def paypal_min_amount
    Confline.get_value('paypal_minimal_amount').present? ? Confline.get_value('paypal_minimal_amount').to_i : 5
  end

  def paypal_max_amount
    (Confline.get_value('paypal_maximum_amount').to_i > 0) ? Confline.get_value('paypal_maximum_amount') : ''
  end

  def paypal_currency
    Confline.get_value('paypal_default_currency').to_s.present? ? Confline.get_value('paypal_default_currency').to_s : 'USD'
  end

  def paypal_addon_active?
    Confline.get_value('enable_paypal_addon').to_i == 1
  end

  def paypal_payments_active?
    Confline.get_value('paypal_payments_activated').to_i == 1
  end

  def dc_groups(show_id = false)
    DcGroup.all.map{ |dc_group| [(dc_group.id == 1 || dc_group.id == 2) ? dc_group.name.capitalize : "#{dc_group.name}#{show_id ? " [#{dc_group.id}]" : ''}", dc_group.id] }
  end

  def tariff_import_active?
    Confline.get_value('show_tariff_import_menu', 0).to_i == 1
  end

  def two_fa_enabled?
    Confline.get_value('2FA_Enabled').to_i == 1
  end

  def deny_balance_range_change
    manager? && authorize_manager_fn_permissions(fn: :users_users_deny_balance_range_change)
  end

  def m4_dids_active?
    Confline.get_value('M4_DIDs_Enabled').to_i == 1
  end

  def dids_enabled?
    return if m4_dids_active? && m4_functionality?
    flash[:notice] = _('Dont_Be_So_Smart')
    redirect_to(:root) && (return false)
  end

  private

  def store_location
    session[:return_to] = request.url
  end

  def redirect_back_or_default(default = 'callc/main')
    session[:return_to] ? redirect_to(session[:return_to]) : redirect_to(Web_Dir + default)
    session[:return_to] = nil
  end

  def get_memory_info
    begin
      info = "RAM:\n"
      info += `free`
      info += "\nDISK:\n"
      info += `df -h`
      info += "\nPS AUX:\n"
      info += `ps aux | grep 'apache\\|cgi\\|USER' | grep -v grep`
      return info
    rescue
      return 'Error on extracting memory and PS info.'
    end
  end

  def get_svn_info
    begin
      svn_info = `svn info #{Rails.root}`
      svn_status = (`svn status #{Rails.root} 2>&1`).to_s.split("\n").collect { |status| status if ((status[0..0] == 'M') || (status.scan('This client is too old to work with working copy').size > 0)) }.compact.size > 0
      svn_data = svn_info.split("\n")
      rep = svn_data[1].to_s.split(': ')[1].to_s.strip
      rev = svn_data[4].to_s.split(': ')[1].to_s.strip
      status = svn_status ? 'YES' : 'NO'
    rescue => exception
      # For info
      status = exception
      rev = rep = 'SVN ERROR'
      # status = rev = rep = "SVN ERROR"
    end
    return rep, rev, status
  end

  def simple_file_name?(string)
    string.match(/^[a-zA-Z1-9]+.[a-zA-Z1-9]+/)
  end

  def testable_file_send(file, filename, mimetype)
    if params[:test]
      case mimetype
        when 'application/pdf' then
          render text: {filename: filename, file: 'File rendered'}.to_json
        else
          render text: {filename: filename, file: file}.to_json
      end
    else
      send_data(file, type: mimetype, filename: filename)
    end
  end

  def send_crash_email(address, subject, message)
    MorLog.my_debug('  >> Before sending message.', true)
    local_filename = '/tmp/mor_crash_email.txt'
    File.open(local_filename, 'w') { |file| file.write(message) }

    command = ApplicationController::send_email_dry('guicrashes@ocean-tel.uk', address, '', subject, "-o message-file='#{local_filename}' tls='auto'")

    system(command) unless (defined?(NO_EMAIL) && (NO_EMAIL.to_i == 1))

    MorLog.my_debug("  >> Crash email sent to #{address}", true)
    MorLog.my_debug("  >> COMMAND : #{command.inspect}", true)
    MorLog.my_debug("  >> MESSAGE  #{message.inspect}", true)
    system("rm -f #{local_filename}")
  end

  def find_destination
    @destination = Destination.where(id: params[:id]).includes([:destinationgroup]).first
    unless @destination
      flash[:notice] = _('Destination_was_not_found')
      redirect_to(controller: 'directions', action: 'list') && (return false)
    end
  end

  def is_number?(val = nil)
    Application.is_number?(val)
  end

  def is_prefix?(val = nil)
    (!!(val.match /^\+?[0-9#%]+$/) rescue false)
  end

  def is_number_pool_format?(val = nil)
    (!!(val.match /^[0-9%]+$/) rescue false)
  end

  def is_numeric?(val = nil)
    # Check if value is a digit ( allows decimal seperator )
    (!!(Float(val)) rescue false)
  end

  def monitorings_addon_active?
    confline = lambda {Confline.get_value('MA_Active').to_i == 1}
    functionality_active(:ma_active, confline)
  end

  def reseller_active?
    confline = lambda {Confline.get_value('RS_Active').to_i == 1}
    functionality_active(:rs_active, confline)
  end

  def pbx_active?
    confline = lambda {Confline.get_value('PBX_Active').to_i == 1}
    pbx_cofline_status = functionality_active(:PBX_Active, confline)

    if reseller?
      pbx_cofline_status and (not reseller?)
    else
      pbx_cofline_status
    end
  end

  def reseller_pro_active?
    confline = lambda {reseller_active? and (Confline.get_value('RSPRO_Active').to_i == 1)}
    functionality_active(:reseller_pro_active, confline)
  end

  def admin?
    session[:usertype].to_s == 'admin' if session[:usertype].present?
  end

  def manager?
    session[:usertype].to_s == 'manager' if session[:usertype].present?
  end

  def reseller?
    session[:usertype].to_s == 'reseller' if session[:usertype].present?
  end

  def user?
    session[:usertype].to_s == 'user' if session[:usertype].present?
  end

  def test_machine_active?
    (defined?(TEST_MACHINE) and TEST_MACHINE.to_i == 1)
  end

  def ccl_active?
    confline = lambda do
      ccl_active = Confline.get_value('CCL_Active') rescue NIL
      (ccl_active.present? && (ccl_active.to_i == 1))
    end
    functionality_active(:ccl_active, confline)
  end

  def user_tz
    current_user.time_zone
  end

  def user_time_from_params(year, month, day, hour, minute, no_tz = false)
    keys = [:year, :month, :day, :hour, :minute]

    now = Time.now

    default_date_hash = {
        year: now.year,
        month: now.month,
        day: now.day,
        hour: '00',
        minute: '00'
    }

    date_hash = Hash[keys.zip([year, month, day, hour, minute])]

    date_hash.each do |key, value|
      date_hash[key.intern] = default_date_hash[key.intern] unless value.to_s.match(/^\d+$/)
    end

    date_time_str = "#{date_hash[:year]}-#{date_hash[:month]}-#{date_hash[:day]} #{date_hash[:hour]}:#{date_hash[:minute]}"


    time = no_tz ? Time.parse(date_time_str) : Time.zone.parse(date_time_str)

    # time.parse changes month to the neares if it is invalid.
    # Example: 2013-02-30 is changed to 2013-03-01
    # ticket #8344
    if time.month.to_i != date_hash[:month].to_i
      time = time.change(month: date_hash[:month])
      time = time.change(day: time.end_of_month.day)
    end

    time
  end

  def last_day_month(date)
    year = session["year_#{date}".to_sym]
    if last_day_of_month(session["year_#{date}".to_sym], session["month_#{date}".to_sym]).to_i <= session["day_#{date}".to_sym].to_i
      day = '01'
      if session["month_#{date}".to_sym].to_i == 12
        month = '01'
        year = session["year_#{date}".to_sym].to_i + 1
      else
        month = session["month_#{date}".to_sym].to_i+1
      end
    else
      day = session["day_#{date}".to_sym].to_i+1
      month = session["month_#{date}".to_sym].to_i
    end
    return year, month, day
  end

  #  Check whether supplied date's day is the last day of that month.
  #  Maybe we should exten Date, Daytime, Time with this method, but i dont approve modifying built in classes
  #
  #  *Params*
  #  *date* - Date, Daytime, Time instances or anything that has year, month and day methods
  #
  # *Returns*
  # *boolean* - true or false depending whether day is the last day of the month of supplied date

  def self.last_day_of_the_month?(date)
    next_month = Date.new(date.year, date.month) + 42 # warp into the next month
    date.day == (Date.new(next_month.year, next_month.month) - 1).day # back off one day from first of that month
  end

  # Check whether supplied date's day is the last day of that month.
  # Maybe we should exten Date, Daytime, Time with this method, but i dont approve modifying built in classes
  #
  # *Params*
  # *date* - Date, Daytime, Time instances or anything that has day method
  #
  # *Returns*
  # *boolean* - true or false depending whether day is the first day of the month of supplied date

  def self.first_day_of_the_month?(date)
    date.day == 1
  end


  # Return difference in 'months' between two dates.
  # In MOR 'month' only counts when it is a period FROM FIRST SECOND
  # OF CALENDAR MONTH TILL LAST SECOND OF CALENDAR MONTH. for example:
  # period between 01.01 00:00:00 and 01.31 23:59:59 is whole 1 month
  # period between 01.02 00:00:00 and 02.01 23:59:59 is NOT a whole month, althoug intervals exressed as seconds are the same
  # period between 01.01 00:00:00 and 02.01 23:59:59 is whole 1 month
  # period between 01.01 00:00:00 and 02.29 23:59:59 is whole 1 month
  # period between 01.01 00:00:00 and 02.29 23:59:59 is whole 1 month, allthoug it may seem as allmost two months
  # period between 01.02 00:00:00 and 02.29 23:59:59 is NOT a whole month, allthoug it may seem as allmost two months
  # period between 01.02 00:00:00 and 03.29 23:59:59 is only 1 whole month, allthoug it may seem as allmost three months
  # lets hope you'll get it, if not ask boss, he knows whats this about.
  def self.month_difference(period_start, period_end)
    month_diff = period_end.month - period_start.month
    if month_diff == 0
      return ((first_day_of_the_month? period_start and last_day_of_the_month? period_end) ? 1 : 0)
    else
      month_diff = month_diff - 1
      if first_day_of_the_month? period_start
        month_diff += 1
      end
      if last_day_of_the_month? period_end
        month_diff += 1
      end
      return month_diff
    end
  end

  def check_post_method
    unless request.post?
      dont_be_so_smart
      redirect_to root_path and return false
    end
  end

  def store_url
    session[:url] = "#{request.protocol}#{request.host_with_port}" if session[:url].blank?
  end

  def handle_unverified_request
    begin
      super
    rescue ArgumentError
      Rails.cache.clear
      reset_session rescue ArgumentError
    end
    redirect_to controller: 'callc', action: 'login', session_expired: true
  end

  # Only to be used when the time is stored in session
  def limit_search_by_days
    search_from = session_from_datetime

      if user?
        stats_for_last = Confline.get_value("Show_Calls_statistics_to_#{current_user.usertype.capitalize}_for_last", current_user.owner_id).to_i
        unless stats_for_last == 0
          current_time = Time.current.beginning_of_day
          if (current_time - Time.parse(session_from_datetime)) > stats_for_last.days
            new_time = current_time - stats_for_last.days
            search_from = new_time.strftime('%Y-%m-%d %H:%M:%S')
          end
        end
      end

    return search_from
  end

  def time_in_user_tz(hours, minutes, seconds='00')
    time_str = [hours, minutes, seconds].join(':')

    time = Time.parse(time_str).in_time_zone(user_tz)
    time
  end

  def functionality_active(key, confline)
    if session.blank?
      return confline.call
    else
      session[key] ||= confline.call
      return session[key]
    end
  end

  def adjust_m2_date
    if params[:date_from] && params[:time_from]
      time = parse_datetime(params[:date_from], params[:time_from])
      params[:date_from] = Hash[[:year, :month, :day].zip([time.year, time.month, time.day])]
      params[:date_from].update(Hash[[:hour, :minute].zip([time.hour, time.min])])
    end
    if params[:date_till] && params[:time_till]
      time = parse_datetime(params[:date_till], params[:time_till])
      params[:date_till] = Hash[[:year, :month, :day].zip([time.year, time.month, time.day])]
      params[:date_till].update(Hash[[:hour, :minute].zip([time.hour, time.min])])
    end
  end

  def parse_datetime(date, time = '')
    date_frmt = (Confline.get('date_format').try(:value) || '%Y-%m-%d').to_s.split.first
    time_frmt = %w(%H %M %S).slice(0, time.to_s.split(':').size).join(':')
    DateTime.strptime("#{date} #{time}", "#{date_frmt} #{time_frmt}")
  rescue ArgumentError
    flash[:notice] = _('Wrong_date_format')
    Time.zone.now
  end

  # this method is used to prevent losing cyrillic character while encoding to utf
  def fix_encoding_import_csv(file_raw)
    begin
      cleaned = file_raw.dup.force_encoding('UTF-8')
      unless cleaned.valid_encoding?
        cleaned = file_raw.encode('UTF-8', 'Windows-1251')
      end
    file = cleaned
    rescue EncodingError
      file.encode!( 'UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end
    file
  end

  def annoying_messages
    if Confline.get_value('unlicensed') == '1'
      flash[:notice] = flash[:warning] = flash[:status] = 'Your copy of M2 is not licensed, contact <a href="http://www.ocean-tel.uk/class-4-softswitch">Kolmisoft</a>'
    end
  end

  def send_warning_balance_sms(src_user, dst_user)
    sms = SmsSender.new(src_user_id: src_user.id, dst_user_id: dst_user.id)
    unless sms.valid?
      Action.add_action_hash(
          src_user.owner_id,
          {
              action: 'error', target_type: 'user', target_id: dst_user.id,
              data: 'Cant_send_SMS', data2: sms.errors.messages.values.join('; ')
          }
      )
      return false
    end

    sms.apply_template_for_message(template_name: 'send_warning_balance_sms')

    sms.deliver_via_post

    if sms.response_crash
      action = 'error'
      target = 'user'
      data = 'Cant_send_SMS'
      data2 = {error: sms.response.message}
    else
      if sms.response['status'] < '400'
        action = 'warning_balance_sms_send'
        target = sms.number_to
        data = dst_user.usertype
        data2 = ''
      else
        action = 'error'
        target = 'user'
        data = 'Cant_send_SMS'
        data2 = sms.response['status']
      end
    end
    Action.add_action_hash(src_user.owner_id, {action: action, target_type: target, target_id: dst_user.id, data: data, data2: data2})
  end

  def check_m4_functionality
    if Confline.get_value('M4_Functionality').to_i == 1
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end
end

# Enumerable module
module Enumerable
  def dups
    inject({}) { |item, value| item[value] = item[value].to_i + 1; item }.reject { |key, value| value == 1 }.keys
  end
end
