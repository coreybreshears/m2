# -*- encoding : utf-8 -*-
# Financial Statuses list.
class FinancialStatusesController < ApplicationController
  layout :determine_layout

  before_filter :authorize
  before_filter :access_denied, if: lambda { user? }
  before_filter :set_session, only: [:list]
  before_filter :set_currency, only: [:list]
  before_filter :get_exchange_rate, only: [:list]
  before_filter :change_separator, only: [:list]

  def list
    @page_title, @page_icon = [_('financial_status'), 'details.png']
    @show_currency_selector = true
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'

    user_id = manager? ? 0 : current_user.id
    ses_financial_statuses = session[:financial_statuses].merge(current_user: current_user)
    @users, where_sentence = FinancialStatus.financial_status(ses_financial_statuses, User, user_id)
    @users, @total_pages, @options = nice_list(@options, @users)
    find_totals(@users, where_sentence)
    change_back_separator
    show_clear_button
  end

  private

  def find_totals(users, where_sentence)
    @totals = {}
    if users && users.size > 0
      [:balance, :balance_min, :balance_max, :warning_email_balance].each {|key| @totals[key] = User.where(where_sentence).sum(key)}
    end
  end

  def show_clear_button
    options = session[:financial_statuses]
    @show_clear_button = (options.present? and [:s_user_id, :min_balance, :max_balance, :s_accountant_id].any? {|key| options[key].present?})
  end

  def change_separator
    # Change user's number separator to MOR's
    options = session[:financial_statuses]
    options[:min_balance].to_s.try(:sub!, /[\,\.\;]/, '.').try(:strip!)
    options[:max_balance].to_s.try(:sub!, /[\,\.\;]/, '.').try(:strip!)
    session[:financial_statuses] = options
  end

  def change_back_separator
    options = session[:financial_statuses]
    separator = Confline.get_value('Global_Number_Decimal').to_s
    options[:min_balance].try(:sub!, /[\,\.\;]/, separator)
    options[:max_balance].try(:sub!, /[\,\.\;]/, separator)
    session[:financial_statuses] = options
  end

  def nice_list(options, users)
    if users
      fpage, total_pages, options = Application.pages_validator(session, options, users.size)
      selection = users.limit("#{fpage}, #{session[:items_per_page]}")
      return selection, total_pages, options
    else
      return nil, 0, options
    end
  end

  def set_session
    order_by, order_desc, page = params[:order_by], params[:order_desc], params[:page]
  	options = session[:financial_statuses]
    options = {} if params[:clear] || !options
    options = params if params[:search_pressed]
    options[:order_by], options[:order_desc] = order_by, order_desc.to_i if order_by
    options[:page] = page if page
    @options = session[:financial_statuses] = options
  end

  def set_currency
    currency = params[:currency]
    if currency
      session[:show_currency] = currency
    elsif !session[:show_currency]
      session[:show_currency] = Currency.first.name
    end
  end

  def get_exchange_rate
    currency = session[:show_currency]
    session[:financial_statuses][:exchange_rate] = currency ? Currency.where(name: currency).first.exchange_rate : 1
  end
end
