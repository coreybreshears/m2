# MOR accounting stuff
# -*- encoding : utf-8 -*-
class AccountingController < ApplicationController
  layout :determine_layout
  before_filter :check_localization
  before_filter :authorize
  before_filter do |object_instance|
    object_instance.instance_variable_set :@allow_read, true
    object_instance.instance_variable_set :@allow_edit, true
  end

  def index_main
    dont_be_so_smart
    redirect_to(:root) && (return false)
  end

  def date_query(date_from, date_till)
    # date query
    date_sql = if date_from == ''
                 ''
               elsif date_from.length > 11
                 "AND calldate BETWEEN '#{date_from}' AND '#{date_till}'"
               else
                 "AND calldate BETWEEN '" + date_from.to_s + " 00:00:00' AND '" +
                   date_till.to_s + " 23:59:59'"
               end
    date_sql
  end

  def add_space(space)
    space = space.to_i
    sp = ''
    space.times do
      sp += ' '
    end
    sp
  end

  def financial_statements
    @page_title = _('Financial_statements')
    @page_icon = 'view.png'

    @show_currency_selector = 1
    @currency = session[:show_currency]

    params[:clear] ? change_date_to_present : change_date
    @issue_from_date = Date.parse(session_from_date)
    @issue_till_date = Date.parse(session_till_date)

    session_options = session[:accounting_statement_options]
    @valid_status_values = %w[paid unpaid all]
    @user_id = financial_statements_user_id(session_options)
    @status = financial_statements_status(session_options)
    @users = User.find_all_for_select(corrected_user_id, exclude_owner: true)
    @options = {user_id: @user_id, status: @status}

    @show_search = true

    owner_id = admin? ? 0 : current_user_id

    ordinary_user = (current_user.usertype == 'user')

    # there is no need to convert to user currency because method does it by itself
    @paid_payment, @unpaid_payment = Payment.financial_statements(owner_id, @user_id, @status, @issue_from_date,
                                                                  @issue_till_date, ordinary_user, @currency
                                                                 )

    # rename to session options
    session[:accounting_statement_options] = @options
  end

  def not_authorized_generate_pdf_or_csv(user, status)
    # its user and he has permission to generate this pdf/csv
    !((user.id == session[:user_id]) && status) ||
      # its users owner
      (user.owner_id == session[:user_id])
  end

  private

  # Based on what params user selected or if they were not passed based on params saved in session
  # return user_id, that should be filtered for financial statements. if user passed clear as param
  # return nil
  #
  # *Params*
  # +session_options+ hash including :user_id, might be nil
  #
  # *Return*
  # +user_id+ integer or nil

  def financial_statements_user_id(session_options)
    params_clear = params[:clear]
    if current_user.usertype == 'user'
      current_user_id
    elsif params[:user_id] && !params_clear
      params[:user_id]
    elsif session_options && session_options[:user_id] && !params_clear
      session_options[:user_id]
    end
  end

  # Based on what params user selected or if they were not passed based params saved in session
  # return status, that should be filtered for financial statements.
  #
  # *Params*
  # +session_options+ hash including :status, might be nil
  #
  # *Returns*
  # +status+ - string, one of valid_status_values, by default 'all'

  def financial_statements_status(session_options)
    params_clear = params[:clear]
    params_status = params[:status]
    if @valid_status_values.include?(params_status && !params_clear)
      params_status
    elsif session_options && @valid_status_values.include?(session_options[:status] && !params_clear)
      session_options[:status]
    else
      'all'
    end
  end

  # convert prices in statements from default system currency to
  # currency that is set in session
  #
  # *Params*
  # +statement+ iterable of financial stement data(they rices should be in system currency)
  #
  # *Returns*
  # +statement+ same object that was passed only it's prices recalculated in user selected currency

  def convert_to_user_currency(statements)
    exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
    statements.each do |statement|
      statement.price = statement.price.to_d * exchange_rate
      statement.price_with_vat = statement.price_with_vat.to_d * exchange_rate
    end
    statements
  end
end
