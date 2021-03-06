# Balance Report is a list of aggregated data about user's calls
# -*- encoding : utf-8 -*-
class BalanceReportsController < ApplicationController
  include ApplicationHelper

  before_filter :authorize
  before_filter :authorize_assigned_users, only: %w[user_statement_report], if: -> { current_user.try(:show_only_assigned_users?) }
  before_filter :access_denied, if: -> { user? }
  layout :determine_layout

  before_filter :check_localization

  def list
    @page_title = _('balance_report')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
    @show_currency_selector = true
    clear_search(params) if params[:clear].to_i == 1
    @options = initialize_options(params)
    @searching = params[:search_on].to_i == 1
    params_date_from = params[:date_from]
    params_date_till = params[:date_till]
    params_time_zone = @options[:s_time_zone]
    show_hidden_users = (@options[:show_hidden_users] == 1) ? '' : 'users.hidden = 0'

    if params_date_from
      make_params_time_from = Time.mktime(params_date_from[:year], params_date_from[:month]).beginning_of_month
      make_params_time_till = Time.mktime(params_date_till[:year], params_date_till[:month]).end_of_month

      params_date_from[:day] = make_params_time_from.day
      params_date_from[:hour] = make_params_time_from.hour
      params_date_from[:minute] = make_params_time_from.min

      params_date_till[:day] = make_params_time_till.day
      params_date_till[:hour] = make_params_time_till.hour
      params_date_till[:minute] = make_params_time_till.min
    end
    change_date

    session_parsed_time_from = Time.parse(session_from_datetime)
                                   .in_time_zone(params_time_zone)
                                   .strftime('%Y-%m-%d %H:%M:%S')

    session_parsed_time_till = Time.parse(session_till_datetime)
                                   .in_time_zone(params_time_zone)
                                   .strftime('%Y-%m-%d %H:%M:%S')

    @clear_search =
      check_searching_params(params, session_from_datetime, session_till_datetime, params_time_zone, show_hidden_users)
    if session_parsed_time_from > session_parsed_time_till
      @balance_report_users_all = []
    else
      @balance_report_users_all = balance_report_data(session_parsed_time_from, session_parsed_time_till,
                                                      params_time_zone, show_hidden_users).
          sort_by! { |key| key[@options[:order_by].to_sym] }

      @balance_report_users_all.reverse! unless @options[:order_desc].to_i.zero?
    end

    items_per_page = session[:items_per_page]
    balance_report_users_all_size = @balance_report_users_all.size
    @total_pages = (balance_report_users_all_size.to_d / items_per_page.to_d).ceil

    fpage, @total_pages, @options = Application.pages_validator(session, @options, balance_report_users_all_size)

    balance_report_total_amounts(@balance_report_users_all)

    @balance_report_users_all = @balance_report_users_all[fpage...(items_per_page.to_i + fpage)]

    session[:balance_report_options] = @options
  end

  def user_statement_report
    @page_title = _('user_statement_report')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
    @show_currency_selector = true
    @options = initialize_options(params)
    user_id = params[:id].to_i
    params_time_zone = @options[:s_time_zone]

    session_parsed_time_from = Time.parse(session_from_datetime)
                                   .in_time_zone(params_time_zone)
                                   .strftime('%Y-%m-%d %H:%M:%S')

    session_parsed_time_till = Time.parse(session_till_datetime)
                                   .in_time_zone(params_time_zone)
                                   .strftime('%Y-%m-%d %H:%M:%S')

    @user_statement_report = user_statement_report_data(session_parsed_time_from, session_parsed_time_till, user_id)

    user_statement_report_total_amounts(@user_statement_report)
  end

  private

  def balance_report_data(start_time, end_time, params_time_zone, show_hidden_users)
    time_period = "BETWEEN '#{start_time}' AND '#{end_time}'"
    select_user = 'users.id AS user_id'
    default_values = ['-2', nil, '', _('All').downcase]
    user_id = default_values.include?(@options[:s_user_id]) ? '' : " AND users.id = '#{@options[:s_user_id].to_i}'"
    assigned_users = if current_user.show_only_assigned_users?
                       "users.responsible_accountant_id = #{current_user.id}"
                     else
                       ''
                     end

    group_by = 'users.id'
    used_users, users = Array.new(2) { [] }

    es_start_time = Time.parse(session_from_datetime).in_time_zone(params_time_zone).to_s.split(' ')[0..1].join('T')
    es_end_time = Time.parse(session_till_datetime).in_time_zone(params_time_zone).to_s.split(' ')[0..1].join('T')

    traffic_to_us = EsBalanceReports.get_data_traffic_to_us(
        from: es_start_time, till: es_end_time, show_hidden_users: show_hidden_users, user_id: user_id,
        assigned_users: assigned_users
    )
    find_used_users(traffic_to_us, used_users)

    traffic_from_us = EsBalanceReports.get_data_traffic_from_us(
        from: es_start_time, till: es_end_time, show_hidden_users: show_hidden_users.present?, user_id: user_id,
        assigned_users: assigned_users
    )
    find_used_users(traffic_from_us, used_users)

    we_invoiced = M2Invoice.select(select_user.to_s)
                           .select("SUM(m2_invoices.total_amount_with_taxes * IF((m2_invoices.currency = '#{session[:show_currency]}'), m2_invoices.currency_exchange_rate, #{@options[:exchange_rate].to_d})) AS we_invoiced")
                           .joins('LEFT JOIN users ON users.id = m2_invoices.user_id')
                           .where("m2_invoices.issue_date #{time_period}#{user_id}")
                           .where('users.usertype != ?', 'manager')
                           .where(show_hidden_users)
                           .where(assigned_users)
                           .group("#{group_by}")
    find_used_users(we_invoiced, used_users)

    paid_to_us = M2Payment.select(select_user.to_s)
                          .select('SUM(m2_payments.amount_with_tax) AS paid_to_us')
                          .joins('LEFT JOIN users ON users.id = m2_payments.user_id')
                          .where("m2_payments.amount_with_tax >= 0 AND (m2_payments.date #{time_period})#{user_id}")
                          .where('users.usertype != ?', 'manager')
                          .where(show_hidden_users)
                          .where(assigned_users)
                          .group(group_by.to_s)
    find_used_users(paid_to_us, used_users)

    we_paid = M2Payment.select(select_user.to_s)
                       .select('SUM(m2_payments.amount_with_tax) AS we_paid')
                       .joins('LEFT JOIN users ON users.id = m2_payments.user_id')
                       .where("m2_payments.amount_with_tax < 0 AND (m2_payments.date #{time_period})#{user_id}")
                       .where('users.usertype != ?', 'manager')
                       .where(show_hidden_users)
                       .where(assigned_users)
                       .group(group_by.to_s)
    find_used_users(we_paid, used_users)

    used_users.each do |user_id|
      user_traffic_to_us = traffic_to_us.find { |id| id[:user_id] == user_id }.try(:[], :traffic_to_us).to_d
      user_traffic_from_us = traffic_from_us.find { |id| id[:user_id] == user_id }.try(:[], :traffic_from_us).to_d
      user_we_invoiced = we_invoiced.find { |id| id[:user_id] == user_id }.try(:we_invoiced).to_d
      user_paid_to_us = paid_to_us.find { |id| id[:user_id] == user_id }.try(:paid_to_us).to_d
      user_we_paid = we_paid.find { |id| id[:user_id] == user_id }.try(:we_paid).to_d
      user_debt = user_traffic_to_us - user_paid_to_us
      user_our_debt = user_traffic_from_us + user_we_paid
      user_balance = user_our_debt - user_debt

      user_hash = {
        user_id: user_id,
        traffic_to_us: user_traffic_to_us,
        we_invoiced: user_we_invoiced,
        paid_to_us: user_paid_to_us,
        debt: user_debt,
        traffic_from_us: user_traffic_from_us,
        invoiced_to_us: 0,
        we_paid: (user_we_paid < 0 ? user_we_paid * (-1) : user_we_paid),
        our_debt: user_our_debt,
        balance: user_balance,
        nice_user: nice_user_by_id(user_id)
      }
      users << user_hash
    end
    users
  end

  def find_used_users(data, used_users)
    data.each { |value| used_users << value[:user_id] unless used_users.include?(value[:user_id]) }
  end

  def user_statement_report_data(start_time, end_time, user_id)
    time_period = "BETWEEN '#{start_time}' AND '#{end_time}'"
    select_user = 'users.id AS user_id'
    where_user = "users.id = #{user_id}"
    good_users_data = []

    we_invoiced = M2Invoice.select('m2_invoices.issue_date AS date')
                           .select(select_user.to_s)
                           .select('SUM(m2_invoices.total_amount_with_taxes) AS we_invoiced')
                           .select('m2_invoices.comment AS comment')
                           .joins('LEFT JOIN users ON users.id = m2_invoices.user_id')
                           .where("m2_invoices.issue_date #{time_period} AND #{where_user}")
                           .group('m2_invoices.issue_date')

    paid_to_us = M2Payment.select('m2_payments.date AS date')
                          .select(select_user.to_s)
                          .select('SUM(m2_payments.amount_with_tax) AS paid_to_us')
                          .select('m2_payments.comment AS comment')
                          .joins('LEFT JOIN users ON users.id = m2_payments.user_id')
                          .where("m2_payments.amount_with_tax >= 0 AND (m2_payments.date #{time_period}) AND #{where_user}")
                          .group('m2_payments.date')

    we_paid = M2Payment.select('m2_payments.date AS date')
                       .select(select_user.to_s)
                       .select('SUM(m2_payments.amount_with_tax) AS we_paid')
                       .select('m2_payments.comment AS comment')
                       .joins('LEFT JOIN users ON users.id = m2_payments.user_id')
                       .where("m2_payments.amount_with_tax < 0 AND (m2_payments.date #{time_period}) AND #{where_user}")
                       .group('m2_payments.date')

    users_data = we_invoiced + paid_to_us + we_paid
    users_data.sort_by! { |key| key[:date] }

    users_data.each do |data|
      users_date = data[:date].strftime('%Y-%m-%d')
      users_we_invoiced = data.try(:we_invoiced).to_d
      users_paid_to_us = data.try(:paid_to_us).to_d
      users_invoiced_to_us = 0
      users_we_paid = data.try(:we_paid).to_d
      users_comment = data.try(:comment).to_s
      users_balance = (users_we_invoiced - users_paid_to_us + users_invoiced_to_us - users_we_paid)
      users_balance *= (-1) if users_balance != 0

      users_data_hash = {
        user_id: user_id.to_i,
        date: users_date,
        we_invoiced: users_we_invoiced,
        paid_to_us: users_paid_to_us,
        invoiced_to_us: users_invoiced_to_us,
        we_paid: ((users_we_paid < 0) ? users_we_paid * (-1) : users_we_paid),
        comment: users_comment,
        balance: users_balance
      }
      good_users_data << users_data_hash
    end
    good_users_data
  end

  def balance_report_total_amounts(balance_report_users_all)
    @totals = { traffic_to_us: 0, we_invoiced: 0, paid_to_us: 0, debt: 0, traffic_from_us: 0, invoiced_to_us: 0,
                we_paid: 0, our_debt: 0, balance: 0
    }

    balance_report_users_all.each do |data|
      @totals[:traffic_to_us] += data[:traffic_to_us]
      @totals[:we_invoiced] += data[:we_invoiced]
      @totals[:paid_to_us] += data[:paid_to_us]
      @totals[:debt] += data[:debt]
      @totals[:traffic_from_us] += data[:traffic_from_us]
      @totals[:invoiced_to_us] += data[:invoiced_to_us]
      @totals[:we_paid] += data[:we_paid]
      @totals[:our_debt] += data[:our_debt]
      @totals[:balance] += data[:balance]
    end
  end

  def user_statement_report_total_amounts(user_statement_report)
    @totals = {we_invoiced: 0, paid_to_us: 0, invoiced_to_us: 0, we_paid: 0, balance: 0}

    user_statement_report.each do |data|
      @totals[:we_invoiced] += data[:we_invoiced]
      @totals[:paid_to_us] += data[:paid_to_us]
      @totals[:invoiced_to_us] += data[:invoiced_to_us]
      @totals[:we_paid] += data[:we_paid]
      @totals[:balance] += data[:balance]
    end
  end

  def check_searching_params(params, time_from, time_till, time_zone, show_hidden_users)
    time_now = Time.current.strftime('%Y-%m')
    time_from = Time.parse(time_from).strftime('%Y-%m')
    time_till = Time.parse(time_till).strftime('%Y-%m')

    return (
    (time_zone != current_user.time_zone.to_s) || params[:s_user].present? ||
        (time_now != time_from) || (time_now != time_till) || show_hidden_users.to_s.blank?
    )
  end

  def clear_search(params)
    current_time = Time.current
    current_time = {year: current_time.year.to_s, month: current_time.month.to_s}
    params[:date_from], params[:date_till], params[:time_zone], params[:s_user_id], params[:show_hidden_users] =
        [current_time, current_time, '', '-2', 0]

    return params
  end

  def initialize_options(params)
    time_zone = params[:time_zone]
    s_user_id = params[:s_user_id]
    balance_report_options = session[:balance_report_options]
    options = balance_report_options || {}

    set_options_from_params(options, params, {order_by: 'nice_user', order_desc: 0, page: 1, show_hidden_users: 0}, '', true)

    currency = session[:show_currency]

    if s_user_id.present?
      options[:s_user] = params[:s_user]
      options[:s_user_id] = s_user_id
    end

    options[:exchange_rate] = currency ? Currency.where(name: currency).first.exchange_rate : 1

    options[:s_time_zone] = (((params[:action] == 'list') ? time_zone[:time_zone].to_s : time_zone.to_s) if time_zone.present?) ||
      (balance_report_options && (params[:clear].to_i != 1) ? balance_report_options[:s_time_zone] : current_user.time_zone.to_s)

    options
  end

  def authorize_assigned_users
    return if User.check_responsability(params[:id])
    flash[:notice] = _('Dont_be_so_smart')
    redirect_to(action: :root) && (return false)
  end
end
