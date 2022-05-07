# Mainly Cron and Login actions.
class CallcController < ApplicationController
  # require 'rami'
  require 'digest/sha1'
  # require 'enumerator'

  layout :determine_layout

  before_filter :check_localization, except: [
    :monthly_actions,
    :show_quick_stats, :quick_stats_active_calls, :quick_stats_user_ac, :quick_stats_technical_info, :redis_footer_info
  ]
  before_filter :authorize, except: [
    :login, :try_to_login, :monthly_actions, :forgot_password, :admin_ip_access,
    :show_quick_stats, :quick_stats_active_calls, :quick_stats_user_ac, :quick_stats_technical_info
  ]
  before_filter :quick_stats_user_present?, only: [
    :show_quick_stats, :quick_stats_active_calls, :quick_stats_user_ac, :quick_stats_technical_info
  ]
  before_action :check_post_method, only: [:disable_replication_check]

  @@monthly_action_cooldown = 2.hours
  @@daily_action_cooldown = 2.hours
  @@hourly_action_cooldown = 20.minutes

  def index
    if session[:usertype]
      redirect_to(action: 'login') && (return false)
    else
      redirect_to(action: 'logout') && (return false)
    end
  end

  def login
    @show_login = params[:shl].to_s.to_i
    @u = params[:u].to_s
    params_id = params[:id] if params[:id].is_a?(String)

    report_ip_on_fail

    flash[:notice] = _('session_expired') if params[:session_expired]

    @owner = params_id ? User.where(uniquehash: params_id).first : User.where(id: 0).first
    @owner_id, @defaulthash = @owner ? [@owner.id, @owner.get_hash] : [0, '']
    @allow_register = allow_register?(@owner)

    session[:login_id] = @owner_id

    flags_to_session(@owner)

    if Confline.get_value('Show_logo_on_register_page', @owner_id).to_s == ''
      Confline.set_value('Show_logo_on_register_page', 1, @owner_id)
    end

    @page_title = _('Login')
    @page_icon = 'key.png'

    (redirect_to(:root) && (return false)) if session[:login] == true

    set_time

    if Confline.get_value('Show_logo_on_register_page', @owner_id).to_i == 1
      session[:logo_picture], session[:version], session[:copyright_title] = Confline.get_logo_details(@owner_id)
    else
      session[:logo_picture], session[:version], session[:copyright_title] = [''] * 3
    end

    if request.env['HTTP_X_MOBILE_GATEWAY']
      respond_to do |format|
        format.wml { render 'login.wml.builder' }
      end
    end
  end

  def try_to_login
    session[:layout_t] = params[:layout_t].to_s if params[:layout_t]
    unless params['login']
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @username = params['login']['username'].to_s
    @psw = params['login']['psw'].to_s

    @type = 'user'
    @login_ok = false

    @user = User.where(username: @username, password: Digest::SHA1.hexdigest(@psw)).first

    if m4_functionality? && two_fa_enabled? && @user && @user.two_fa_enabled == 1
      render(:login) && (return false) unless two_fa_auth
    end

    request_remote_ip = request.remote_ip
    if Confline.get_value('admin_login_with_approved_ip_only ', 0).to_i == 1 && @user.try(:usertype).to_s == 'admin'
      iplocation = Iplocation.admin_ip_find_or_create(request_remote_ip)

      if Iplocation.where(approved: 1).size <= 1
        iplocation.approve
      elsif iplocation.approved.to_i == 0
        if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
          iplocation.admin_ip_send_email_authorization
          flash[:notice] = "UNAUTHORIZED IP ADDRESS. System Admin received email with request to authorize your IP: #{iplocation.ip}"
        else
          flash[:notice] = "UNAUTHORIZED IP ADDRESS. Your IP: #{iplocation.ip} is not authorized to access this account"
        end
        Action.unauthorized_login('admin', iplocation.ip)
        redirect_to(action: :login, id: @user.uniquehash, u: @username) && (return false)
      end
    end

    if @user && @user.owner
      @login_ok = true
      renew_session(@user)
      store_url
    end

    session[:login] = @login_ok

    if @login_ok == true
      session[:login_ip] = request_remote_ip
      add_action(session[:user_id], 'login', request.env['REMOTE_ADDR'].to_s)
      # Session is synced with the last password change
      session[:session_token] = @user.password_changed_at if Confline.get_value('logout_on_password_change').to_i == 1

      @user.mark_logged_in
      bad_psw = ((params['login']['psw'].to_s == 'admin') && (@user.id == 0)) ? _('ATTENTION!_Please_change_admin_password_from_default_one_Press') + " <a href='#{Web_Dir}/users/edit/0'> #{_('Here')} </a> " + _('to_do_this') : ''
      flash[:notice] = bad_psw if bad_psw.present?
      flash[:first_login] = true
      redirect_to(:root) && (return false)
    else

      add_action_second(0, 'bad_login', @username.to_s, request.env['REMOTE_ADDR'].to_s)

      us = User.where(id: session[:login_id]).first
      u_hash = us ? us.uniquehash : ''
      flash[:notice] = _('bad_login')
      show_login = (Action.disable_login_check(request.env['REMOTE_ADDR'].to_s).to_i == 0) ? 1 : 0
      redirect_to(action: 'login', id: u_hash, shl: show_login, u: @username, bad_login: 1) && (return false)
    end
  end

  def logout
    add_action(session[:user_id], 'logout', '')

    user = User.where(id: session[:user_id]).first
    if user
      user.mark_logged_out
      owner = user.owner
      user_id = user.id
    end
    owner ||= User.where(id: 0).first
    owner_id = owner.try(:id) || 0

    # for reseller and his users, use reseller's logout link
    owner_id = user_id if user and reseller?

    session[:login] = false
    session.destroy

    if Confline.get_value('Logout_link', owner_id).blank?
      id = if user.try(:is_reseller?)
             user.get_hash
           elsif owner.try(:get_hash)
             owner.get_hash
           end

      redirect_to action: 'login', id: id
    elsif user.try(:is_reseller?)
      redirect_to get_logout_link(user_id), id: user.get_hash
    else
      redirect_to get_logout_link(owner_id)
    end
  end

  def forgot_password
    email = params[:email]
    if email and !email.blank?
      @r, @st = User.recover_password(email)
      flash[:notice_forgot] = @r.dup and @r.clear if @r.include?(_('Email_not_sent_because_bad_system_configurations'))
    end
    render layout: false
  end

  def main
    @page_title = _('Start_page')
    @show_currency_selector = 1
    @tariffs = get_tariffs_per_user_op if user?

    redirect_to(action: :login) && (return false) unless session[:user_id]
    dont_be_so_smart if params[:dont_be_so_smart]

    session[:layout_t] = 'full'

    @user = User.includes(:tax).where(id: session[:user_id]).first
    redirect_to(action: :logout) && (return false) unless @user

    recheck_integrity_check
    @username = nice_user(@user)

    if user?
      render :user_dashboard
    else
      check_server_space
      render :admin_dashboard
    end
  end

  def show_quick_stats
    @ex = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    @user = User.includes(:tax).where(id: session[:user_id]).try(:first)
    render(nothing: true) && (return false) unless @user
    time_now = Time.now.in_time_zone(@user.try(:time_zone))
    year = time_now.year.to_s
    month = time_now.month.to_s
    day = time_now.day.to_s

    month_t = admin? ? '' : (year + '-' + good_date(month))
    last_day = last_day_of_month(year, good_date(month))
    day_t = year + '-' + good_date(month) + '-' + good_date(day)
    options = session[:callc_main_stats_options] || {}

    @quick_stats = @user.quick_stats(month_t, last_day, day_t, current_user_id)
    session[:callc_main_stats_options] = options

    render layout: false
  end

  def quick_stats_active_calls
    @active_calls = "#{Activecall.count_calls(hide_active_calls_longer_than, false, current_user)} / #{Activecall.count_calls(hide_active_calls_longer_than, true, current_user)}"
    render layout: false
  end

  def quick_stats_user_ac
    @active_calls = "#{current_user.active_calls_count(hide_active_calls_longer_than)} / " \
      "#{current_user.active_calls_count(hide_active_calls_longer_than, true)}"
    render :quick_stats_active_calls, layout: false
  end

  def quick_stats_technical_info
    @servers = Server.all_quick_stats
    @es_sync = EsQuickStatsTechnicalInfo.get_data
    @es_sync[:tooltip] = "<b>#{_('MySQL_Calls')}:</b> #{@es_sync[:mysql]}<br/><b>#{_('Elasticsearch_Calls')}:</b> #{@es_sync[:es]}"
    @db_replication = replication_check_disabled? ? 0 : db_replication_status

    render layout: false
  end

  def user_settings
    @user = User.where(id: session[:user_id]).first
  end

  def global_settings
    @page_title = _('global_settings')
    cond = 'exten = ? AND context = ? AND priority IN (2, 3) AND appdata like ?'
    ext = Extline.where(cond, '_X.', 'mor', 'TIMEOUT(response)%').first
    @timeout_response = (ext ? ext.appdata.gsub('TIMEOUT(response)=', '').to_i : 20)
    ext = Extline.where(cond, '_X.', 'mor', 'TIMEOUT(digit)%').first
    @timeout_digit = (ext ? ext.appdata.gsub('TIMEOUT(digit)=', '').to_i : 10)
    @translations = Translation.order('position ASC').all
  end

  def global_settings_save
    hide_active_calls_longer_than = params[:hide_active_calls_longer_than].to_i
    hide_active_calls_longer_than = 2 if hide_active_calls_longer_than <= 0
    Confline.set_value('Hide_active_calls_longer_than', hide_active_calls_longer_than, 0)
    Confline.set_value('Load_CSV_From_Remote_Mysql', params[:load_csv_from_remote_mysql].to_i, 0)
    redirect_to(action: 'global_settings') && (return false)
  end

  def reconfigure_globals
    @page_title = _('global_settings')
    @type = params[:type]

    if @type == 'devices'
      @devices = Device.where('user_id > 0').all
      @devices.each do |dev|
        reconfigure = configure_extensions(dev.id, {current_user: current_user})
        return false if !reconfigure
      end
    end

    reconfigure_outgoing_extensions if @type == 'outgoing_extensions'
  end

  def global_change_timeout
    if Extline.update_timeout(params[:timeout_response].to_i, params[:timeout_digit].to_i)
      flash[:status] = _('Updated')
    else
      flash[:notice] = _('Invalid values')
    end
    redirect_to(action: 'global_settings') && (return false)
  end

  def global_set_tz
    if Confline.get_value('System_time_zone_ofset_changed').to_i == 0
      time_now = Time.now
      sql = "UPDATE users SET time_zone = '#{ActiveSupport::TimeZone[time_now.utc_offset / 3600].name}';"
      ActiveRecord::Base.connection.execute(sql)
      Confline.set_value('System_time_zone_ofset_changed', 1)
      flash[:status] = _('Time_zone_for_users_set_to') + " #{ActiveSupport::TimeZone[time_now.utc_offset / 3600].name} "
    else
      flash[:notice] = _('Global_Time_zone_set_replay_is_dont_allow')
    end
    redirect_to(action: 'global_settings') && (return false)
  end

  def set_tz_to_users
    users = User.all
    users.each do |user|
      begin
        Time.zone = user.time_zone
        user.time_zone = ActiveSupport::TimeZone[Time.zone.now.utc_offset.hour.to_d + params[:add_time].to_d].name
        user.save
      rescue => exception
      end
    end

    flash[:status] = _('Time_zone_for_users_add_value') + " + #{params[:add_time].to_d} "
    redirect_to(action: 'global_settings') && (return false)
  end

  # cronjob runs every hour
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/hourly_actions

  def hourly_actions
    #    backups_hourly_cronjob
    if active_heartbeat_server
      periodic_action('hourly', @@hourly_action_cooldown) do
        # check/make auto backup
        #    bt = Thread.new {
        Backup.backups_hourly_cronjob(session[:user_id])
        # }
        # =========== send b warning email for users ==================================
        MorLog.my_debug('Starting checking for balance warning', 1)
        User.check_users_balance
        send_balance_warning
        MorLog.my_debug('Ended checking for balance warning', 1)

        # bt.join
        # ======================== Cron actions =====================================
        CronAction.do_jobs
        Cron.do_jobs
        # ======================== System time ofset =====================================
        # sql = 'select HOUR(timediff(now(),convert_tz(now(),@@session.time_zone,\'+00:00\'))) as u;'
        # z = ActiveRecord::Base.connection.select_all(sql)[0]['u']
        # MorLog.my_debug("GET global time => #{z.to_yaml}", 1)
        # t = z.to_s.to_i
        # old_tz= Confline.get_value('System_time_zone_ofset')
        # if t.to_i != old_tz.to_i and Confline.get_value('System_time_zone_daylight_savings').to_i == 1
        # ========================== System time ofset update users ================================
        # diff = t.to_i - old_tz.to_i
        # sql = "UPDATE users SET time_zone = ((time_zone + #{diff.to_d}) % 24);;"
        # ActiveRecord::Base.connection.execute(sql)
        # MorLog.my_debug("System time ofset update users", 1)
        # end
        # Confline.set_value('System_time_zone_ofset', t.to_i, 0)
        # MorLog.my_debug("confline => #{Confline.get_value('System_time_zone_ofset')}", 1)
        # ======================== Devices  =====================================
        check_devices_for_accountcode
        # ======================== Servers =====================================
        inform_admin_for_low_space_servers

        update_timezone_offsets
        # ==================== Update Blocked IPs - IpLocation Countries ======
        BlockedIP.iplocation_countries_update
        # M4 Fraud protection reset
        User.fraud_protection_reset if m4_functionality?
      end
    else
      MorLog.my_debug('Backup not made because this server has different IP than Heartbeat IP from Conflines')
    end
  end

  # cronjob runs every midnight
  # 0 0 * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/daily_actions
  def daily_actions
    if active_heartbeat_server # to be sure to run this only once per day
      periodic_action('daily', @@daily_action_cooldown) do

        # =========== get Currency rates from yahoo.com =================
        update_currencies

        #============ delete old files ==================================
        delete_files_after_csv_import
        system('rm -f /tmp/get_tariff_*') #delete tariff export zip files

        TariffJob.delete_older
        # =========== block users if necessary ==========================
        block_users

        @time = Time.now - 1.day
        # ===================== Resync ElasticSearch ==========================
        #elasticsearch_resync_if_dg_changed 2021-10-15 disabled due to messed up es resync on huge DB
      end
    end
  end

  # cronjob runs every 1st day of month
  # 0 * * * * wget -o /dev/null -O /dev/null http://localhost/billing/callc/monthly_actions

  def monthly_actions
    # if active_heartbeat_server
    periodic_action('monthly', @@monthly_action_cooldown) do

      year = Time.now.year.to_i
      month = Time.now.month.to_i - 1

      if month == 0
        year -= 1
        month = 12
      end

      my_debug("Saving balances for users for: #{year} #{month}")
      save_user_balances(year, month)
    end
    # end
  end

  def periodic_action(type, cooldown)
    db_time = Time.now.to_s(:db)
    MorLog.my_debug "#{db_time} - #{type} actions starting sleep"
    sleep(rand * 10)
    MorLog.my_debug "#{db_time} - #{type} actions starting sleep end"
    begin
      time_set = Time.parse(Confline.get_value("#{type}_actions_cooldown_time"))
    rescue ArgumentError
      time_set = Time.now - 1.year
    end
    current_time = Time.now
    unless time_set && time_set + cooldown > current_time
      Confline.set_value("#{type}_actions_cooldown_time", current_time.to_s(:db))
      MorLog.my_debug "#{type} actions starting"
      yield
      MorLog.my_debug "#{type} actions finished"
    else
      MorLog.my_debug("#{cooldown} has not passed since last run of #{type.upcase}_ACTIONS")
      render text: 'To fast.'
    end
  end

  def global_change_confline
    if params[:heartbeat_ip]
      Confline.set_value('Heartbeat_IP', params[:heartbeat_ip].to_s.strip)
      flash[:status] = 'Heartbeat IP set'
    end
    redirect_to(action: :global_settings) && (return false)
  end

  def additional_modules
    @page_title = _('Additional_modules')
  end

  def additional_modules_save
    ccl, ccl_old, _first_srv, def_asterisk, reseller_server,
        @resellers_devices = Confline.additional_modules_save_assign(params)

    if ccl.to_s != ccl_old.to_s && params[:indirect].to_i == 1
      @sd = ServerDevice.all

      if ccl.to_i == 0
        Confline.additional_modules_save_no_ccl(ccl, @sd, @resellers_devices, def_asterisk, reseller_server)

        flash[:status] = _('Settings_saved')

        # removing session so that users couldn't use addons.
        Rails.cache.clear
        reset_session
        redirect_to(action: :additional_modules) && (return true)

      elsif ccl.to_i == 1

        ip = params[:ip_address]
        host = params[:host]

        if ip.blank? || !check_ip_validity(ip) || !Server.where(server_ip: ip).count.zero?
          flash[:notice] = _('Incorrect_Server_IP')
          redirect_to(action: :additional_modules) && (return false)
        elsif host.blank? || !check_hostname_validity(host) || !Server.where(hostname: host).count.zero?
          flash[:notice] = _('Incorrect_Host')
          redirect_to(action: :additional_modules) && (return false)
        else

          old_id = Server.select('MAX(id) AS last_old_id').first.last_old_id rescue 0
          new_id = old_id.to_i + 1

          created_server = Server.new(server_ip: ip, hostname: host, server_type: 'sip_proxy', comment: 'SIP Proxy', active: 0)

          if created_server.save &&
              Device.where(name: 'mor_server_' + new_id.to_s).update_all(nat: 'yes', allow: 'alaw;g729;ulaw;g723;g726;gsm;ilbc;lpc10;speex;adpcm;slin;g722')

            @sd = Confline.additional_modules_save_with_ccl(@sd, created_server, ccl)
          else
            created_server_errors_values = created_server.errors.values.first
            flash[:notice] = _(created_server_errors_values.first, "mor_server_#{created_server.id}") if created_server_errors_values
            redirect_to(action: :additional_modules) && (return false)
          end

        end
      else
        flash[:notice] = _('additional_modules_fail')
        redirect_to(action: :additional_modules) && (return false)
      end

    end

    # removing session so that users couldn't use addons.
    Rails.cache.clear
    reset_session

    flash[:status] = _('Settings_Saved')
    redirect_to action: :additional_modules
  end

  # IP validation
  def check_ip_validity(ip = nil)
    regexp = /^\b(?![0.]*$)(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)(?:\.(?:25[0-5]|(?:2[0-4]|1\d|[1-9])?\d)){3}\b$/
    (regexp.match(ip) ? (return true) : (return false))
  end

  # Hostname validation
  def check_hostname_validity(hostname = nil)
    regexp = /(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)|(^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$)$/
    (regexp.match(hostname) ? (return true) : (return false))
  end

  def toggle_search(show_object = 'show_search')
    if params[:refine_results]
      controller = params[:controll]
      action = params[:act]
      session[controller] ||= {}
      session[controller][action] ||= {}
      show = session[controller][action][show_object.to_sym]
      session[controller][action][show_object.to_sym] = show

      unless session[controller][action].empty?
        session[controller][action].each do |key, value|
          session[controller][action][key] = (key.to_s == show_object.to_s) ? ((value.to_i == 0) ? 1 : 0) : 0
        end
      end
    end

    render nothing: true
  end

  def toggle_manage
    toggle_search('show_manage')
  end

  def toggle_create
    toggle_search('show_create')
  end

  def change_currency
    currency = Currency.where(name: params[:currency], active: 1).first.try(:name)
    session[:show_currency] ||= currency
    redirect_to controller: params[:url][:controller], action: params[:url][:action], id: params[:url][:id], page: params[:url][:page], st: params[:url][:st]
  end

  def inform_admin_for_low_space_servers
    MorLog.my_debug('Checking Servers free space')
    servers_with_space_exceeded = Server.where("hdd_free_space < #{server_free_space_limit}").pluck(:id)

    if servers_with_space_exceeded.present?
      MorLog.my_debug('Found Servers with exceeded space limit')

      servers_with_space_exceeded.each do |server_with_no_space|
        server = Server.where(id: server_with_no_space).first
        MorLog.my_debug('Preparing email to send for admin')
        admin_id = 0
        admin = User.where(id: admin_id).first
        email_template = Email.where(name: 'server_low_free_space', owner_id: admin_id).first
        email_from = Confline.get_value('Email_from', admin_id).to_s
        variables = Email.email_variables(admin, nil, hdd_free_space: server.hdd_free_space, server_id: server.id, server_ip: server.server_ip)

        status, _email_error = Email.send_balance_warning_email(email_template, email_from, admin, variables)
        MorLog.my_debug(status)
      end
    else
      MorLog.my_debug('Servers have enough free space')
    end
  end

  def admin_ip_access
    ip = Iplocation.where(uniquehash: params[:id].to_s, approved: 0).first

    if Confline.get_value_default_on('admin_login_with_approved_ip_only ', 0).to_i == 1 && ip.present?
      ip_addr = ip.ip
      if params[:block_ip].present?
        ip.block_ip
        message = "IP: #{ip_addr} was successfully blocked."
        Action.login_blocked('admin', ip_addr)
      else
        ip.approve
        message = "IP: #{ip_addr} was successfully authorized."
        Action.login_authorized('admin', ip_addr)
      end
      flash[:status] = message
    else
      dont_be_so_smart
    end
    redirect_to(action: :login) && (return false)
  end

  def disable_replication_check
    access_denied && (return false) unless admin?

    Confline.set_value(
      'disable_replication_check',
      params[:disable_replication_check].to_i.to_s
    )
  end

  def m4_functionality
    access_denied && (return false) unless admin?
    Confline.set_value('M4_Functionality', params[:m4_functionality].to_i.to_s)
    flash[:status] = _('Settings_Saved')
    redirect_to(action: :global_settings) && (return false)
  end

  def redis_footer_info
    response = {cps: '-', cc: '-'}

    begin
      redis_connection = Redis.new(Confline.redis_connection_hash)
      response = {
          cps: (redis_connection.mget('CORE_CPS_GLOBAL').first || '-'),
          cc: (redis_connection.mget('CORE_CC_GLOBAL').first || '-')
      }
      redis_connection.try(:disconnect!)
    rescue => error
      redis_connection.try(:disconnect!)
      response = {cps: '-', cc: '-', error: error.to_s}
    end

    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  private

  def check_server_space
    return unless admin?
    servers = Server.where("hdd_free_space < #{server_free_space_limit} AND active = 1").count
    return if servers.zero?
    flash[:warning] = "#{_('Servers_with_low_free_space')}: #{servers}. "\
      "<a href='#{Web_Dir}/servers/list'>#{_('Check_it_here')}</a>"
  end

  def report_ip_on_fail
    ip_report_on = Confline.get_value_default_on('bad_login_ip_report_warning ', 0).to_i == 1
    @ip_info = Iplocation.get_location(request.remote_ip) if params[:bad_login] && ip_report_on
  end

  def check_devices_for_accountcode
    ActiveRecord::Base.connection.execute('UPDATE devices set accountcode = id WHERE accountcode = 0;')
  end

  # if Heartbeat IP is set, check if current server IP is same as Heartbeat IP
  def active_heartbeat_server
    heartbeat_ip = Confline.get_value('Heartbeat_IP').to_s
    # remote_ip = `/sbin/ifconfig | grep '#{heartbeat_ip} '`
    remote_ip = `ip -o -f inet addr show | grep -E "inet[[:space:]]+#{heartbeat_ip}[[:space:]/]"`

    render(text: 'Heartbeat IP incorrect') && (return false) if heartbeat_ip.present? && remote_ip.to_s.empty?

    true
  end

  # saves users balances at the end of the month to use them in future in invoices to show users how much they owe to system owner
  def save_user_balances(year, month)
    @year = year.to_i
    @month = month.to_i

    date = "#{@year.to_s}-#{@month.to_s}"

    if months_between(Time.mktime(@year, @month, '01').to_date, Time.now.to_date) < 0
      render(text: 'Date is in future') && (return false)
    end

    users = User.all

    # check all users for actions, if action not present - create new one and save users balance
    users.each do |user|
      old_action = Action.where(data: date, user_id: user.id).first
      if !old_action
        MorLog.my_debug("Creating new action user_balance_at_month_end for user with id: #{user.id}, balance: #{user.raw_balance}")
        Action.add_action_hash(user, action: 'user_balance_at_month_end', data: date, data2: user.raw_balance.to_s, data3: Currency.get_default.name)
      else
        MorLog.my_debug("Action user_balance_at_month_end for user with id: #{user.id} present already, balance: #{old_action.data2}")
      end
    end
  end

  def delete_files_after_csv_import
    MorLog.my_debug('delete_files_after_csv_import', 1)
    select = []
    select << 'SELECT table_name'
    select << 'FROM   INFORMATION_SCHEMA.TABLES'
    select << "WHERE  table_schema = 'mor' AND"
    select << "       table_name like 'import%' AND"
    select << '       create_time < ADDDATE(NOW(), INTERVAL -1 DAY);'
    tables = ActiveRecord::Base.connection.select_all(select.join(' '))
    if tables
      tables.each do |table|
        MorLog.my_debug("Found table : #{table['table_name']}", 1)
        Tariff.clean_after_import(table['table_name'])
      end
    end
  end

  def update_currencies
    begin
      Currency.transaction do
        my_debug('Trying to update currencies')
        notice = Currency.update_currency_rates
        notice ? my_debug('Currencies updated') : my_debug('Currencies NOT updated.')
      end
    rescue => exception
      my_debug(exception)
      my_debug('Currencies NOT updated')
      return false
    end
  end

  def backups_hourly_cronjob
    redirect_to controller: 'backups', action: 'backups_hourly_cronjob'
  end

  def block_users
    date = Time.now.strftime('%Y-%m-%d')
    # my_debug date
    users = User.where(block_at: date).all
    # my_debug users.size if users
    users.each do |user|
      user.blocked = 1
      user.save
    end
    my_debug('Users for blocking checked')
  end

  def send_balance_warning
    enable_debug = 1

    administrator = User.where(id: 0).first
    users = User.includes(:address).where('warning_email_active = 1 AND ' \
                                            '((((warning_email_sent = 0) OR (warning_email_sent_admin = 0) OR (warning_email_sent_manager = 0)) ' \
                                            'AND warning_email_hour = -1) ' \
                                          'OR ' \
                                            '(warning_email_hour != -1) ' \
                                          ') AND ( ' \
                                            '(warning_balance_increases = 0 AND (' \
                                              '(balance < warning_email_balance) OR ' \
                                              '(balance < warning_email_balance_admin) OR ' \
                                              '(balance < warning_email_balance_manager))) ' \
                                            ' OR (warning_balance_increases = 1 AND (' \
                                              '(balance > warning_email_balance) OR ' \
                                              '(balance > warning_email_balance_admin) OR ' \
                                              '(balance > warning_email_balance_manager))) ' \
                                          ')').all
    if users.size.to_i > 0
      users.each do |user|

        email_to_address = user.get_email_to_address.to_s
        num = ''
        num_admin = ''
        num_manager = ''
        manager = User.where(id: user.responsible_accountant_id).first

        email_hour = user.warning_email_hour
        user_current_time = Time.now.in_time_zone(user.time_zone).hour
        admin_current_time = Time.now.in_time_zone(administrator.time_zone).hour
        manager_current_time = manager ? Time.now.in_time_zone(manager.time_zone).hour : 0

        if enable_debug == 1 && (email_hour == user_current_time ||
          email_hour == admin_current_time || email_hour == manager_current_time || email_hour == -1)
          MorLog.my_debug("Need to send warning_balance email to: #{user.id} #{user.username} #{email_to_address}")
        end

        email = Email.where(name: 'warning_balance_email', owner_id: user.owner_id).first

        if user.warning_email_hour.to_i == -1 && user.warning_balance_increases.to_i == 1
          local_user_email = Email.where(name: 'warning_balance_email_local2', owner_id: 0).first
        else
          local_user_email = Email.where(name: 'warning_balance_email_local', owner_id: 0).first
        end

        unless email
          owner = user.owner

          if owner.usertype == 'reseller'
            owner.check_reseller_emails
            email = Email.where(name: 'warning_balance_email', owner_id: user.owner_id).first
          end
        end

        variables = email_variables(user)
        admin_email = administrator.email.to_s

        begin
          email_from = Confline.get_value('Email_from', user.owner_id).to_s
          email_sent_string = _('Email_sent')
          old_email_sent, old_email_sent_admin, old_email_sent_manager  = user.warning_email_sent,
                                                                          user.warning_email_sent_admin,
                                                                          user.warning_email_sent_manager

          balance_increases = user.warning_balance_increases.to_i

          send_warning_email =  (((user.balance < user.warning_email_balance && balance_increases == 0) or
                                (user.balance > user.warning_email_balance && balance_increases == 1)) and
                                ((user.warning_email_sent.to_i != 1 and email_hour == -1) or
                                  (email_hour == user_current_time)))
          if send_warning_email
            variables[:user_email] = email_to_address
            num, email_error = Email.send_balance_warning_email(email, email_from, user, variables)
            send_warning_balance_sms(user, user) if balance_increases == 0 && user.send_warning_balance_sms.to_i == 1
          end

          send_warning_email =  (((user.balance < user.warning_email_balance_admin && balance_increases == 0) or
                                (user.balance > user.warning_email_balance_admin && balance_increases == 1)) and
                                (((user.warning_email_sent_admin.to_i != 1) and (email_hour == -1)) or
                                  (email_hour == admin_current_time)))

          if send_warning_email
            variables[:user_email] = admin_email
            num_admin, email_error = Email.send_balance_warning_email(local_user_email, email_from, administrator, variables)
            send_warning_balance_sms(user, administrator) if balance_increases == 0 && user.send_warning_balance_sms.to_i == 1
          end

          resp_manag_email = manager.try(:main_email).to_s
          send_warning_email =  (((user.balance < user.warning_email_balance_manager && balance_increases == 0) or
                                (user.balance > user.warning_email_balance_manager && balance_increases == 1)) and
                                ((user.warning_email_sent_manager.to_i != 1 and email_hour == -1) or
                                  (email_hour == manager_current_time)))

          if manager.present? and send_warning_email
            variables[:user_email] = resp_manag_email
            num_manager, email_error = Email.send_balance_warning_email(local_user_email, email_from, manager, variables)
            send_warning_balance_sms(user, manager) if balance_increases == 0 && user.send_warning_balance_sms.to_i == 1
          end

          if (num.to_s == email_sent_string)
            Action.add_action_hash(user.owner_id, {action: 'warning_balance_send', target_type: email_to_address, target_id: user.id, data: user.id, data2: email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to user: #{email_to_address}")
            end
            user.warning_email_sent = 1
          end

          if (num_admin.to_s == email_sent_string)
            Action.add_action_hash(user.owner_id, {action: 'warning_balance_send', target_type: admin_email, target_id: 0, data: user.id, data2: email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to admin: #{admin_email}")
            end
            user.warning_email_sent_admin = 1
          end

          if (num_manager.to_s == email_sent_string)
            Action.add_action_hash(user.owner_id, {action: 'warning_balance_send', target_type: resp_manag_email, target_id: manager.id, data: user.id, data2: email.id})
            if enable_debug == 1
              MorLog.my_debug("warning_balance_sent: #{user.id} #{user.username}, to manager: #{resp_manag_email}")
            end
            user.warning_email_sent_manager = 1
          end

          save_status = user.save

          if enable_debug == 1
            email_not_sent_string = _('email_not_sent')
            MorLog.my_debug(
              save_status ? 'User saved' : "WARNING! User was not saved. Errors: #{user.errors.messages}"
            )
            if num.to_s == email_not_sent_string
              MorLog.my_debug("Email could not be sent for USER user_id: #{user.id} email: #{email_to_address}")
            end
            if num_admin.to_s == email_not_sent_string
              MorLog.my_debug("Email could not be sent for ADMIN user_id: #{user.id} email: #{admin_email}")
            end
            if num_manager.to_s == email_not_sent_string
              MorLog.my_debug("Email could not be sent for MANAGER user_id: #{user.id} email: #{resp_manag_email}")
            end

            if email_hour == -1
              if old_email_sent == user.warning_email_sent and old_email_sent == 1
                MorLog.my_debug("Email was already sent to USER user_id: #{user.id} email: #{email_to_address}")
              end
              if old_email_sent_admin == user.warning_email_sent_admin and old_email_sent_admin == 1
                MorLog.my_debug("Email was already sent to ADMIN user_id: #{user.id} email: #{admin_email}")
              end
              if old_email_sent_manager == user.warning_email_sent_manager and old_email_sent_manager == 1
                MorLog.my_debug("Email was already sent to MANAGER user_id: #{user.id} email: #{resp_manag_email}")
              end
            end
          end
        rescue => exception
          if enable_debug == 1
            MorLog.my_debug("warning_balance email not sent to: #{user.id} #{user.username} #{email_to_address}, " +
              "because: #{exception.message.to_s}")
          end
          Action.new(user_id: user.owner_id, target_id: user.id, target_type: 'user', date: Time.now.to_s(:db),
                     action: 'error', data: 'Cant_send_email', data2: exception.message.to_s
                    ).save
        end
      end
    else
      if enable_debug == 1
        MorLog.my_debug('No users to send warning email balance')
      end
    end
    MorLog.my_debug('Sent balance warning action finished')
  end

  def find_registration_owner
    unless params[:id] && (@owner = User.where(uniquehash: params[:id]).first)
      dont_be_so_smart
      redirect_to(action: 'login') && (return false)
    end

    if Confline.get_value('Registration_enabled', @owner.id).to_i == 0
      dont_be_so_smart
      redirect_to(action: 'login') && (return false)
    end
  end

  def check_users_count
    owner = User.where(uniquehash: params[:id]).first
    own_providers = owner.own_providers
    limit_it = ((own_providers == 1 and not reseller_pro_active?) or (own_providers == 0 and not reseller_active?))
    if owner and (owner.usertype == 'reseller') and limit_it and (User.where(owner_id: owner.id).count >= 2)
      flash[:notice] = _('Registration_is_unavailable')
      redirect_to(action: "login/#{params[:id]}") && (return false)
    end
  end

  def update_timezone_offsets
    timezones = ActiveSupport::TimeZone.all
    timezones.each do |timezone|
      find_timezone_by_name = Timezone.where("zone = \"#{timezone.name}\"").first
      tz_to_db = find_timezone_by_name.blank? ? Timezone.new : find_timezone_by_name
      tz_to_db.zone = timezone.name
      tz_to_db.offset = Time.now.in_time_zone("#{timezone.name}").utc_offset
      tz_to_db.save
    end
  end

  def allow_register?(owner)
    if owner
      less_than_two_users_owned = User.where(owner_id: owner.id).count < 2
      is_reseller = owner.own_providers == 0
      is_reseller_pro = owner.own_providers == 1
      return less_than_two_users_owned ||  (is_reseller && reseller_active?) || (is_reseller_pro && reseller_pro_active?)
    else
      return false
    end
  end

  def set_time
    time_now = Time.now

    session[:year_from] = session[:year_till] = time_now.year
    session[:month_from] = session[:month_till] = time_now.month
    session[:day_from] = session[:day_till] = time_now.day

    session[:hour_from] = 0
    session[:minute_from] = 0

    session[:hour_till] = 23
    session[:minute_till] = 59
  end

  def get_logout_link(user_id)
    logout_link = Confline.get_value('Logout_link', user_id).to_s
    link = (logout_link.include?('http') ? '' : 'http://') + logout_link
    link
  end

  def quick_stats_user_present?
    (render text: '') && (return false) if current_user.blank?
  end

  def elasticsearch_resync_if_dg_changed
    return unless Confline.get_value('dg_group_was_changed_today').to_i == 1
    Elasticsearch.resync
  end

  def get_tariffs_per_user_op
    sql = "SELECT DISTINCT tariffs.* FROM tariffs
          JOIN devices ON devices.op_tariff_id = tariffs.id
          JOIN users ON users.id = devices.user_id
          WHERE users.id = #{current_user_id}"
    ActiveRecord::Base.connection.select_all(sql)
  end

  def two_fa_auth
    code = TwoFactorAuth.where(user_id: @user.id).first
    code = code.destroy_if_expired if code.present? &&  params[:login].exclude?(:code_2fa)
    @two_fa_auth = true
    @two_fa_email = @user.main_email.to_s

    unless code.present?
      TwoFactorAuth.create(@user.id)
      return false
    end

    return false unless params[:login].key?(:code_2fa)
    code.login_ip = request.env['REMOTE_ADDR'].to_s

    unless code.verify_code(params[:login][:code_2fa].to_s.strip)
      flash_errors_for(_('2FA_authentication_failed'), code)
      @two_fa_auth = false if code.code_expired?
      return false
    end
    true
  end
end
