# Payments managing.
class PaymentsController < ApplicationController
  layout :determine_layout

  before_filter :check_post_method, only: [:destroy, :create]
  before_filter :access_denied, except: [:personal_payments], if: -> { !(admin? || manager?) }
  before_filter :authorize

  before_filter :find_m2payment, only: [:destroy, :change_comment, :total_amounts, :approve_payment, :deny_payment]
  before_filter :init_help_link, only: [:list]
  before_filter :set_approval_period, only: [:list]
  before_filter :change_to_asc_desc, only: [:personal_payments]
  before_filter :authorize_assigned_users, only: [:new, :create], if: -> { current_user.try(:show_only_assigned_users?) }

  def list
    @page_title = _('Payments')
    @page_icon = 'creditcards.png'
    get_default_currency
    change_date
    @m2payments = {}
    @m2payments[:currencies] = M2Payment.select('DISTINCT currency_id').all
    @m2payments[:searched], @m2payments[:searched_all], @m2payments[:clear_search], @total_pages, @options = nice_list(initialize_options, session[:items_per_page].to_i)
    total_amounts(@m2payments[:searched_all])
    session[:m2payment_order_by_options] = @options
    Application.change_separators(@options.select { |key, _| key.to_s.include?('amount') }, Confline.get_value('Global_Number_Decimal') || '.')
  end

  def personal_payments
    # Temp workaround
    adjust_m2_date
    change_date

    unless user? || reseller?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    clear = params[:clear].present?

    @options = session[:personal_payments] = clear ? {} : load_params_to_session(session[:personal_payments])

    change_date_to_present if clear

    @options[:from] = session_from_datetime
    @options[:till] = session_till_datetime

    if [:order_by, :order_desc].any? { |key| @options[key].blank? }
      @options[:order_by] = 'date'
      @options[:order_type] = 'desc'
      @options[:order_desc] = '1'
    end

    # for ordering - sortable_header
    params.reverse_update(@options.slice(:order_desc, :order_by))

    @payments, @totals, @show_only_latest = M2Payment.find_personal_payments(@options, current_user)
    @payments = @payments.page(params[:page]).per(session[:items_per_page])
    @payments = @payments.order('date desc').limit(10) if @show_only_latest
  end

  def new
    @page_title = _('Add_payment')
    @page_icon = 'creditcards.png'

    cache = session[:new_payment_cache] || {amount: nil, amount_with_tax: nil}
    user_id = params[:user_id]
    @user = User.where(id: user_id).first if user_id

    @data = {
      currencies: Currency.get_active,
      payment: M2Payment.new(cache)
    }

    session.try(:delete, :new_payment_cache)
  end

  def confirm
    @page_title = _('Add_payment')
    @page_icon = 'creditcards.png'

    payment_attributes = params[:m2_payment] || {}
    payment_attributes[:user_id] = params[:s_user_id]
    user_id = payment_attributes[:user_id]

    unless User.where(id: user_id).present?
      redirect_to(action: :new) && (return false)
    end

    if User.first_owned_by(user_id, correct_owner_id) and Currency.first_active(payment_attributes[:currency_id])
      Application.change_separators(payment_attributes.select { |key, _| ['amount', 'amount_with_tax', 'exchange_rate'].member? key }, '.')
      @payment = M2Payment.new_by_attributes(payment_attributes)

      if !@payment.valid?
        session[:new_payment_cache] = payment_attributes
        flash_errors_for(_('payment_was_not_created'), @payment)
        redirect_to controller: 'payments', action: 'new', user_id: user_id
      else
        disallow_send_confirmation = User.where(id: user_id).first.get_email_to_address2.blank?
        render locals: {
          default_currency: Currency.get_default.name,
          payment_currency: @payment.currency.name,
          disallow_send_confirmation: disallow_send_confirmation
        }
      end
    else
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def create
    payment_attributes = params[:m2_payment]
    user_id = payment_attributes[:user_id].to_i
    payment = M2Payment.new_by_attributes(payment_attributes)
    payment.save!
    if payment.present? && payment.amount > 0
      invoice = payment.generate_invoice_for_manual_payment
      if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1 && invoice
        send_payment_invoice(invoice)
      end
    end

    user = User.where(id: user_id).first
    user_owner_id = user.owner_id
    Application.reset_user_warning_email_sent_status(user)

    if params[:confirm_payment_email].to_i == 1
      email = Email.where(name: 'payment_confirmation', owner_id: user_owner_id).first
      email_from = Confline.get_value('Email_from', user_owner_id).to_s
      variables = email_variables(user)
      variables[:user_email] = user.get_email_to_address2.to_s
      _status, email_error = Email.send_balance_warning_email(email, email_from, user, variables)
      if email_error.blank?
        Action.create_email_sending_action(user, 'email_sent', email, er_type: 0, status: 'email_sent')
      end
    end

    flash[:status] = _('payment_successfully_created')
    if email_error.present?
      email_error_notice = _('Email_Something_is_wrong_please_consult_help_link')
      email_error_notice += "<a id='exception_info_link' href='http://wiki.ocean-tel.uk/index.php/Configuration_from_GUI#Emails' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
      flash[:notice] = email_error_notice
    end

    redirect_to controller: 'payments', action: 'list', params: {s_user_id: user_id, s_user: params[:s_user]}
  end

  def destroy
    if @m2payment.approved.to_i == 1
      flash[:notice] = _('Payment_is_waiting_for_approval')
      redirect_to(action: :list) && (return false)
    end

    if @m2payment.destroy
      user = User.where(id: @m2payment.user_id).first
      if user.try(:class) == User && [0, 2].include?(@m2payment.approved.to_i)
        user.raw_balance -= @m2payment.amount
        user.save
      end
      flash[:status] = _('Payment_successfully_deleted')
    else
      dont_be_so_smart
    end
    redirect_to action: :list
  end

  def change_comment
    @m2payment.comment = params[:comment].to_s.strip
    @m2payment.save
    render(nothing: true) && (return false)
  end

  def get_currency_by_user_id
    user = User.where("id = #{params[:id]} AND owner_id = #{correct_owner_id}").first
    return unless user
    currency = user.currency_id
    render text: currency.to_s
  end

  def approve_payment
    if @m2payment.approved == 2
      redirect_to(action: :list) && (return false)
    end

    @m2payment.approved = 2
    if @m2payment.save
      @m2payment.update_user_balance
      @m2payment.send_confirmnation_email_to_user
      flash[:status] = _('Payment_was_approved_successfully')
    else
      flash[:notice] = _('Payment_was_not_approved')
    end
    redirect_to(action: :list) && (return false)
  end

  def deny_payment
    if @m2payment.approved == 3
      redirect_to(action: :list) && (return false)
    end

    @m2payment.approved = 3
    if @m2payment.save
      @m2payment.update_denied_balance
      @m2payment.send_confirmnation_email_to_user('rejected')
      flash[:status] = _('Payment_was_denied_successfully')
    else
      flash[:notice] = _('Payment_was_not_denied')
    end
    redirect_to(action: :list) && (return false)
  end

  private

  def total_amounts(payments)
    @totals = {amount: 0, amount_with_tax: 0}
    exchange_currency = ->(amount, exchange_rate) { amount * exchange_rate }
    current_currency = current_user.active_currency

    payments.each do |payment|
      @totals[:amount] += payment.amount.to_d
      @totals[:amount_with_tax] += payment.amount_with_tax.to_d
    end
  end

  def find_m2payment
    @m2payment = M2Payment.where(id: params[:id]).first
    return if @m2payment
    flash[:notice] = _('payment_not_found')
    redirect_to(action: :list) && (return false)
  end

  def init_help_link
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
  end

  def nice_list(options, items_per_page)
    selection_all, clear_search, invalid_search = M2Payment.order_by(options, current_user)

    selection = selection_all = [] if invalid_search

    fpage, total_pages, options = Application.pages_validator(session, options, selection_all.size)

    selection = selection_all[fpage...(items_per_page + fpage)]

    return selection, selection_all, clear_search, total_pages, options
  end

  def initialize_options
    options = session[:m2payment_order_by_options] || {}

    if params[:clear].to_i == 1
      change_date_to_present
      options = {}
    end

    options[:s_date_from], options[:s_date_till], options[:not_default_date] = date_search

    param_keys = [
      'order_by', 'order_desc', 'search_on', 'page', 's_user_id', 's_amount_min', 's_amount_max',
      's_currency_id', 's_date_from', 's_date_till', 's_user'
    ]
    params.select { |key, _| param_keys.member?(key) }.each do |key, value|
      options[key.to_sym] = value.to_s
    end

    options[:s_user_id] = '' if options[:s_user].blank? && options[:s_user_id].to_i == -2

    options[:decimal_digits] = session[:nice_number_digits]
    options[:hide_hidden_users] = true
    options
  end

  def date_search
    time = Time.current
    user_date_from = time.beginning_of_day.strftime('%Y-%m-%d %H:%M:%S')
    user_date_till = time.end_of_day.strftime('%Y-%m-%d %H:%M:%S')
    not_default_date = session_from_datetime != user_date_from || session_till_datetime != user_date_till
    user_date_from, user_date_till = not_default_date ? [session_from_datetime, session_till_datetime] : [user_date_from, user_date_till]
    return user_date_from, user_date_till, not_default_date
  end

  def change_to_asc_desc
    order_desc = params[:order_desc]
    params[:order_type] = ((order_desc.to_i == 0) ? 'asc' : 'desc') if order_desc.present?
  end

  def authorize_assigned_users
    user_id = params[:user_id] || params[:m2_payment][:user_id]
    return if user_id.blank?
    redirect_to(action: :root) && (return false) unless User.check_responsability(user_id)
  end

  def send_payment_invoice(invoice)
    user_invoice = User.where(id: invoice.user_id).first
    return false if user_invoice.blank?

    email = Email.where(name: 'invoices', owner_id: user_invoice.owner_id).first
    variables = Email.email_variables(user_invoice, nil, {}, invoice: invoice)
    email.body = EmailsController::nice_email_sent(email, variables)
    email.subject = EmailsController::nice_email_sent(email, variables, 'subject')
    email_from = current_user.email.to_s
    email_to = user_invoice.get_email_to_address2.to_s
    attach = payment_invoice_attachment(invoice)

    return false unless attach

    email_status = Email.send_email_with_attachment(email, email_to, email_from, attach)
    if email_status
      Action.create_email_sending_action(user_invoice, 'email_sent', email, er_type: 0, status: 'email_sent')
    end
  end

  def payment_invoice_attachment(invoice)
    require 'templateXL/templateXL/templates/m2_invoice_template'
    return if invoice.blank?
    invoice_user = invoice.user
    template_path, invoice_cells_confline_owner_id = invoice_user.custom_invoice_xlsx_template_preparation
    m2_invoice_number = invoice.number
    file_path, file_name = ["/tmp/m2/invoices/#{m2_invoice_number}.xlsx", "#{m2_invoice_number}.xlsx"]

    m2_invoice_template = TemplateXL::M2InvoiceTemplate.new(template_path, file_path, invoice_cells_confline_owner_id)
    m2_invoice_template.m2_invoice, m2_invoice_template.m2_invoice_lines = invoice.copy_for_xslx
    m2_invoice_template.generate
    m2_invoice_template.save

    if Confline.get_value('convert_xlsx_to_pdf').to_i == 1
      system("rm -rf /tmp/m2/invoices/#{m2_invoice_number}.pdf")
      convert_xlsx_to_pdf('/tmp/m2/invoices', m2_invoice_number)
      pdf_file_path = "/tmp/m2/invoices/#{m2_invoice_number}.pdf"
      return pdf_file_path if File.exists?(pdf_file_path)
    end

    File.exists?(file_path) ? file_path : false
  end

  def set_approval_period
    return if params[:needs_approve].blank?
    dates = M2Payment.approval_period.reject { |date| date.blank? }
    return if dates.blank?
    params[:date_from] = date_hash(nice_user_timezone(dates[0]).to_time)
    params[:date_till] = date_hash(nice_user_timezone(dates[1]).to_time, true)
  end

  def date_hash(date, till = false)
    {
      year: date.year,
      month: date.month,
      day: date.day,
      hour: date.hour,
      minute: till ? '59' : date.min
    }
  end
end
