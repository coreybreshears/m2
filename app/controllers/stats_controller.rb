# -*- encoding : utf-8 -*-
# M2 Statistics
class StatsController < ApplicationController
  include PdfGen
  include SqlExport
  require 'uri'
  require 'net/http'
  require 'pdf_gen/prawn'

  layout :determine_layout

  before_filter :check_localization
  before_filter :authorize
  before_filter :access_denied, only: [
                                        :active_calls_graph, :server_load, :update_server_load,
                                        :files, :bulk_management, :bulk_delete, :archived_calls_download,
                                        :archived_calls_delete, :terminator_active_calls, :calls_dashboard,
                                        :user_stats, :active_calls_per_server, :active_calls_per_user_op,
                                        :active_calls_cps_cc_live, :debug_log
                                      ], unless: -> { admin? || manager? }
  before_filter :check_authentication, only: [:active_calls, :active_calls_count, :active_calls_show]
  before_filter :load_ok?, only: [:show_user_stats, :active_calls, :calls_per_day,
    :all_users_detailed, :calls_list, :load_stats, :old_calls_stats, :users_finances, :profit,
    :country_stats, :first_activity, :hangup_cause_codes_stats, :system_stats, :action_log]
  before_filter :find_user_from_id_or_session, only: [:call_list, :index, :user_stats,
    :call_list_to_csv, :call_list_from_link, :user_logins, :call_list_to_pdf]
  before_filter :check_post_method, only: [:country_stats_download_table_data, :archived_calls_resync]
  before_filter :no_cache, only: [:active_calls]
  before_filter :no_users, only: [:old_calls_stats]
  before_filter :strip_params, only: [:calls_list, :old_calls_stats]
  before_filter :check_if_searching, only: [:calls_list, :old_calls_stats, :user_stats]
  before_filter :number_separator, only: [:server_load, :update_server_load]
  before_filter :strip_params, only: [:active_calls_show, :calls_list]
  before_action :aurora_active?, only: %(:old_calls_stats)

  before_filter do |var|
    var.instance_variable_set :@allow_read, true
    var.instance_variable_set :@allow_edit, true
  end

  before_action :calls_dashboard_options, only: [:calls_dashboard]
  before_action :server_load_options, :server_load_find_server, only: [:server_load, :update_server_load, :check_radius_status, :check_es_status]

  def index
    redirect_to(action: :user_stats) && (return false)
  end

  def prepare_calls_by_client_for_es
    options = {}
    options[:gte] = es_session_from
    options[:lte] = es_session_till
    options[:users] = (current_user.show_only_assigned_users?) ?
        User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id) :
        User.where("usertype <> 'manager' AND usertype <> 'admin'").pluck(:id)
    options[:ex] = @current_user.active_currency.exchange_rate
    options[:current_user] = @current_user

    options
  end

  def show_user_stats
    adjust_m2_date
    change_date
    change_date_to_present if params[:clear]

    @options ||= {}
    @options[:from] = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s) + ' ' + good_date(session[:hour_from].to_s) + ':' + good_date(session[:minute_from].to_s) + ':00'
    @options[:till] = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s) + ' ' + good_date(session[:hour_till].to_s) + ':' + good_date(session[:minute_till].to_s) + ':59'

    @data = EsCallsByUser.get_data(prepare_calls_by_client_for_es)

    render layout: 'm2_admin_layout'
  end

  def all_users_detailed
    @page_title = _('All_users_detailed')
    @users = User.where('hidden = 0') # , :conditions => "usertype = 'user'") #, :limit => 6)
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Integrity_Check'
    @searching = params[:search_on].to_i == 1
    change_date

    if @searching
      session[:hour_from] = '00'
      session[:minute_from] = '00'
      session[:hour_till] = '23'
      session[:minute_till] = '59'

      @call_stats = Call.total_calls_by_direction_and_disposition(session_time_from_db, session_time_till_db)

      @o_answered_calls = 0
      @o_no_answer_calls = 0
      @o_busy_calls = 0
      @o_failed_calls = 0
      @i_answered_calls = 0
      @i_no_answer_calls = 0
      @i_busy_calls = 0
      @i_failed_calls = 0
      @call_stats.each do |stats|
        direction = stats['direction'].to_s
        disposition = stats['disposition'].to_s.upcase
        total_calls = stats['total_calls'].to_i
        if direction == 'outgoing'
          if disposition == 'ANSWERED'
            @o_answered_calls = total_calls
          elsif disposition == 'NO ANSWER'
            @o_no_answer_calls = total_calls
          elsif disposition == 'BUSY'
            @o_busy_calls = total_calls
          elsif disposition == 'FAILED'
            @o_failed_calls = total_calls
          end
        elsif direction == 'incoming'
          if disposition == 'ANSWERED'
            @i_answered_calls = total_calls
          elsif disposition == 'NO ANSWER'
            @i_no_answer_calls = total_calls
          elsif disposition == 'BUSY'
            @i_busy_calls = total_calls
          elsif disposition == 'FAILED'
            @i_failed_calls = total_calls
          end
        end
      end
      @outgoing_calls = @o_answered_calls + @o_no_answer_calls + @o_busy_calls + @o_failed_calls
      @incoming_calls = @i_answered_calls + @i_no_answer_calls + @i_busy_calls + @i_failed_calls
      @total_calls = @incoming_calls + @outgoing_calls

      sfd = session_time_from_db
      std = session_time_till_db

      @outgoing_perc = 0
      @outgoing_perc = @outgoing_calls.to_d / @total_calls * 100 if @total_calls > 0
      @incoming_perc = 0
      @incoming_perc = @incoming_calls.to_d / @total_calls * 100 if @total_calls > 0

      @o_answered_perc = 0
      @o_answered_perc = @o_answered_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_no_answer_perc = 0
      @o_no_answer_perc = @o_no_answer_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_busy_perc = 0
      @o_busy_perc = @o_busy_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0
      @o_failed_perc = 0
      @o_failed_perc = @o_failed_calls.to_d / @outgoing_calls * 100 if @outgoing_calls > 0

      @i_answered_perc = 0
      @i_answered_perc = @i_answered_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_no_answer_perc = 0
      @i_no_answer_perc = @i_no_answer_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_busy_perc = 0
      @i_busy_perc = @i_busy_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0
      @i_failed_perc = 0
      @i_failed_perc = @i_failed_calls.to_d / @incoming_calls * 100 if @incoming_calls > 0

      @t_answered_calls = @o_answered_calls + @i_answered_calls
      @t_no_answer_calls = @o_no_answer_calls + @i_no_answer_calls
      @t_busy_calls = @o_busy_calls + @i_busy_calls
      @t_failed_calls = @o_failed_calls + @i_failed_calls

      @t_answered_perc = 0
      @t_answered_perc = @t_answered_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_no_answer_perc = 0
      @t_no_answer_perc = @t_no_answer_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_busy_perc = 0
      @t_busy_perc = @t_busy_calls.to_d / @total_calls * 100 if @total_calls > 0
      @t_failed_perc = 0
      @t_failed_perc = @t_failed_calls.to_d / @total_calls * 100 if @total_calls > 0

      @a_date, @a_calls, @a_billsec, @a_avg_billsec, @total_sums = Call.answered_calls_day_by_day(session_time_from_db, session_time_till_db)

      @t_calls = @total_sums['total_calls'].to_i
      @t_billsec = @total_sums['total_billsec'].to_i
      @t_avg_billsec = @total_sums['average_billsec'].to_i

      index = @a_date.length

      # @t_avg_billsec =  @t_billsec / @t_calls if @t_calls > 0

      # formating graph for INCOMING/OUTGOING calls

      @Out_in_calls_graph = "\""
      if @t_calls > 0
        @Out_in_calls_graph += _('Outgoing') + ';' + @outgoing_calls.to_s + ';' + 'false' + '\\n' + _('Incoming') + ';' + @incoming_calls.to_s + ';' + 'false' + "\\n\""
      else
        @Out_in_calls_graph = "\"No result" + ';' + '1' + ';' + 'false' + "\\n\""
      end

      # formating graph for Call-type calls

      @Out_in_calls_graph2 = "\""
      if @t_calls > 0

        @Out_in_calls_graph2 += _('ANSWERED') + ';' + @t_answered_calls.to_s + ';' + 'false' + "\\n"
        @Out_in_calls_graph2 += _('NO_ANSWER') + ';' + @t_no_answer_calls.to_s + ';' + 'false' + "\\n"
        @Out_in_calls_graph2 += _('BUSY') + ';' + @t_busy_calls.to_s + ';' + 'false' + "\\n"
        @Out_in_calls_graph2 += _('FAILED') + ';' + @t_failed_calls.to_s + ';' + 'false' + "\\n"

        @Out_in_calls_graph2 += "\""
      else
        @Out_in_calls_graph2 = "\"No result" + ';' + '1' + ';' + 'false' + "\\n\""
      end

      # formating graph for Calls

      @Calls_graph = ''
      (0..@a_calls.size - 1).each do |index|
        @Calls_graph += @a_date[index].to_s + ';' + @a_calls[index].to_i.to_s + "\\n"
      end
      # formating graph for Calltime

      @Calltime_graph = ''
      (0..@a_billsec.size - 1).each do |index|
        @Calltime_graph += @a_date[index].to_s + ';' + (@a_billsec[index].to_i / 60).to_s + "\\n"
      end

      # formating graph for Avg.Calltime
      @Avg_Calltime_graph = ''
      (0..@a_avg_billsec.size - 1).each do |index|
        @Avg_Calltime_graph += @a_date[index].to_s + ';' + @a_avg_billsec[index].to_i.to_s + "\\n"
      end
    end
  end

  def user_stats
    @options = user_stats_options
    @data = EsUserStats.new(
      from: es_session_from, till: es_session_till,
      ufrom: @options[:from], utill: @options[:till],
      page: params[:page].to_i, size: session[:items_per_page].to_i,
      current_user: @options[:current_user],
      user_id: @options[:user_id]
    )
    # Disposition stats: a table and a piechart
    disp_stats = @data.disposition_stats
    @disp_table = disp_stats.stats
    # Tranlsate the piechart
    @piechart = disp_stats.piechart.map { |row| [_(row[0]), row[1]] }

    # Daily stats: days report, calls, duration, and acd histograms
    @daily_stats = @data.daily_stats
  end

  # in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def user_logins
    change_date
    @Login_graph = []

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page_title = _('Login_stats_for') + nice_user(@user)

    date_start = Time.mktime(session[:year_from], session[:month_from], session[:day_from])
    date_end = Time.mktime(session[:year_till], session[:month_till], session[:day_till])

    @MyDay = Struct.new('MyDay', :date, :login, :logout, :duration)
    @a = [] # day
    @b = [] # login
    @c = [] # logout
    @d = [] # duration

    # making date array
    date_end = Time.now if date_end > Time.now
    if date_start == date_end
      @a << date_start
    else
      date = date_start
      while date < (date_end + 1.day)
        @a << date
        date += 1.day
      end
    end

    @total_pages = (@a.size.to_d / 10.to_d).ceil
    @all_date = @a
    @a = []
    iend = ((10 * @page) - 1)
    iend = @all_date.size - 1 if iend > (@all_date.size - 1)
    for index in ((@page - 1) * 10)..iend
      @a << @all_date[index]
    end
    @page_select_header_id = @user.id

    # make state lists for every date
    lgn_graph_i = 0

    user_id = @user.id

    @a.each do |date|
      bb = [] # login date
      cc = [] # logout date
      dd = [] # duration

      date_str = date.strftime('%Y-%m-%d')
      # let's find starting action for the day
      start_action = Action.where(['user_id = ? AND SUBSTRING(date,1,10) < ?', user_id, date_str]).order('date DESC').first
      other_actions = Action.where(['user_id = ? AND SUBSTRING(date,1,10) = ?', user_id, date_str]).order('date ASC')

      # form array for actions
      actions = []
      actions << start_action if start_action
      for oa in other_actions
        actions << oa
      end

      # compress array removing spare logins/logouts
      pa = 0 # previous action to compare
      # if actions.size > 0
      (1..actions.size - 1).each do |index|
        if actions[index].action == actions[pa].action # and actions[i] != actions.last
          actions[index] = nil
        else
          pa = index
        end
        index += 1
      end
      actions.compact!
      # build array from data
      unless actions.empty? # fix if we do not have data
        if actions.size == 1
          # all day same state
          date_next_day = date + 1.day
          if actions[0].action == 'login'
            bb << date
            cc << date_next_day - 1.second
            dd << date_next_day - date
          end

        else
          # we have some state change during day
          index = 1
          index = 0 if actions[0].action == 'login'

          (actions.size / 2).times do

            # login
            lin = (actions[index].date.day == date.day) ? actions[index].date :  date
            # logout
            lout = actions[index + 1] ? actions[index + 1].date : (date + 1.day - 1.second)  # we have logout

            bb << lin
            cc << lout
            dd << lout - lin

            index += 2
          end
        end

      end

      @b << bb
      @c << cc
      @d << dd

      hours = {}

      index = 0
      12.times do
        hours[(index * 8)] = (index * 2).to_s
        index += 1
      end

      # hours = {0 => "0", 2=>"2", 4=>"4", 6=>"6", 8=>"8", 10=>"10",12=>"12",  14=>"14", 16=>"16", 18=>"18", 20=>"20", 22=>"22" }

      # format data array
      # for i in 0..95

      arr = []
      96.times do
        arr << 0
      end

      (0..bb.size - 1).each do |index|
        range_start = (bb[index].hour * 60 + bb[index].min) / 15
        range_end = (cc[index].hour * 60 + cc[index].min) / 15
        (range_start..range_end).each do |iindex|
          arr[iindex] = 1
        end
      end

      # formating graph for Log States whit flash
      @Login_graph[lgn_graph_i] = ''
      rr = 0
      while rr <= 96
        db = rr % 8
        as = rr / 4
        if db == 0
          @Login_graph[lgn_graph_i] += as.to_s + ';' + arr[rr].to_s + "\\n"
        end
        rr += 1
      end

      lgn_graph_i += 1
    end

    @days = @MyDay.new(@a, @b, @c, @d)
  end

  # in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def call_list_from_link

    @date_from = params[:date_from]
    @date_till = params[:date_till].to_s != 'time_now' ? params[:date_till] : Time.now.strftime('%Y-%m-%d %H:%M:%S')

    @call_type = 'all'
    @call_type = params[:call_type] if params[:call_type]

    page_titles = {
      'all' => _('all_calls'),
      'answered' => _('answered_calls'),
      'answered_inc' => _('incoming_calls'),
      'missed' => _('missed_calls')
    }

    @page_title = "#{page_titles[@call_type]}: #{nice_user(@user)}"

    @calls = @user.calls(@call_type, @date_from, @date_till)

    @total_duration = 0
    @total_price = 0
    @total_billsec = 0

    @curr_rate = {}
    @curr_rate2 = {}
    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    @calls.each do |call|
      call_id = call.id
      @total_duration += call.duration
      call_user_price = call.user_price
      @rate_cur = Currency.count_exchange_prices(exrate: exrate, prices: [call_user_price.to_d]) if call_user_price
      @total_price += @rate_cur if call_user_price
      @curr_rate[call_id] = @rate_cur
      @total_billsec += call.nice_billsec
    end

    @show_destination = params[:show_dst]
    redirect_to controller: 'stats', action: 'call_list', id: @user.id, call_type: @call_type, date_from_link: @date_from, date_till_link: @date_till, direction: 'outgoing' # and return false
  end

  # in before filter : user (:find_user_from_id_or_session)
  def calls_list
    @page_title = _('calls_list')
    @page_icon = 'call.png'
    @show_currency_selector = 1

    adjust_m2_date
    change_date
    search_from = limit_search_by_days

    if user?
      unless (@user = current_user)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end

      @hide_non_answered_calls_for_user = (@user.hide_non_answered_calls.to_i == 1)
    end

    @options = last_calls_stats_parse_params(false, @hide_non_answered_calls_for_user)
    is_devices_for_sope_present

    if user?
      @origination_points, @origination_point, @termination_points, @termination_point = last_calls_stats_user(@user, @options)
    end

    if admin? || manager?
      @user, @tp_user, @origination_points, @origination_point, @hgcs, @hgc, @termination_points, @termination_point = last_calls_stats_admin(@options)
      @options[:servers] = Server.select(:id, 'CONCAT("ID: ", id, ", IP: ", server_ip, " (", comment, ")") AS nice_description')
                                 .where(server_type: 'freeswitch')
                                 .all
    end

    session[:calls_list] = @options
    options = last_calls_stats_set_variables(@options, user: @user, origination_point: @origination_point,
                                                       hgc: @hgc, current_user: current_user,
                                                       termination_point: @termination_point,
                                                       tp_user: @tp_user)
    options[:from_es] = es_session_from
    options[:till_es] = es_session_till
    options[:usertype] = @current_user.try(:usertype)
    options[:current_user] = current_user
    options[:from_no_tz] = session_from_datetime_no_timezone
    options[:till_no_tz] = session_till_datetime_no_timezone

    @column_options = call_list_additional_columns
    options[:column_options] = @column_options
    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    type = 'pdf' if params[:pdf].to_i == 1

    case type
      when 'html'
        if @options[:s_user_id].present? && (params[:commit] == 'refine' || params[:search_on].to_i == 1 || params[:page].present?)
          @total_calls_stats = EsLastCallsTotals.last_calls_totals(options)
          @total_calls = @total_calls_stats[:total_calls]
          @calls = Call.last_calls(options)
          if @calls.first.to_s == 'error'
            flash[:notice] =  @calls.last
            redirect_to(action: :calls_list, clear: true) && (return false)
          end
        else
          @total_calls_stats = []
          @total_calls = 0
          @calls = []
        end
        @show_destination = 1
        params.reverse_update(options.slice(:order_by, :order_desc))
        session[:calls_list] = @options
      when 'pdf'
        options[:column_dem] = '.'
        options[:current_user] = current_user
        calls, test_data = Call.last_calls_csv(options.merge(pdf: 1))
        if calls.to_s == 'error'
          flash[:notice] =  test_data
          (render json: {data: test_data}) && (return false)
        end
        total_calls = EsLastCallsTotals.last_calls_totals(options)
        pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user, direction: '', date_from: options[:from_no_tz], date_till: options[:till_no_tz], show_currency: session[:show_currency], rs_active: reseller_active?, column_options: @column_options)
        @show_destination = 1
        session[:calls_list] = @options
        if params[:test].to_i == 1
          render text: 'OK'
        elsif !@user || Confline.get_value('Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls').to_i == 0
          cookies['fileDownload'] = 'true'
          send_data pdf.render, filename: "Calls_#{options[:from_no_tz]}-#{options[:till_no_tz]}.pdf", type: 'application/pdf'
        else
          cookies['fileDownload'] = 'true'
          send_data pdf.render, filename: "#{nice_user(@user).gsub(' ', '_')}_Calls_#{options[:from_no_tz]}-#{options[:till_no_tz]}.pdf", type: 'application/pdf'
        end
      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user] = current_user
        options[:show_full_src] = session[:show_full_src]
        options[:csv] = true
        options[:cdr_template_id] = params[:cdr_template_id] if params[:cdr_template_id].present?

        if options[:cdr_template_id].present?
          Call.last_calls_csv(options) && (return false)
        else
          filename, test_data = Call.last_calls_csv(options)
          if filename.to_s == 'error'
            flash[:notice] =  test_data
            (render json: {data: test_data}) && (return false)
          end
        end

        if filename
          filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)
          if (params[:test].to_i == 1) && (@user != nil) && (Confline.get_value('Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls').to_i != 0)
            render text: ("#{nice_user(@user).gsub(' ', '_')}_" << filename) + test_data.to_s
          elsif params[:test].to_i == 1
            render text: filename + test_data.to_s
          elsif @user.blank? || (Confline.get_value('Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls').to_i == 0)
            file = File.open(filename) if File.exist?(filename)
            cookies['fileDownload'] = 'true'
            send_data file.read, filename: filename if file
          else
            file = File.open(filename)
            cookies['fileDownload'] = 'true'
            send_data file.read, filename: "#{nice_user(@user).gsub(' ', '_')}_" << filename
          end
        else
          flash[:notice] = _('Cannot_Download_CSV_File_From_DB_Server')
          (redirect_to :root) && (return false)
        end
    end
    @options[:page] = 1 if params[:commit]
  end

  def files
    @page_title = _('Files')
    @page_icon  = 'call.png'
    @help_link  = 'http://wiki.ocean-tel.uk/index.php/files'

    @files = get_archived_calls.delete_if do |filename|
      begin
        DateTime.strptime(filename.slice(23..38), '%Y%b%d-%H%M%S')
        DateTime.strptime(filename.slice(43..58), '%Y%b%d-%H%M%S')
        false
      rescue
        true
      end
    end
    file_array_hash = []
    @files.each do |file|
      file_hash = {name: file, from_date: "#{DateTime.strptime(file.slice(23..38), '%Y%b%d-%H%M%S')}", download: "#{Web_Dir}/stats/archived_calls_download?name=#{file}", delete_file: "#{Web_Dir}/stats/archived_calls_delete?name=#{file}" }
      file_array_hash << file_hash
    end

    @data = {table_rows: file_array_hash}

    @options ||= {}
    @options[:from] = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s) + ' ' + good_date(session[:hour_from].to_s) + ':' + good_date(session[:minute_from].to_s) + ':00'
    @options[:till] = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s) + ' ' + good_date(session[:hour_till].to_s) + ':' + good_date(session[:minute_till].to_s) + ':59'
  end

  def bulk_delete
    if params[:clear]
      change_date_to_present
    else
      @find_backup_size = 0
      adjust_m2_date
      change_date

      date_from_params = (params[:date_from][:year].to_s + '-' + params[:date_from][:month].to_s + '-' + params[:date_from][:day].to_s + ' ' + params[:date_from][:hour].to_s + ':' + params[:date_from][:minute].to_s + ':00').to_datetime
      date_till_params = (params[:date_till][:year].to_s + '-' + params[:date_till][:month].to_s + '-' + params[:date_till][:day].to_s + ' ' + params[:date_till][:hour].to_s + ':' + params[:date_till][:minute].to_s + ':59').to_datetime

      path = backup_path
      @files = get_archived_calls
      @files.each { |file|
        date_from_index = file.index('from_')
        date_till_index = file.index('to_')
        begin
          date_from = DateTime.strptime(file.slice(date_from_index + 5..date_from_index + 20), '%Y%b%d-%H%M%S')
          date_till = DateTime.strptime(file.slice(date_till_index + 3..date_till_index + 18), '%Y%b%d-%H%M%S')

          if (date_from_params <= date_from) && (date_till_params >= date_till)
            @find_backup_size += 1
            File.delete("#{path}/#{file}")
          end
        rescue
          flash[:notice] = _('Cannot_delete_files')
          (redirect_to action: :files) && (return false)
        end
      }
      if @find_backup_size > 0
        flash[:status] = _('Archived_calls_files_deleted') + ': ' + @find_backup_size.to_s
      else
        flash[:notice] = _('Files_were_not_found')
      end
    end
    redirect_to action: :files
  end

  def archived_calls_download
    path = backup_path
    if params[:name].present?
      filename = params[:name]
      full_filename = path + '/' + filename
      begin
        send_file full_filename, filename: filename, x_sendfile: true, stream: true
      rescue
        flash[:notice] = _('Archived_calls_file_missing')
        (redirect_to action: :files) && (return false)
      end
    end
  end

  def archived_calls_delete
    path = backup_path
    full_filename = path + '/' + params[:name]
    if File.exist?(full_filename)
      File.delete(full_filename)
    else
      flash[:notice] = _('Archived_calls_file_missing')
      (redirect_to action: :files) && (return false)
    end
    flash[:status] = _('Archived_calls_file_deleted')
    redirect_to action: :files
  end

  def old_calls_stats
    @page_title = _('Old_Calls')
    @page_icon  = 'call.png'
    @help_link  = 'http://wiki.ocean-tel.uk/index.php/Old_calls'

    change_date

    @show_currency_selector = 1
    @options = last_calls_stats_parse_params(true)

    time = current_user.user_time(Time.now)
    from = session_from_datetime_array != [time.year.to_s, time.month.to_s, time.day.to_s, '0', '0', '00']
    till = session_till_datetime_array != [time.year.to_s, time.month.to_s, time.day.to_s, '23', '59', '59']

    if from || till
      @options[:search_on] = 1
    end

    @devices_for_sope_present = Device.find_all_for_select(corrected_user_id).present?

    if user?
      unless (@user = current_user)
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    if admin? || manager?
      @user, @tp_user, @origination_points, @origination_point, @hgcs, @hgc, @termination_points, @termination_point = last_calls_stats_admin(@options)
      @options[:servers] = Server.select(:id, 'CONCAT("ID: ", id, ", IP: ", server_ip, " (", comment, ")") AS nice_description')
                           .where(server_type: 'freeswitch')
                           .all
    end

    session[:calls_list] = @options
    options = last_calls_stats_set_variables(@options, {user: @user, origination_point: @origination_point,
                                                        hgc: @hgc, current_user: current_user,
                                                        termination_point: @termination_point,
                                                        tp_user: @tp_user})

    type = 'html'
    type = 'csv' if params[:csv].to_i == 1
    # type = 'pdf' if params[:pdf].to_i == 1
    use_cloud = @options[:use_cloud]
    if use_cloud
      archived_calls_table_resync
    end
    case type
      when 'html'
        flash[:warning] =
          if params[:search_in] == 'cloud' && !aurora_active?
            _('Cloud_misconfiguration_warning')
          end

        if @searching && @options[:s_user_id].present?
          @total_calls_stats = use_cloud ? AWS::ArchivedCall.totals(options) : OldCall.last_calls_total_stats(options)
          @total_calls = @total_calls_stats.total_calls.to_i
          logger.debug " >> Total calls: #{@total_calls}"
          @calls = use_cloud ? AWS::ArchivedCall.calls(options) : OldCall.last_calls(options)
          logger.debug("  >> Calls #{@calls.size}")
        else
          @total_calls_stats = []
          @total_calls = 0
          @calls = []
        end
        @total_pages = (@total_calls / session[:items_per_page].to_d).ceil
        options[:page] = @total_pages if options[:page].to_i > @total_pages.to_i
        options[:page] = 1 if options[:page].to_i < 1
        @show_destination = 1
        session[:calls_list] = @options
      # @calls = [@calls[1]]

      # when 'pdf'
      #   options[:column_dem] = '.'
      #   options[:current_user] = current_user
      #   calls, test_data = OldCall.last_calls_csv(options.merge({:pdf => 1}))
      #   total_calls = OldCall.last_calls_total_stats(options)
      #   pdf = PdfGen::Generate.generate_last_calls_pdf(calls, total_calls, current_user, {:direction => '', :date_from => session_from_datetime, :date_till => session_till_datetime, :show_currency => session[:show_currency], :rs_active => rs_active?})
      #   logger.debug("  >> Calls #{calls.size}")
      #   @show_destination = 1
      #   session[:calls_list] = @options
      #   if params[:test].to_i == 1
      #     render :text => "OK"
      #   else
      #     send_data pdf.render, :filename => "Calls_#{session_from_datetime}-#{session_till_datetime}.pdf", :type => "application/pdf"
      #   end

      when 'csv'
        options[:test] = 1 if params[:test]
        options[:collumn_separator], options[:column_dem] = current_user.csv_params
        options[:current_user]  = current_user
        options[:show_full_src] = session[:show_full_src]
        options[:csv] = true
        filename, test_data = use_cloud ? AWS::ArchivedCall.as_csv(options) : OldCall.last_calls_csv(options)
        filename = load_file_through_database(filename) if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
        if filename
          filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)
          if (params[:test].to_i == 1) && (@user != nil) && (Confline.get_value('Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls').to_i != 0)
            render text: ("#{nice_user(@user).gsub(' ', '_')}_" << filename) + test_data.to_s
          elsif params[:test].to_i == 1
            render text: filename + test_data.to_s
          elsif @user.blank? || (Confline.get_value('Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls').to_i == 0)
            file = File.open(filename) if File.exist?(filename)
            send_data file.read, filename: filename if file
          else
            file = File.open(filename)
            send_data file.read, filename: "#{nice_user(@user).gsub(' ', '_')}_" << filename
          end
        else
          flash[:notice] = _('Cannot_Download_CSV_File_From_DB_Server')
          (redirect_to :root) && (return false)
        end
    end

    @options[:page] = 1 if params[:commit]
  end

  def call_list
    dont_be_so_smart
    (redirect_to :root) && (return false)
  end

  def country_stats
    adjust_m2_date
    change_date

    country_stats_parse_params

    @data = EsCountryStats.get_data(
        s_user_id: @options[:user_id], current_user: current_user,
        from: es_limit_search_by_days, till: es_session_till, exrate: change_exchange_rate
    )
    session[:country_stats] = @options
  end

  def country_stats_download_table_data
    filename = Call.country_stats_download_table_csv(params, current_user)
    filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)

    cookies['fileDownload'] = 'true'
    send_data(File.open(filename).read, filename: filename.sub('/tmp/', ''))
  end

  ############ CSV ###############

  def last_calls_stats_admin
    redirect_to action: 'calls_list'
  end

  # in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def call_list_to_csv
    @direction = 'outgoing'
    params_direction = params[:direction]
    @direction = params_direction if params_direction

    @sel_device_id = 0
    params_device = params[:device]
    @sel_device_id = params_device.to_i if params_device

    @device = Device.where(['id = ?', @sel_device_id]).first if @sel_device_id > 0

    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    params_hgc = params[:hgc]
    @sel_hgc_id = params_hgc.to_i if params_hgc

    @hgc = Hangupcausecode.where(id: @sel_hgc_id).first if @sel_hgc_id > 0

    if session[:usertype].to_s != 'admin' && @user.is_reseller?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
    # res = session[:usertype] == 'admin' ? params[:reseller].to_i : 0
    params_date_from = params[:date_from]
    params_date_till = params[:date_till]
    params_call_type = params[:call_type]
    date_from = params_date_from ? params_date_from : session_from_datetime
    date_till = params_date_till ? params_date_till : session_till_datetime
    call_type = params_call_type ? params_call_type.to_s : 'answered'

    user_type = manager? ? 'admin' : session[:usertype]
    filename, test_data = @user.user_calls_to_csv(tz: current_user.time_offset, device: @device, direction: @direction, call_type: call_type, date_from: date_from, date_till: date_till, default_currency: session[:default_currency], show_currency: session[:show_currency], show_full_src: session[:show_full_src], hgc: @hgc, usertype: user_type, nice_number_digits: session[:nice_number_digits], test: params[:test].to_i)
    filename = load_file_through_database(filename) if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
    if filename
      filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)
      if params[:test].to_i != 1
        send_data(File.open(filename).read, filename: filename)
      else
        render text: filename + test_data.to_s
      end
    else
      flash[:notice] = _('Cannot_Download_CSV_File_From_DB_Server')
      (redirect_to :root) && (return false)
    end
  end

  ############ PDF ###############

  # in before filter : user (:find_user_from_id_or_session, :authorize_user)
  def call_list_to_pdf
    @direction = 'outgoing'
    @direction = params[:direction] if params[:direction]

    @sel_device_id = 0
    @sel_device_id = params[:device].to_i if params[:device]

    @device = Device.find(@sel_device_id) if @sel_device_id > 0

    @hgcs = Hangupcausecode.all
    @sel_hgc_id = 0
    @sel_hgc_id = params[:hgc].to_i if params[:hgc]

    @hgc = Hangupcausecode.where(id: @sel_hgc_id).first if @sel_hgc_id > 0

    date_from = params[:date_from]
    date_till = params[:date_till]
    call_type = params[:call_type]
    user = @user

    calls = user.calls(call_type, date_from, date_till, @direction, 'calldate', 'DESC', @device, hgc: @hgc)

    ###### Generate PDF ########
    pdf = Prawn::Document.new(size: 'A4', layout: :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    pdf.text("#{_('CDR_Records')}: #{user.first_name} #{user.last_name}", left: 40, size: 16)
    pdf.text(_('Period') + ': ' + date_from + '  -  ' + date_till, left: 40, size: 10)
    pdf.text(_('Currency') + ": #{session[:show_currency]}", left: 40, size: 8)
    pdf.text(_('Total_calls') + ": #{calls.size}", left: 40, size: 8)

    total_price = 0
    total_billsec = 0
    total_duration = 0
    total_prov_price = 0
    total_prfit = 0

    exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])

    items = []
    calls.each do |call|
      item = []
      @rate_cur3 = Currency.count_exchange_prices(exrate: exrate, prices: [call.user_price.to_d])
      @rate_prov = Currency.count_exchange_prices(exrate: exrate, prices: [call.provider_price.to_d]) if session[:usertype] == 'admin'
      # if session[:usertype] == 'reseller'
      #   # selfcost for reseller himself is user price, so profit always = 0 for his own calls
      #   @rate_prov = (call.reseller_id == 0) ?
      #       Currency.count_exchange_prices(exrate: exrate, prices: [call.user_price.to_d]) :
      #       Currency.count_exchange_prices(exrate: exrate, prices: [call.reseller_price.to_d])
      # end

      item << call.calldate.strftime('%Y-%m-%d %H:%M:%S')
      item << call.src
      item << hide_dst_for_user(current_user, 'pdf', call.dst.to_s)

      billsec = call.nice_billsec
      item << nice_time(billsec)
      duration = call.nice_duration
      item << nice_time(duration)

      item << call.disposition

      if admin? || manager? || reseller?
        item << nice_number(@rate_cur3)
        item << nice_number(@rate_prov)
        item << nice_number(@rate_cur3.to_d - @rate_prov.to_d)
        item << nice_number(@rate_cur3.to_d != 0.to_d ? ((@rate_cur3.to_d - @rate_prov.to_d) / @rate_cur3.to_d) * 100 : 0) + ' %'
        item << nice_number(@rate_prov.to_d != 0.to_d ? ((@rate_cur3.to_d / @rate_prov.to_d) * 100) - 100 : 0) + ' %'
      end

      price_element = 0
      price_element = @rate_cur3 if call.user_price
      total_price += price_element
      # total_price += @rate_cur3 if call.user_price
      total_prov_price += @rate_prov.to_d
      total_prfit += @rate_cur3.to_d - @rate_prov.to_d
      total_billsec += billsec
      total_duration += duration

      items << item
    end
    item = []
    # Totals
    item << {text: _('Total'), colspan: 3}
    item << nice_time(total_billsec)
    item << nice_time(total_duration)
    item << ' '
    if session[:usertype] == 'admin' || session[:usertype] == 'reseller'
      item << nice_number(total_price)
      item << nice_number(total_prov_price)
      item << nice_number(total_prfit)
      total_price_dec = total_price.to_d
      if total_price_dec != 0
        item << nice_number(total_price_dec != 0.to_d ? (total_prfit / total_price_dec) * 100 : 0) + ' %'
      else
        item << nice_number(0) + ' %'
      end
      if total_prov_price.to_d != 0
        item << nice_number(total_prov_price.to_d != 0 ? ((total_price_dec / total_prov_price.to_d) * 100) - 100 : 0) + ' %'
      else
        item << nice_number(0) + ' %'
      end
    else
      if @direction != 'incoming'
        item << nice_number(total_price)
      end
    end

    items << item

    headers, headers2 = PdfGen::Generate.call_list_to_pdf_header(pdf, @direction, current_user, 0, {})

    pdf.table(items,
              width: 550, border_width: 0,
              font_size: 7,
              headers: headers) do
    end

    string = '<page>/<total>'
    opt = {at: [500, 0], size: 9, align: :right, start_count_at: 1}
    pdf.number_pages string, opt

    send_data pdf.render, filename: "Calls_#{user.first_name}_#{user.last_name}_#{date_from}-#{date_till}.pdf", type: 'application/pdf'
  end

  def users_finances
    @page_title = _('Users_finances')
    @page_icon = 'money.png'
    @searching = params[:search_on].to_i == 1

    default = {page: '1', s_completed: '', s_username: '', s_fname: '', s_lname: '', s_balance_min: '', s_balance_max: '', s_type: ''}
    @options = !session[:users_finances_options] ? default : session[:users_finances_options]
    default.each { |key, value| @options[key] = params[key] if params[key] }

    if @searching
      owner_id = session[:user_id]
      cond = ['users.hidden = ?', 'users.owner_id = ?']
      var = [0, owner_id]

      if %w(postpaid prepaid).include?(@options[:s_type])
        cond << 'users.postpaid = ?'
        var << (@options[:s_type] == 'postpaid' ? 1 : 0)
      end

      add_contition_and_param(@options[:s_username], @options[:s_username] + '%', 'users.username LIKE ?', cond, var)
      add_contition_and_param(@options[:s_fname], @options[:s_fname] + '%', 'users.first_name LIKE  ?', cond, var)
      add_contition_and_param(@options[:s_lname], @options[:s_lname] + '%', 'users.last_name LIKE ?', cond, var)
      add_contition_and_param(@options[:s_balance_min], @options[:s_balance_min].to_d, 'users.balance >= ?', cond, var)
      add_contition_and_param(@options[:s_balance_max], @options[:s_balance_max].to_d, 'users.balance <= ?', cond, var)
      @total_users = User.where([cond.join(' AND ').to_s] + var).all.size.to_i

      items_per_page, total_pages = item_pages(@total_users)
      page_no = Application.valid_page_number(@options[:page], total_pages)
      offset, limit = Application.query_limit(total_pages, items_per_page, page_no)

      @total_pages = total_pages
      @options[:page] = page_no

      @users = User.where([cond.join(' AND ').to_s] + var)
                   .limit(limit)
                   .offset(offset).all

      @search = (cond.size.to_i > 2) ? 1 : 0
      @total_balance = @total_credit = @total_payments = @total_amount = 0
      @amounts = []
      @payment_size = []
      hide_uncompleted_payment = Confline.get_value('Hide_non_completed_payments_for_user', current_user.id).to_i

      @users.each_with_index do |user, _|
        payments = user.m2_payments
        amount = 0
        pz = 0
        currency_id = 0
        currency_name = 'USD'
        payments.each do |payment|
          # if hide_uncompleted_payment == 0 or
          # (hide_uncompleted_payment == 1 and (p.pending_reason != 'Unnotified payment' or p.pending_reason.blank?))
          #   if p.completed.to_i == @options[:s_completed].to_i or @options[:s_completed].blank?
          pz += 1
          pa = payment.amount
          payment_currency = payment.currency_id.to_i
          if payment_currency != currency_id.to_i
            currency_id = payment_currency
            currency_name = Currency.where("id = #{currency_id}").first.try(:name).to_s
            currency_name = 'USD' if currency_name.blank?
          end
          amount += get_price_exchange(pa, currency_name)
          #   end
          # end
        end
        @amounts[user.id] = amount
        @payment_size[user.id] = pz
        @total_balance += user.balance
        @total_credit += user.credit if user.credit != (-1) && user.postpaid.to_i != 0
        @total_payments += pz
        @total_amount += amount
      end
    end
    session[:users_finances_options] = @options
  end

  def get_rs_user_map
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1
    @responsible_accountant_id.to_s != '-1' ? cond = ['responsible_accountant_id = ?', @responsible_accountant_id] : ''
    output = []
    output << "<option value='-1'>All</option>"
    output << User.where(cond).map { |user| ["<option value='" + user.id.to_s + "'>" + nice_user(user) + '</option>'] }
    render text: output.join
  end

  def profit
    @page_title = _('Profit')
    @page_icon = 'money.png'
    change_date
    @searching = params[:search_on].to_i == 1
    @sub_vat = 0
    owner = correct_owner_id

    if admin?
      @responsible_accountants = User.select('accountants.*')
                                     .joins(['JOIN users accountants ON(accountants.id = users.responsible_accountant_id)'])
                                     .where("accountants.hidden = 0 and accountants.usertype = 'manager'")
                                     .group('accountants.id').order('accountants.username')
    end

    @search_user = params[:s_user]
    @user_id = params[:s_user_id]

    up, rp, pp = current_user.get_price_calculation_sqls
    @user_id = params[:s_user_id] ? params[:s_user_id].to_i : -1
    @user_id = -1 if @user_id == -2 && @search_user.blank?
    @responsible_accountant_id = params[:responsible_accountant_id] ? params[:responsible_accountant_id].to_i : -1

    if @searching
      session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = ['00', '00', '23', '59']
      conditions, user_sql2, select = Stat.find_sql_conditions_for_profit(reseller?, session[:user_id].to_i, @user_id, @responsible_accountant_id, session_from_datetime, session_till_datetime, up, pp)

      total = Call.find_totals_for_profit_prices(select, conditions)

      @total_duration = (total['billsec']).to_i
      @total_call_price = (total['user_price']).to_d
      @total_call_selfprice = total['provider_price'].to_d

      total = Call.find_totals_for_profit(conditions)

      if total && total[0] && total[0]['total_calls'].to_i != 0
        @total_calls = total[0]['total_calls'].to_i
        @total_answered_calls = total[0]['answered_calls'].to_i
        @total_not_ans_calls = total[0]['no_answer_calls'].to_i
        @total_busy_calls = total[0]['busy_calls'].to_i
        @total_error_calls = total[0]['failed_calls'].to_i

        if @total_calls != 0
          @average_call_duration = @total_duration.to_d / @total_answered_calls.to_d

          @total_answer_percent = @total_answered_calls.to_d * 100 / @total_calls.to_d
          @total_not_ans_percent = @total_not_ans_calls.to_d * 100 / @total_calls.to_d
          @total_busy_percent = @total_busy_calls.to_d * 100 / @total_calls.to_d
          @total_error_percent = @total_error_calls.to_d * 100 / @total_calls.to_d
        else
          @total_answer_percent = @total_not_ans_percent = @total_busy_percent = @total_error_percent = @average_call_duration = 0
        end
      else
        @total_calls = @total_answered_calls = 0
        @total_answer_percent = @total_not_ans_percent = @total_busy_percent = @total_error_percent = 0
        @average_call_duration = @total_not_ans_calls = @total_busy_calls = @total_error_calls = 0
      end

      @total_profit = @total_call_price - @total_call_selfprice

      if @total_call_price != 0 && @total_answered_calls != 0
        select = ['']
        res = Call.where("#{SqlExport.replace_price("SUM(#{up})", reference: 'price')}, SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'duration', COUNT(DISTINCT(calls.user_id)) AS 'users'")
                  .joins('LEFT JOIN users ON (users.id = calls.user_id)')
                  .where((conditions + ["calls.disposition = 'ANSWERED'"]).join(' AND '))

        resu = Call.select("COUNT(DISTINCT(calls.user_id)) AS 'users'")
                   .joins('LEFT JOIN users ON (users.id = calls.user_id)')
                   .where((conditions + ["calls.disposition = 'ANSWERED'"]).join(' AND '))
        @total_users = resu[0]['users'].to_i if resu && resu[0]

        @total_percent = 100
        @total_profit_percent = @total_profit.to_d * 100 / @total_call_price.to_d
        @total_selfcost_percent = @total_percent - @total_profit_percent
        # average
        @total_duration_min = @total_duration.to_d / 60
        @avg_profit_call_min = @total_profit.to_d / @total_duration_min
        @avg_profit_call = @total_profit.to_d / @total_answered_calls.to_d
        days = (session_till_date.to_date - session_from_date.to_date).to_f
        days = 1.0 if days == 0
        @avg_profit_day = @total_profit.to_d / (session_till_date.to_date - session_from_datetime.to_date + 1).to_i
        @avg_profit_user = (@total_users != 0) ? (@total_profit.to_d / @total_users.to_d) : 0
      else
        # profit
        @total_percent = 0
        @total_profit_percent = 0
        @total_selfcost_percent = 0
        # avg
        @avg_profit_call_min = 0
        @avg_profit_call = 0
        @avg_profit_day = 0
        @avg_profit_user = 0
      end

      a1 = session_from_datetime
      a2 = session_till_datetime
      @s_total_profit = @total_profit
    end
  end

  # Generates profit report in PDF
  def generate_profit_pdf
    @user_id = -1
    user_name = ''
    if params[:user_id]
      if params[:user_id] != '-1'
        @user_id = params[:user_id]
        user = User.find_by_sql("SELECT * FROM users WHERE users.id = '#{@user_id}'")
        user_name = user[0].present ? (user[0]['username'] + ' - ' + user[0]['first_name'] + ' ' +
            user[0]['last_name']) :
        params[:username].to_s
      else
        user_name = 'All users'
      end
    end

    pdf = Prawn::Document.new(size: 'A4', layout: :portrait)
    pdf.font_families.update('arial' => {
        bold: "#{Prawn::BASEDIR}/data/fonts/Arialb.ttf",
        italic: "#{Prawn::BASEDIR}/data/fonts/Ariali.ttf",
        bold_italic: "#{Prawn::BASEDIR}/data/fonts/Arialbi.ttf",
        normal: "#{Prawn::BASEDIR}/data/fonts/Arial.ttf"})

    # pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf.text(_('PROFIT_REPORT'), {left: 40, size: 14, style: :bold})
    pdf.text(_('Time_period') + ': ' + session_from_date.to_s + ' - ' + session_till_date.to_s, {left: 40, size: 10, style: :bold})
    pdf.text(_('Counting') + ': ' + user_name.to_s, {left: 40, size: 10, style: :bold})

    pdf.move_down 60
    pdf.stroke do
      pdf.horizontal_line 0, 550, fill_color: '000000'
    end
    pdf.move_down 20

    items = [
        [_('Total_calls'), {text: params[:total_calls].to_s, align: :left}, {text: ' ', colspan: 3}],
        [_('Answered_calls'), {text: params[:total_answered_calls].to_s, align: :left}, {text: nice_number(params[:total_answer_percent].to_s) + ' %', align: :left}, _('Duration') + ': ' + nice_time(params[:total_duration]), _('Average_call_duration') + ': ' + nice_time(params[:average_call_duration])],
        [_('No_Answer'), {text: params[:total_not_ans_calls].to_s, align: :left}, {text: nice_number(params[:total_not_ans_percent].to_s) + ' %', align: :left}, {text: ' ', colspan: 2}],
        [_('Busy_calls'), {text: params[:total_busy_calls].to_s, align: :left}, {text: nice_number(params[:total_busy_percent].to_s) + ' %', align: :left}, {text: ' ', colspan: 2}],
        [_('Error_calls'), {text: params[:total_error_calls].to_s, align: :left}, {text: nice_number(params[:total_error_percent].to_s) + ' %', align: :left}, {text: ' ', colspan: 2}],
        # bold
        [' ', {text: _('Price'), align: :left, style: :bold}, {text: _('Percent'), align: :left, style: :bold}, {text: _('Call_time'), align: :left, style: :bold}, {text: _('Active_users'), align: :left, style: :bold}],
        [_('Total_call_price'), {text: nice_number(params[:total_call_price].to_s), align: :left}, {text: nice_number(params[:total_percent].to_s), align: :left}, {text: nice_time(params[:total_duration].to_s), align: :left}, {text: params[:active_users].to_i.to_s, align: :left}],
        [_('Total_call_self_price'), {text: nice_number(params[:total_call_selfprice].to_s), align: :left}, {text: nice_number(params[:total_selfcost_percent].to_s), align: :left}, {text: ' ', colspan: 2}],
        [_('Calls_profit'), {text: nice_number(params[:total_profit].to_s), align: :left}, {text: nice_number(params[:total_profit_percent].to_s), align: :left}, {text: ' ', colspan: 2}],
        [_('Average_profit_per_call_min'), {text: nice_number(params[:avg_profit_call_min].to_s), align: :left}, {text: ' ', colspan: 3}],
        [_('Average_profit_per_call'), {text: nice_number(params[:avg_profit_call].to_s), align: :left}, {text: ' ', colspan: 3}],
        [_('Average_profit_per_day'), {text: nice_number(params[:avg_profit_day].to_s), align: :left}, {text: ' ', colspan: 3}],
        [_('Average_profit_per_active_user'), {text: nice_number(params[:avg_profit_user].to_s), align: :left}, {text: ' ', colspan: 3}]
    ]
    if session[:usertype] != 'reseller'
      # bold
      items << [' ', {text: _('Price'), align: :left, style: :bold}, {text: ' ', colspan: 3}]
      # bold  1 collumn
      items << [{text: _('Total_profit'), align: :left, style: :bold}, {text: nice_number(params[:s_total].to_s), align: :left}, {text: ' ', colspan: 3}]
    end

    pdf.table(items,
              width: 550, border_width: 0,
              font_size: 9) do
      column(0).style(align: :left)
      column(1).style(align: :left)
      column(2).style(align: :left)
      column(3).style(align: :left)
      column(4).style(align: :left)
    end

    pdf.move_down 20
    pdf.stroke do
      pdf.horizontal_line 0, 550, fill_color: '000000'
    end

    send_data pdf.render, filename: "Profit-#{user_name}-#{session_from_date}_#{session_till_date}.pdf", type: 'application/pdf'
  end

  # ================= ACTIVE CALLS ====================

  def active_calls_count
    @acc = Activecall.count_calls(hide_active_calls_longer_than).to_s + ' / ' + Activecall.count_calls(hide_active_calls_longer_than, true).to_s
    render(layout: false)
  end

  def active_calls
    user = User.new(usertype: session[:usertype])
    user.id = session[:user_id]
    @page_title = _('Active_Calls')
    @page_icon = 'call.png'
    active_calls_show

    # search
    @countries = Direction.select(:name).order('name ASC')
    @termination_points = []
    @origination_points = []
    @servers = Server.select(:id, 'CONCAT("ID: ", id, ", IP: ", server_ip, " (", comment, ")") AS nice_description')
                     .where(server_type: 'freeswitch', active: 1)
                     .all
    @managers = User.where(usertype: 'manager').all if m4_functionality?
  end

  def active_calls_show
    @options = session[:active_calls_options] || {}
    @time_now = Time.now
    @refresh_period = session[:active_calls_refresh_interval].to_i

    # this code selects correct calls for admin/reseller/user
    user_sql = " (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
    user_id = manager? ? 0 : session[:user_id]
    @user_id = user_id

    if user_id != 0
      user_sql << " AND (activecalls.user_id = #{user_id} OR dst_usr.id = #{user_id}) "
    end

    user_sql << ' AND activecalls.active = 1'

    @ma_active = monitorings_addon_active?
    @show_server = Confline.active_calls_show_server?

    if user_id.to_s.blank? || params[:s_user].to_s == '-2'
      @active_calls = Activecall.where(id: nil)
    else
      @active_calls = Activecall
      .select(
          "activecalls.id as ac_id, activecalls.channel as channel, activecalls.prefix, activecalls.server_id as server_id,
          activecalls.answer_time as answer_time, activecalls.src as src, activecalls.localized_dst as dst, activecalls.uniqueid as uniqueid,
          activecalls.lega_codec as lega_codec,activecalls.legb_codec as legb_codec,activecalls.pdd as pdd,
          #{SqlExport.replace_price('activecalls.user_rate', {reference: 'user_rate', ex: change_exchange_rate})}, #{SqlExport.replace_price('activecalls.provider_rate', {reference: 'provider_rate', ex: change_exchange_rate})}, tariffs.currency as rate_currency,
          users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, users.username as user_username, users.owner_id as user_owner_id,
          devices.id as 'device_id',devices.device_type as device_type, devices.name as device_name, devices.username as device_username, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.host as device_host, devices.description as device_description, devices.ani as device_ani, devices.user_id as device_user_id,
          dst.id as dst_device_id,  dst.device_type as dst_device_type, dst.name as dst_device_name, dst.username as dst_device_username, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.host as dst_device_host, dst.description as dst_device_description, dst.ani as dst_device_ani, dst.user_id as dst_device_user_id,
          dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name, dst_usr.username as dst_user_username, dst_usr.owner_id as dst_user_owner_id,
          destinations.direction_code as direction_code, directions.name as direction_name, destinations.name as destination_name, destinations.prefix as destination_prefix,
          NOW() - activecalls.answer_time AS 'duration',
          IF(activecalls.answer_time IS NULL, 0, 1 ) as 'status'"
        ).joins(
          'LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
          LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
          LEFT JOIN users ON (users.id = devices.user_id)
          LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
          LEFT JOIN tariffs ON (tariffs.id = users.tariff_id)
          LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
          LEFT JOIN directions ON (directions.code = destinations.direction_code)'
        ).where(user_sql)

      # Search filter
      search = (params[:search_on] == '1') ? params : @options

      if search[:s_user].present? && search[:s_user_id].present? && search[:s_user_id].to_i >= 0
        @active_calls = @active_calls.where(user_id: search[:s_user_id])
      end

      if search[:s_device_op].present? && search[:s_device_op].to_i > 0
        @active_calls = @active_calls.where(src_device_id: search[:s_device_op])
      end

      if current_user.show_only_assigned_users?
        assigned_users = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
        @active_calls = @active_calls.where(user_id: assigned_users)
      end

      s_manager = params[:s_manager].to_i

      if m4_functionality? && !current_user.show_only_assigned_users? && s_manager > 0
        assigned_users = User.where("users.responsible_accountant_id = #{s_manager}").pluck(:id)
        @active_calls = @active_calls.where(user_id: assigned_users)
      end

      search_s_country = search[:s_country]
      if search_s_country.present?
        direction = Direction.where(name: search_s_country).first.code
        @active_calls = @active_calls.where('destinations.direction_code = ?', direction)
      end
      search_s_status = search[:s_status]
      if search_s_status.present?
        status = 'NOT' unless search_s_status.to_i.zero?
        @active_calls = @active_calls.where("answer_time IS #{status} NULL")
      end
      search_s_device = search[:s_device]
      if search_s_device.present? && search_s_device.to_i > 0
        @active_calls = @active_calls.where(dst_device_id: search[:s_device])
      end
      search_s_user_for_tp = search[:s_user_for_tp]
      s_user_tp_id = search[:s_user_for_tp_id]
      if search_s_user_for_tp.present? && s_user_tp_id.present? && s_user_tp_id.to_i >= 0
        @active_calls = @active_calls.where("dst_usr.id = #{s_user_tp_id.to_i}")
      end
      search_s_source = search[:s_source]
      if search_s_source.present?
        @active_calls = @active_calls.where('activecalls.src LIKE ?', search_s_source)
      end
      search_s_destination = search[:s_destination]
      if search_s_destination.present?
        @active_calls = @active_calls.where('activecalls.localized_dst LIKE ?', search_s_destination)
      end
      s_server = search[:s_server]
      if s_server.present?
        @active_calls = @active_calls.where('activecalls.server_id = ?', s_server)
      end
      # Active Calls Destination names by best matching prefix
      Activecall.update_calls_by_destinations(@active_calls)
    end

    session[:active_calls_options] = search

    json_except = user? ? [:uniqueid, :server_id, :channel, :lega_codec,
                           :legb_codec, :pdd, :dst_device_name,
                           :dst_device_id, :dst_device_type,
                           :dst_device_username, :dst_device_extension,
                           :dst_device_istrunk, :dst_device_host,
                           :dst_device_description, :dst_device_ani,
                           :dst_device_user_id] : []
    @active_calls_json = @active_calls.to_json(except: json_except)

    if request.xhr?
      return render json: @active_calls_json
    end
  end

  # SELECT activecalls.start_time as start_time, activecalls.src as src, activecalls.dst as dst, users.id as user_id, users.first_name as user_first_name, users.last_name as user_last_name, devices.device_type as device_type, devices.name as device_name, devices.extension as device_extension, devices.istrunk as device_istrunk, devices.ani as device_ani, dst.id as dst_id, dst.device_type as dst_device_type, dst.name as dst_device_name, dst.extension as dst_device_extension, dst.istrunk as dst_device_istrunk, dst.ani as dst_device_ani, dst_usr.id as dst_user_id, dst_usr.first_name as dst_user_first_name, dst_usr.last_name as dst_user_last_name
  # FROM activecalls
  # LEFT JOIN providers ON (providers.id =activecalls.provider_id)
  # LEFT JOIN devices ON (devices.id = activecalls.src_device_id)
  # LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
  # LEFT JOIN users ON (users.id = devices.user_id)
  # LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
  # LEFT JOIN destinations ON (destinations.prefix = activecalls.prefix)
  # LEFT JOIN directions ON (directions.code = destinations.direction_code)

  def active_calls_graph
    @page_title = _('active_calls_graph')
    @page_icon = 'call.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Active%20Calls%20Graph'
    @refresh_period = session[:active_calls_refresh_interval].to_i
    @total_answered_count = Activecall.count_calls(hide_active_calls_longer_than, false).to_s + ' / ' +
        Activecall.count_calls(hide_active_calls_longer_than, true).to_s
    @active_calls_data = ActiveCallsData.create_graph_data(user_tz)
    [@active_calls_data, @total_answered_count]
  end

  def update_graph_data
    return unless request.xhr?
    render json: {data: active_calls_graph}
  end

  def terminator_active_calls
    get_action_calls_data
  end

  def active_calls_per_user_op
    get_action_calls_data(op: 1)
  end

  def active_calls_per_server
    sql = "
      SELECT a.server_id AS 'server_id', IFNULL(MAX(a.answered), 0) AS 'answered', IFNULL(MAX(a.ringing), 0) AS 'ringing',
             IFNULL(MAX(a.answered) + MAX(a.ringing), 0) AS 'total',
             (IFNULL(MAX(a.answered), 0) / IFNULL(MAX(a.answered) + MAX(a.ringing), 0)) * 100 AS 'asr',
             CONCAT('ID: ', servers.id, ', IP: ', servers.server_ip, ' (', servers.comment, ')') AS 'server'
      FROM (
          SELECT server_id, COUNT(id) AS 'answered', 0 AS 'ringing'
          FROM activecalls
          WHERE active = 1 AND answer_time IS NOT NULL
          GROUP BY server_id

          UNION

          SELECT server_id, 0 AS 'answered', COUNT(id) AS 'ringing'
          FROM activecalls
          WHERE active = 1 AND answer_time IS NULL
          GROUP BY server_id
      ) AS a
      RIGHT JOIN servers ON a.server_id = servers.id
      WHERE active = 1 AND server_type = 'freeswitch'
      GROUP BY servers.id

      UNION

      SELECT a.server_id AS 'server_id', IFNULL(MAX(a.answered), 0) AS 'answered', IFNULL(MAX(a.ringing), 0) AS 'ringing',
             IFNULL(MAX(a.answered) + MAX(a.ringing), 0) AS 'total',
             (IFNULL(MAX(a.answered), 0) / IFNULL(MAX(a.answered) + MAX(a.ringing), 0)) * 100 AS 'asr',
             CONCAT('ID: ', servers.id, ', IP: ', servers.server_ip, ' (', servers.comment, ')') AS 'server'
      FROM (
          SELECT server_id, COUNT(id) AS 'answered', 0 AS 'ringing'
          FROM activecalls
          WHERE active = 1 AND answer_time IS NOT NULL
          GROUP BY server_id

          UNION

          SELECT server_id, 0 AS 'answered', COUNT(id) AS 'ringing'
          FROM activecalls
          WHERE active = 1 AND answer_time IS NULL
          GROUP BY server_id
      ) AS a
      RIGHT JOIN servers ON a.server_id = servers.id
      WHERE active = 1 AND server_type != 'freeswitch'
      GROUP BY servers.id
      HAVING total > 0
    "
    @data = ActiveRecord::Base.connection.select_all(sql).to_json
    @refresh_period = session[:active_calls_refresh_interval].to_i

    respond_to do |format|
      format.html
      format.json { render json: @data }
    end
  end

  def active_calls_cps_cc_live
    if !m4_functionality? || Confline.get_value('Use_Redis', 0).to_i != 1
      dont_be_so_smart
      redirect_to :root and return false
    end

    cps_cc_data = active_calls_cps_cc_live_data
    # Fill last 5 minutes with zero values
    #  and append last (current time) with Redis retrieved CPS/CC values

    @cps_data = (cps_cc_data[:time_now_timestamp]-299...cps_cc_data[:time_now_timestamp]).map do |time|
      [time, Time.at(time).in_time_zone(user_tz).to_a[0..5].reverse, 0, 0]
    end
    @cps_data << [cps_cc_data[:time_now_timestamp], cps_cc_data[:time_now_chart], cps_cc_data[:cps], (cps_cc_data[:cps].to_f / 30)]

    @cc_data = (cps_cc_data[:time_now_timestamp]-299...cps_cc_data[:time_now_timestamp]).map do |time|
      [time, Time.at(time).in_time_zone(user_tz).to_a[0..5].reverse, 0, 0]
    end
    @cc_data << [cps_cc_data[:time_now_timestamp], cps_cc_data[:time_now_chart], cps_cc_data[:cc], (cps_cc_data[:cc].to_f / 30)]
  end

  def active_calls_cps_cc_live_data
    response = {cps: 0, cc: 0}

    begin
      redis_connection = Redis.new(Confline.redis_connection_hash)
      response = {
          cps: (redis_connection.mget('CORE_CPS_GLOBAL').first.to_i || 0),
          cc: (redis_connection.mget('CORE_CC_GLOBAL').first.to_i || 0)
      }
      redis_connection.try(:disconnect!)
    rescue => error
      redis_connection.try(:disconnect!)
      response = {cps: 0, cc: 0}
    end

    time_now = Time.now.in_time_zone(user_tz)
    time_info = {
        time_now_timestamp: time_now.to_i,
        time_now_chart: time_now.to_a[0..5].reverse
    }

    response.merge(time_info)
  end

  def active_calls_cps_cc_live_update_data
    return unless request.xhr?
    render json: {data: active_calls_cps_cc_live_data}
  end

  # ======================== SYSTEM STATS ======================================

  def system_stats
    @page_title = _('System_stats')
    @page_icon = 'chart_pie.png'

    sql = "SELECT COUNT(users.id) as \'users\' FROM users"
    @total_users = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'admin'"
    @total_admin = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'reseller'"
    @total_resellers = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'accountant'"
    @total_accountant = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.usertype = 'user'"
    @total_t_user = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.postpaid = '1'"
    @total_pospaid = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(users.id) as \'users\' FROM users WHERE users.postpaid = '0'"
    @total_prepaid = get_system_stat(sql, 'users')

    sql = "SELECT COUNT(devices.id) as \'devices\' FROM devices"
    @total_devices = get_system_stat(sql, 'devices')

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs"
    @total_tariffs = get_system_stat(sql, 'tariffs')

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'provider'"
    @total_tariffs_provider = get_system_stat(sql, 'tariffs')

    sql = "SELECT COUNT(tariffs.id) as \'tariffs\' FROM tariffs WHERE tariffs.purpose = 'user_wholesale'"
    @total_tariffs_user_wholesale = get_system_stat(sql, 'tariffs')

    sql = "SELECT COUNT(directions.id) as \'directions\' FROM directions"
    @total_directions = get_system_stat(sql, 'directions')

    sql = "SELECT COUNT(destinations.id) as \'destinations\' FROM destinations"
    @total_destinations = get_system_stat(sql, 'destinations')

    sql = "SELECT COUNT(destinationgroups.id) as \'destinationgroups\' FROM destinationgroups"
    @total_dg = get_system_stat(sql, 'destinationgroups')

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls'
    @total_calls = get_system_stat(sql, 'calls')

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'ANSWERED\' '
    @total_calls_anws = get_system_stat(sql, 'calls')

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'BUSY\' '
    @total_calls_busy = get_system_stat(sql, 'calls')

    sql = 'SELECT COUNT(calls.id) as \'calls\' FROM calls WHERE calls.disposition = \'NO ANSWER\' '
    @total_calls_no_answ = get_system_stat(sql, 'calls')

    @total_failet = @total_calls - @total_calls_anws - @total_calls_busy - @total_calls_no_answ
  end

  # Prefix Finder ################################################################
  def prefix_finder
    redirect_to(action: 'search') && (return false)
  end

  def search
    @page_title, @page_icon = _('Dynamic_Search'), 'magnifier.png'

    if user?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(controller: :callc, action: :login) && (return false)
    end
  end

  def prefix_finder_find
    @phrase = params[:prefix].gsub(/[^\d]/, '') if params[:prefix]
    @dest = Destination.where(prefix: @phrase).
                        order('LENGTH(destinations.prefix) DESC').first if @phrase != ''
    @flag = nil

    if @dest.blank?
      @results = ''
    else
      @flag = @dest.direction_code
      direction = @dest.direction
      @dg = @dest.destinationgroup
      @results = @dest.name.to_s
      @results = direction.name.to_s + ' ' + @results if direction
      @flag2 = @dg.flag if @dg
      @results2 = "#{_('Destination_group')} : " + @dg.name.to_s if @dg
    end
    render(layout: false)
  end

  def prefix_finder_find_country
    @phrase = params[:prefix].gsub(/['"]/, '') if params[:prefix]
    @dirs = Direction.where(['SUBSTRING(name, 1, LENGTH(?)) = ?', @phrase, @phrase]) if @phrase && @phrase.length > 1
    render(layout: false)
  end

  def rate_finder_find
    # '123' => ['1', '12', '123']
    collided_prefix = collide_prefix(params[:prefix])

    # Check if Rates exists with given collided Prefix
    if Rate.where(prefix: collided_prefix).present?
      @rates = Stat.find_rates_and_tariffs_by_number(correct_owner_id, collided_prefix)
    end
    @error = @rates.last if @rates.try(:first).to_s == 'error'
    render(layout: false)
  end

  def ip_finder_find
    if params[:ip]
      ip = params[:ip].to_s.strip

      if ip.present?
        valid_ip_format = ip.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/) ? true : false

        if valid_ip_format
          user_id = manager? ? 0 : current_user.id
          @users_scope = ActiveRecord::Base.connection.select_values("SELECT id FROM users WHERE (owner_id = #{user_id} AND usertype != 'reseller') or id = #{user_id}")
          users_scope = @users_scope.collect(&:to_i).to_s.gsub('[', '(').gsub(']', ')')

          # searching devices
          conditions = "devices.ipaddr LIKE '#{ip}%' AND devices.user_id != -1"
          if current_user.show_only_assigned_users?
            conditions << " AND users.responsible_accountant_id = '#{current_user.id}'"
          end
          conditions += " AND devices.user_id IN #{users_scope}" if reseller?
          @devices = Device.joins('LEFT JOIN users ON devices.user_id = users.id').where(conditions).order('device_type, name').all
        end
      end
    end

    render(layout: false)
  end

  def hangup_cause_codes_stats
    @page_title = _('Hangup_cause_codes_stats')
    @page_icon = 'chart_pie.png'
    @dst_group = Destinationgroup.order(:name).all
    params_clear = params[:clear]

    @options = session[:hangup_cause_codes_stats_options] || {}
    adjust_m2_date
    change_date

    allowed_param_keys = %i[s_user s_user_id s_device dst_group_id order_by order_desc]
    params.select { |key, _| allowed_param_keys.member?(key.to_sym) }.each do |key, value|
      @options[key.to_sym] = value.to_s
    end

    @options[:order_desc] = 1 unless %w[0 1].include?(@options[:order_desc].to_s) # Default must be Descending

    if @options[:s_user].to_s == '' || params_clear
      @options[:s_user_id] = -1
      @options[:s_user] = ''
    elsif %w(-2 -1).include?(@options[:s_user_id].to_s)
      @options[:s_user_id] = -2
    end
    @options[:s_device] = -1 if @options[:s_device].to_s == 'all'

    if params_clear
      change_date_to_present
      @options = {}
      @user_id = @device_id = @dst_group_id = -1
    else
      @user_id = @options[:s_user_id] ? @options[:s_user_id].to_i : -1
      @device_id = @options[:s_device].to_s != '' ? @options[:s_device].to_i : -1
      @dst_group_id = @options[:dst_group_id] ? @options[:dst_group_id].to_i : -1
    end

    @options_from = "#{session[:year_from]}-#{good_date(session[:month_from].to_s)}-#{good_date(session[:day_from].to_s)} "\
      "#{good_date(session[:hour_from].to_s)}:#{good_date(session[:minute_from].to_s)}:00"
    @options_till = "#{session[:year_till]}-#{good_date(session[:month_till].to_s)}-#{good_date(session[:day_till].to_s)} "\
      "#{good_date(session[:hour_till].to_s)}:#{good_date(session[:minute_till].to_s)}:59"

    if @options[:s_user_id] && [-2, -1].exclude?(@options[:s_user_id].to_i)
      @user = User.where(id: @options[:s_user_id]).first
      unless @user
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    es_options = {
        user_id: @user_id, device_id: @device_id, dst_group_id: @dst_group_id,
        current_user: current_user, a1: es_limit_search_by_days, a2: es_session_till,
        order_by: @options[:order_by], order_desc: @options[:order_desc]
    }
    @calls, @calls_graph, @hangupcusecode_graph, @calls_size = EsHgcStats.get_data(es_options)

    session[:hangup_cause_codes_stats_options] = @options
  end

  def calls_per_day
    @page_title = _('Calls_per_day')
    @page_icon = 'chart_bar.png'
    @searching = params[:search_on].to_i == 1

    cond = ''
    des = ''
    des2 = ''
    des3 = ''
    @coun = -1
    @user_id = -1
    @directions = -1

    up, rp, pp = current_user.get_price_calculation_sqls
    if params[:country_id]
      @country_id = params[:country_id]
    end

    if params[:s_user_id]
      # -1 find all users, -2 find nothing
      if params[:s_user].to_s == ''
        params[:s_user_id] = -1
      elsif %w[-2 -1].include?(params[:s_user_id].to_s)
        params[:s_user_id] = -2
      end

      if params[:s_user_id].to_i != -1
        @user = User.where(id: params[:s_user_id]).first
        cond += " calls.user_id = '#{@user.try(:id) || -2}' AND "
        @user_id = @user.try(:id) || -2
      end
    end

    # if params[:reseller_id]
    #   if params[:reseller_id].to_i != -1
    #     @reseller = User.where(id: params[:reseller_id]).first
    #     cond += " calls.reseller_id = '#{@reseller.id}' AND "
    #     @reseller_id = @reseller.id
    #   end
    # end
    @resellers = User.where(usertype: 'reseller').order('first_name ASC').all

    @direction = params[:direction] if params[:direction] && params[:direction].to_i != -1

    owner_id = correct_owner_id

    #cond += " reseller_id ='#{owner_id}' AND " if owner_id != 0

    if @country_id
      if @country_id.to_i != -1
        @country = Direction.where(id: @country_id).first
        @coun = @country.id
        des3 += 'destinations JOIN'
        des2 += 'ON (calls.prefix = destinations.prefix)'
        des +=" AND destinations.direction_code ='#{@country.code}' "
      end
    end
    @countries = Direction.order('name ASC').all

    change_date

    calldate = "(calls.calldate + INTERVAL #{current_user.time_offset} SECOND)"

    session[:hour_from] = '00'
    session[:minute_from] = '00'
    session[:hour_till] = '23'
    session[:minute_till] = '59'

    if @searching
      sql = "SELECT EXTRACT(YEAR FROM #{calldate}) as year, EXTRACT(MONTH FROM #{calldate}) as month, EXTRACT(day FROM #{calldate}) as day, Count(calls.id) as 'calls' , SUM(IF(calls.billsec > 0, calls.billsec, IF(calls.real_billsec > 1, CEIL(calls.real_billsec), NULL) )) as 'duration', SUM(#{up}) as 'user_price', SUM(#{pp}) as 'provider_price', SUM(IF(disposition!='ANSWERED',1,0)) as 'fail'  FROM
      #{des3} calls #{des2}
      WHERE #{cond} calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{des}
      GROUP BY year, month, day"
      @res = ActiveRecord::Base.connection.select_all(sql)

      sql_total = "SELECT  Count(calls.id) as 'calls' , SUM(IF(calls.billsec > 0, calls.billsec, IF(calls.real_billsec > 1, CEIL(calls.real_billsec), NULL) )) as 'duration', SUM(#{up}) as 'user_price', SUM(#{pp}) as 'provider_price', SUM(IF(disposition!='ANSWERED',1,0)) as 'fail'  FROM
      #{des3} calls #{des2}
      WHERE #{cond} calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}' #{des}"
      @res_total = ActiveRecord::Base.connection.select_all(sql_total)
    end
  end

  def first_activity
    @page_title = _('First_activity')
    @page_icon = 'chart_bar.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/First_Activity'

    change_date

    @size = Action.set_first_call_for_user(session_from_date, session_till_date)

    @total_pages = (@size.to_d / session[:items_per_page].to_d).ceil

    @page = 1
    @page = params[:page].to_i if params[:page]
    @page = @total_pages.to_i if params[:page].to_i > @total_pages && @total_pages.to_i > 0
    @page = 1 if params[:page].to_i < 1

    @fpage = ((@page - 1) * session[:items_per_page]).to_i

    sql3 = "SELECT actions.date as 'calldate', actions.data2 as 'card_id', users.first_name, users.last_name, users.username, users.id, actions.user_id FROM users
                  JOIN actions ON  (actions.user_id = users.id)
           WHERE actions.action = 'first_call' and actions.date BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'
           GROUP BY user_id
           ORDER BY date ASC
           LIMIT #{@fpage}, #{session[:items_per_page].to_i}"
    @res = ActiveRecord::Base.connection.select_all(sql3)

    #    @all_res = @res
    #    @res = []
    #
    #    iend = ((session[:items_per_page] * @page) - 1)
    #    iend = @all_res.size - 1 if iend > (@all_res.size - 1)
    #    for i in ((@page - 1) * session[:items_per_page])..iend
    #      @res << @all_res[i]
    #    end
    #
  end

  def action_log
    @page_title = _('Action_log')
    @page_icon = 'chart_bar.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Action_log'
    @searching = params[:search_on].to_i == 1
    @reviewed_labels = [[_('All'), -1], [_('Reviewed').downcase, 1], [_('Not_reviewed').downcase, 0]]

    if user?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    # When redirected from Integrity Check
    if params[:s_int_ch].to_i == 1
      first_action_date = Action.where(action: 'error', processed: 0).order(:date).first.try(:date)
      time_now = Time.now

      if first_action_date && first_action_date.is_a?(Time)
        params[:date_from] = {
            year: first_action_date.year,
            month: first_action_date.month,
            day: first_action_date.day,
            hour: first_action_date.hour,
            minute: first_action_date.min
        }
        params[:date_till] = {year: time_now.year, month: time_now.month, day: time_now.day, hour: 23, minute: 59}
      end
    end

    change_date

    a1 = session_from_datetime
    a2 = session_till_datetime

    @options = session[:action_log_stats_options] || {order_by: 'action', order_desc: 0, page: 1}
    # search paramaters
    clean_param = params[:clean]
    params_page = params[:page]
    params_page ? @options[:page] = params_page.to_i : (clean_param) ? @options[:page] = 1 : (@options[:page] = 1 unless @options[:page])
    params_action_type = params[:action_type]
    params_action_type ? @options[:s_type] = params_action_type.to_s : clean_param ? @options[:s_type] = 'all' : (@options[:s_type]) ? @options[:s_type] = session[:action_log_stats_options][:s_type] : @options[:s_type] = 'all'

    # -1 find all users; -2 find nothing
    if params[:s_user_id].present? && params[:s_user].present?
      @options[:s_user] = params[:s_user_id].to_s
      @options[:s_user_name] = params[:s_user]
    end
    if clean_param || params[:s_user_id].to_i == -2
      @options[:s_user] = -1
      @options[:s_user_name] = ''
    end

    params_processed = params[:processed]
    params_processed ? @options[:s_processed] = params_processed.to_s : (clean_param) ? @options[:s_processed] = -1 : (@options[:s_processed]) ? @options[:s_processed] = session[:action_log_stats_options][:s_processed] : @options[:s_processed] = -1
    # params[:s_int_ch]   ? @options[:s_int_ch] = params[:s_int_ch].to_i     : (params[:clean]) ? @options[:s_int_ch] = 0   : (@options[:s_int_ch])? @options[:s_int_ch] = session[:action_log_stats_options][:s_int_ch] : @options[:s_int_ch] = 0
    params[:target_type] ? @options[:s_target_type] = params[:target_type].to_s : (clean_param) ? @options[:s_target_type] = '' : (@options[:s_target_type]) ? @options[:s_target_type] = session[:action_log_stats_options][:s_target_type] : @options[:s_target_type] = ''
    params[:target_id] ? @options[:s_target_id] = params[:target_id].to_s : (clean_param) ? @options[:s_target_id] = '' : (@options[:s_target_id]) ? @options[:s_target_id] = session[:action_log_stats_options][:s_target_id] : @options[:s_target_id] = ''

    change_date_to_present if clean_param

    current_user_time = current_user.user_time(Time.now)

    year = current_user_time.year.to_s
    month = current_user_time.month.to_s
    day = current_user_time.day.to_s

    from = session_from_datetime_array != [year, month, day, '0', '0', '00']
    till = session_till_datetime_array != [year, month, day, '23', '59', '59']

    @options[:search_on] = (from || till) ? 1 : 0

    # order
    params_order_by = params[:order_by]
    params_order_desc = params[:order_desc]
    params_order_desc ? @options[:order_desc] = params_order_desc.to_i : (@options[:order_desc] = 1 if !@options[:order_desc])
    params_order_by ? @options[:order_by] = params_order_by.to_s : @options[:order_by] == 'acc'
    order_by = Action.actions_order_by(@options)

    @res = Action.select('DISTINCT(actions.action)').order('actions.action').all

    if @searching
      cond, cond_arr, join = Action.condition_for_action_log_list(current_user, a1, a2, params[:s_int_ch], @options)
      # page params
      @ac_size = Action.select('actions.id').where([cond.join(' AND ')] + cond_arr).joins(join).size
      @not_reviewed_actions = Action.where([(['processed = 0'] + cond).join(' AND ')] + cond_arr).joins(join).limit(1).size.to_i == 1

      fpage, @total_pages, _options = Application.pages_validator(session, @options, @ac_size)
      @search = 1
      # search
      @actions = Action.select(" actions.*, #{SqlExport.nice_user_sql}")
                       .where([cond.join(' AND ')] + cond_arr)
                       .joins(join)
                       .order(order_by)
                       .limit("#{fpage}, #{session[:items_per_page].to_i}")
    end
    @permissions = action_log_permissions if manager?
    session[:action_log_stats_options] = @options
  end

  def action_log_mark_reviewed
    a1 = session_from_datetime
    a2 = session_till_datetime
    session[:action_log_stats_options] ? @options = session[:action_log_stats_options] : @options = {order_by: 'action', order_desc: 0, page: 1}
    cond, cond_arr, join = Action.condition_for_action_log_list(current_user, a1, a2, 0, @options)
    @actions = Action.select(' actions.*')
                     .where([cond.join(' AND ')] + cond_arr)
                     .joins(join)

    if @actions
      @actions.each do |action|
        if action.processed == 0
          action.processed = 1
          action.save
        end
      end
    end
    flash[:status] = _('Actions_marked_as_reviewed')
    redirect_to action: :action_log, search_on: 1
  end

  def action_processed
    action = Action.find(params[:id])
    if User.check_responsability(action.user_id) || [current_user.id, -1].include?(action.user_id)
      action.toggle_processed
      flash[:status] = _('Action_marked_as_reviewed')
    end
    @user = params[:user].to_s
    @action = params[:s_action]
    @processed = params[:procc]
    redirect_to action: 'action_log', user_id: @user, processed: @processed, action_type: @action, search_on: 1
  end

  def load_stats
    adjust_m2_date
    change_date_from
    @servers = Server.select(:id, 'CONCAT("ID: ", id, ", IP: ", server_ip, " (", comment, ")") AS nice_description').where(server_type: 'freeswitch')
    @default = {s_user: -1, s_device: -1, s_server: -1}
    @options = (session[:stats_load_stats_options] || @default)
    # -1 find all users, -2 find nothing
    if params[:s_user].to_s == ''
      params[:s_user_id] = -1
    elsif %w[-2 -1].include?(params[:s_user_id].to_s)
      params[:s_user_id] = -2
    end
    s_device = params[:s_device].presence || -1
    @options[:s_user] = params[:s_user_id].presence
    @options[:s_device] = s_device.to_s == 'all' ? -1 : s_device
    @devices = Device.where(user_id: params[:s_user_id]).all if params[:s_user_id].to_i >= 0
    @options[:s_server] = params[:s_server].presence || -1
    if params[:clear]
      change_date_to_present
      @options[:s_user] = @options[:s_device] = @options[:s_server] = -1
      params[:s_user] = nil
    end
    session[:year_till], session[:month_till], session[:day_till] =
    session[:year_from], session[:month_from], session[:day_from]
    session[:hour_from], session[:minute_from], session[:hour_till], session[:minute_till] = '00', '00', '23', '59'
    @options_date = "#{session[:year_from]}-#{good_date(session[:month_from].to_s)}-#{good_date(session[:day_from].to_s)} "\
    "#{good_date(session[:hour_from].to_s)}:#{good_date(session[:minute_from].to_s)}:00"

    @options[:a1], @options[:a2], @options[:current_user] = limit_search_by_days, session_till_datetime, current_user

    @all_calls, answered_calls, highest_duration = Call.calls_for_load_stats(@options)

    all_calls_grouped, answered_calls_grouped, @calls_graph = {}, Array.new(1440, 0), []

    @all_calls.each { |time_interval| all_calls_grouped[time_interval['call_minute']] = time_interval['calls'] }

    answered_calls.each do |call|
      (call['time_index_from']..(call['time_index_from'] + call['minute_duration'])).each do |time_interval|
        break if time_interval >= 1440
        answered_calls_grouped[time_interval] += call['calls_count']
      end
    end
    time = Time.now.midnight
    # Prepare array for graph data, interval - 60 seconds
    graph_array = []
      (24 * 60).times do
        hour = time.strftime('%k').to_i
        minute = time.strftime('%M').to_i
        time_interval = "#{sprintf('%02d', hour)}:#{sprintf('%02d', minute)}"
        @calls_graph.push [[hour, minute, 0], answered_calls_grouped[hour * 60 + minute], all_calls_grouped[time_interval] || 0]
        time += 60.seconds
      end

    flash[:notice] = _('db_error_broken_call_duration') if highest_duration.to_i > 36000
  end

  def truncate_active_calls
    if admin?
      Activecall.delete_all
      redirect_to(controller: 'stats', action: 'active_calls') && (return false)
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def hangup_refined_active_calls
    if admin?
      active_calls_show
      Activecall.hangup_calls(@active_calls)
      redirect_to(controller: :stats, action: :active_calls) && (return false)
    else
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def server_load
    @stats = @server.load_stats(@options[:date_from])
  end

  def update_server_load
    return unless request.xhr?
    render json: {data: server_load}
  end

  def set_minutes_from_calldate(call_calldate)
    calldate = current_user.user_time(call_calldate).to_time
    (calldate.strftime('%H').to_i * 60) + calldate.strftime('%M').to_i
  end

  def calls_dashboard
    @data = EsCallsDashboard::stats(current_user).to_json
    render json: @data if request.xhr?
  end

  def archived_calls_resync
    access_denied unless admin?

    if aurora_active? && AWS::Aurora.sync(force: true)
      flash[:status] = _('Archived_Calls_sync_success')
    else
      flash[:notice] = _('Archived_Calls_sync_failed')
    end

    redirect_to(action: :old_calls_stats) && return
  end

  def check_radius_status
    @server.radius_status_check(true)
    session[:radius_con_failed] = @server.radius_status == 2
    flash[:status] = _('Radius_connection_successful') if @server.radius_status == 0
    redirect_to(action: :server_load, id: @server.id) && (return false)
  end

  def check_es_status
    Server.elasticsearch_status_check(true)
    session[:es_con_failed] = Confline.get_value('ES_Status').to_i == 2
    flash[:status] = _('Elasticsearch_connection_successful') if Confline.get_value('ES_Status').to_i == 0
    redirect_to(action: :server_load, id: @server.id) && (return false)
  end

  def debug_log
    log = `tail -40 #{Debug_File}`
    session[:radius_con_failed] = false
    session[:es_con_failed] = false
    render plain: log
  end

  private

  def archived_calls_table_resync
    access_denied unless admin?

    if aurora_active? && AWS::Aurora.sync_tables
      flash[:status] = _('Archived_Calls_sync_success')
    end
  end

  def aurora_active?
    (@aurora_active ||= AWS::ArchivedCall.active?) == 1
  end

  def get_system_stat(sql, type)
    res = ActiveRecord::Base.connection.select_all(sql)
    res[0][type].to_i
  end

  def server_load_options
    adjust_m2_date
    change_date_from
    change_date_to_present if params[:clear]

    @options =
      {
        date_from: "#{session[:year_from]}-#{good_date(session[:month_from])}-#{good_date(session[:day_from])}",
        sep: Confline.get('Global_Number_Decimal').try(:value) || '.',
        pre: Confline.get_value('Nice_Number_Digits').to_i
      }
  end

  def server_load_find_server
    @server = Server.find_by(id: params[:id])
    return if @server

    flash[:notice] = _('Server_not_found')
    redirect_to(:root) && (return false)
  end

  def call_list_additional_columns
    column_options = {}
    column_options[:show_answer_time] = Call.column_exists?(:answer_time) && Confline.get_value('Show_answer_time_last_calls', 0).to_i == 1
    column_options[:show_end_time] = Call.column_exists?(:end_time) && Confline.get_value('Show_end_time_last_calls', 0).to_i == 1
    column_options[:show_terminated_by] = Call.column_exists?(:terminated_by) && Confline.get_value('Show_terminated_by_last_calls', 0).to_i == 1
    column_options[:show_pdd] = Call.column_exists?(:pdd) && Confline.get_value('Show_pdd_last_calls', 0).to_i == 1
    column_options[:show_duration] = Call.column_exists?(:duration) && Confline.get_value('Show_Duration_in_Last_Calls', 0).to_i == 1
    column_options
  end

  # This needs to be extended in the future
  def action_log_permissions
    {
      manage_tariffs: authorize_manager_permissions(
        controller: :tariffs, action: :rate_details, no_redirect_return: 1
      )
    }
  end

  def calls_dashboard_options
    return if request.xhr?
    @options = Confline.calls_dashboard_config
  end

  def backup_path
    path = Confline.get_value('Backup_Folder')
  end

  def get_archived_calls
    @files = `ls -t -1 #{backup_path} | grep -P "m2_archived_calls_from_\\d{4}\\w{3}\\d{2}-\\d{6}_to_\\d{4}\\w{3}\\d{2}-\\d{6}.tgz"`.split("\n")
  end

  def no_cache
    response.headers['Last-Modified'] = Time.now.httpdate
    response.headers['Expires'] = '0'
    # HTTP 1.0
    response.headers['Pragma'] = 'no-cache'
    # HTTP 1.1 'pre-check=0, post-check=0' (IE specific)
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0, pre-check=0, post-check=0'
  end

  def check_authentication
    if current_user.blank? || (user? && Confline.get_value('Show_Active_Calls_for_Users').to_i == 0)
      (redirect_to :root) && dont_be_so_smart && (return false)
    end
  end

  def find_user_from_id_or_session
    params[:id] ? user_id = params[:id] : user_id = session[:user_id]
    @user = User.where(['id = ?', user_id]).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      (redirect_to :root) && (return false)
    end

    if session[:usertype] == 'reseller'
      if @user.id != session[:user_id] && @user.owner_id != session[:user_id]
        dont_be_so_smart
        (redirect_to :root) && (return false)
      end
    end

    if session[:usertype] == 'user' && @user.id != session[:user_id]
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end
  end

  def last_calls_stats_parse_params(old = false, hide_non_answered_calls_for_user = false)
    default = {
        items_per_page: session[:items_per_page].to_i,
        page: '1',
        s_direction: 'outgoing',
        s_call_type: 'all',
        s_origination_point: 'all',
        s_termination_point: 'all',
        s_hgc: 0,
        search_on: 0,
        s_user: '',
        s_user_id: '-2',
        s_user_terminator: '',
        s_user_terminator_id: '-2',
        user: nil,
        s_destination: '',
        order_by: 'time',
        order_desc: 1,
        s_country: '',
        s_reseller: 'all',
        s_source: nil,
        show_device_and_cid: 0,
        use_cloud: aurora_active?,
        s_billsec: '',
        s_duration: '',
        s_server: '',
        s_uniqueid: ''
    }

    clear = params[:clear]
    if clear
      options = default
      change_date_to_present
    else
      options = session[:calls_list] || default
      params_s_device = params[:s_device]
      params_s_tp_device = params[:s_tp_device]
      options[:items_per_page] = session[:items_per_page] if session[:items_per_page].to_i > 0
      default.each { |key, value| options[key] = params[key] if params[key] }
      options[:direction] = options[:s_direction]
      options[:call_type] = hide_non_answered_calls_for_user ? 'answered' : options[:s_call_type]
      options[:destination] = options[:s_destination].to_s
      options[:source] = options[:s_source] if options[:s_source]
      options[:s_origination_point] = params_s_device if params_s_device
      options[:s_termination_point] = params_s_tp_device if params_s_tp_device
      options[:uniqueid] = options[:s_uniqueid].to_s

      if params[:s_user_id]
        options[:s_user_id] = ((params[:s_user_id] == '-2') && params[:s_user].present?) ? '' : params[:s_user_id]
      end

      if params[:s_user_terminator_id]
        options[:s_user_terminator_id] = ((params[:s_user_terminator_id] == '-2') && params[:s_user_terminator].present?) ? '' : params[:s_user_terminator_id]
      end
    end

    # Params that are not related to the actual search form
    options[:from] = old ? session_from_datetime : limit_search_by_days
    options[:till] = session_till_datetime
    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency]).to_d
    options[:exchange_rate] = exchange_rate
    options[:show_device_and_cid] = params[:action].to_s == 'calls_list' ? Confline.get_value('Show_device_and_cid_in_last_calls', correct_owner_id) : 0

    if options[:order_by] == 'termination_name' && (params[:pdf].to_i == 1 || params[:csv].to_i == 1) # nice_device available only in html version
      options[:order_by] = default[:order_by]
      options[:order_desc] = default[:order_desc]
    end
    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? ' DESC' : ' ASC')
    options[:order] = old ? OldCall.calls_order_by(params, options) : Call.calls_order_by(params, options)

    search_in = params[:search_in]
    options[:use_cloud] = search_in.blank? ? options[:use_cloud] : aurora_active? && search_in == 'cloud'

    options
  end

  def last_calls_stats_user(user, options)
    devices = user.devices.origination_points
    tpoints = user.devices.termination_points
    device = Device.origination_points.where(id: options[:s_origination_point]).first if options[:s_origination_point] != 'all' && options[:s_origination_point].present?
    tp = tpoints.find_by(id: options[:s_termination_point]) if options[:s_termination_point] != 'all' && options[:s_termination_point].present?
    [devices, device, tpoints, tp]
  end

  def last_calls_stats_reseller(options)
    s_user = options[:s_user]
    user = User.where(id: s_user).first if s_user != 'all' && s_user.present?

    s_device = options[:s_device]
    device = Device.where(id: s_device).first if s_device != 'all' && s_device.present?

    if user
      devices = user.devices
    else
      devices = Device.find_all_for_select(corrected_user_id)
    end
    users = User.select("id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}").where("users.usertype = 'user' AND users.owner_id = #{corrected_user_id} AND hidden=0").order("nice_user")
    if Confline.get_value('Show_HGC_for_Resellers').to_i == 1
      hgcs = Hangupcausecode.find_all_for_select
      s_hgc = options[:s_hgc]
      hgc = Hangupcausecode.where(id: s_hgc).first if s_hgc.to_i > 0
    end

    providers = nil
    provider = nil

    return users, user, devices, device, hgcs, hgc, providers, provider
  end

  def last_calls_stats_admin(options)
    user = User.where(id: options[:s_user_id]).first if options[:s_user_id].present? && (options[:s_user_id] != '-2')
    tp_user = User.where(id: options[:s_user_terminator_id]).first if options[:s_user_terminator_id].present? && (options[:s_user_terminator_id] != '-2')
    hgc = Hangupcausecode.where(id: options[:s_hgc]).first if options[:s_hgc].to_i > 0
    hgcs = Hangupcausecode.find_all_for_select
    termination_point = Device.where(id: options[:s_termination_point]).first if options[:s_termination_point] != 'all' && !options[:s_termination_point].blank?


    if user
      origination_point = Device.where(id: options[:s_origination_point]).first if options[:s_origination_point] != 'all' && !options[:s_origination_point].blank?
      origination_points = user.devices.origination_points_sort_nice_device
    else
      origination_point, origination_points = [[], []]
    end

    if tp_user
      termination_points = tp_user.devices.termination_points_sort_nice_device
    else
      termination_points = Device.termination_points_with_user
    end
    return user, tp_user, origination_points, origination_point, hgcs, hgc, termination_points, termination_point
  end

  def last_calls_stats_set_variables(options, values)
    options.merge(values.reject { |key, value| !value })
  end

  def get_price_exchange(price, cur)
    exrate = Currency.count_exchange_rate(cur, current_user.currency.name)
    rate_cur = Currency.count_exchange_prices({exrate: exrate, prices: [price.to_d]})
    return rate_cur.to_d
  end

  def no_users
    if user?
      dont_be_so_smart && (redirect_to :root)
    end
  end

  def show_user_stats_clear_search(params)
    current_time_from = {year: Time.current.year.to_s, month: Time.current.month.to_s, day: Time.current.day.to_s, hour: '00', minute: '00'}
    current_time_till = {year: Time.current.year.to_s, month: Time.current.month.to_s, day: Time.current.day.to_s, hour: '23', minute: '59'}
    params[:date_from] = current_time_from
    params[:date_till] = current_time_till

    return params
  end

  def show_user_stats_check_searching_params(time_from, time_till)
    time_now_from = Time.current.strftime('%Y-%m-%d 00:00')
    time_now_till = Time.current.strftime('%Y-%m-%d 23:59')
    time_from = Time.parse(time_from).strftime('%Y-%m-%d %H:%M')
    time_till = Time.parse(time_till).strftime('%Y-%m-%d %H:%M')

    (time_now_from != time_from) || (time_now_till != time_till)
  end

  def country_stats_parse_params
    @options = session[:country_stats] || {}

    s_user_id = params[:s_user_id] || session[:country_stats][:user_id]
    s_user = params[:s_user] || session[:country_stats][:user]
    clear = params[:clear]

    if s_user_id.blank? || %w(-2 -1 0).include?(s_user_id.to_s)
      s_user_id = -1
      s_user = ''
    end

    if clear
      s_user_id = -1
      s_user = ''
      change_date_to_present
    end

    if params[:search_pressed] || @options[:start].blank? || clear
      @options[:start] = Time.parse(session_from_datetime)
      @options[:end] = Time.parse(session_till_datetime)
      s_user_id = s_user_id.to_i if s_user_id.present? && !clear
      s_user = s_user if s_user_id.present? && !clear
    end

    @options[:from] = "#{session[:year_from]}-#{good_date(session[:month_from].to_s)}-#{good_date(session[:day_from].to_s)} "\
      "#{good_date(session[:hour_from].to_s)}:#{good_date(session[:minute_from].to_s)}:00"
    @options[:till] = "#{session[:year_till]}-#{good_date(session[:month_till].to_s)}-#{good_date(session[:day_till].to_s)} "\
      "#{good_date(session[:hour_till].to_s)}:#{good_date(session[:minute_till].to_s)}:59"

    change_date_to_present if clear
    @options[:user_id] = s_user_id
    @options[:user] = s_user
  end

  def is_devices_for_sope_present
    devices_for_sope = Device.find_all_for_select(corrected_user_id, {count: true})
    @devices_for_sope_present = devices_for_sope[0].count_all.to_i > 0
  end

  def user_stats_options
    params[:time_from] = '00:00'
    params[:time_till] = '23:59'
    p_uid = params[:s_user_id].to_i
    adjust_m2_date

    user_id = if params[:clear]
                change_date_to_present
                nil
              else
                change_date
                p_uid > 0 || p_uid == -1 ? p_uid : session[:user_stats_uid]
              end
    session[:user_stats_uid] = user_id


    {
      from: "#{session[:year_from]}-#{good_date(session[:month_from])}-#{good_date(session[:day_from])} 00:00:00",
      till: "#{session[:year_till]}-#{good_date(session[:month_till])}-#{good_date(session[:day_till])} 23:59:59",
      user_id: user_id.to_i, user: Stat.manager_users(user_id),
      time_format: Confline.get('time_format').try(:value) || '%M:%S',
      current_user: current_user
    }
  end

  def get_action_calls_data(options = {})
    @data = Device.active_calls_distribution(current_user, options).to_json except: [:extension, :description, :device_type]
    @refresh_period = session[:active_calls_refresh_interval].to_i
    respond_to do |format|
      format.html
      format.json { render json: @data }
    end
  end
end
