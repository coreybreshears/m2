# Invoices managing and exporting.
class M2InvoicesController < ApplicationController
  include M2InvoicesHelper
  include M2InvoiceLinesHelper
  layout :determine_layout

  before_filter :check_post_method, only: [:destroy, :update, :recalculate_invoice]
  before_filter :authorize
  before_filter :access_denied, except: [:user_invoices,
                                         :user_invoice_details,
                                         :export_to_xlsx], if: -> { user? }
  before_filter :check_localization

  before_filter :find_m2_invoice, only: [:edit, :update, :destroy, :total_amounts, :export_to_xlsx, :invoice_lines,
                                         :total_inv_line_amount, :user_invoice_details, :recalculate_invoice]
  before_filter :number_separator

  before_filter :init_help_link, only: [:list, :invoice_lines, :edit, :update]
  before_filter :strip_params, only: [:list, :invoice_lines, :update]
  before_filter :change_currency, only: [:list, :invoice_lines]
  before_filter :status_changed_present, only: [:update]
  before_filter :authorize_assigned_users, only: [:export_to_xlsx, :edit, :destroy, :invoice_lines,
                                                  :recalculate_invoice, :update, :edit],
                                                   if: -> { current_user.try(:show_only_assigned_users?) }
  before_filter :check_es_sync_status, only: %w[generate_invoices_status]
  before_filter :check_manual_invoice, only: %w[recalculate_invoice invoice_lines]

  def list
    @create_button_name = _('Generate_invoices')
    @options ||= {}

    @page_title = _('Invoices')
    @page_icon = 'view.png'
    @show_currency_selector = true
    @options = initialize_options(params[:action].to_s)
    @options = manual_generation_time(session)
    @float_digits = Confline.get_value('Nice_Number_Digits').to_i
    @m2_invoices_all, @m2_invoices_in_page, @total_pages, @options, @clear_search = nice_list(@options, session[:items_per_page].to_i)
    total_amounts(@m2_invoices_all)
    session[:m2_invoices_options] = @options
    Application.change_separators(@options, @nbsp)
  end

  def manual_generation_time(session)
    search_is_not_cleared = !params[:clear]
    time = session[:time]
    from = time[:from]
    till = time[:till]
    issue = time[:issue]

    @options[:from] = from.present? && search_is_not_cleared ? from.to_s :
    session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s)

    @options[:till] = till.present? && search_is_not_cleared ? till.to_s :
    session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s)

    @options[:issue] = issue.present? && search_is_not_cleared ? issue.to_s :
    session[:year_issue].to_s + '-' + good_date(session[:month_issue].to_s) + '-' + good_date(session[:day_issue].to_s) + '00:00:00'
    session[:time] = {}
    @options
  end

  def customer_invoices_recalculate
    invoices_ids = params[:invoices_ids]
    invoices_numbers = params[:invoices_numbers].to_s.split(' ')
    action = params[:commit]

    if invoices_ids.present?
      invoices_ids_for_script = remove_manual_payment_ids_from_list(invoices_ids)
      if action == _('Recalculate_selected') && invoices_ids_for_script.present?
        BackgroundTask.create(
          task_id: 5,
          owner_id: 0,
          created_at: Time.zone.now,
          status: 'WAITING',
          user_id: -2
        )

        invoices_numbers.map! { |number| "/tmp/m2/invoices/#{number}.{xlsx,pdf}" }
        invoices_numbers.in_groups_of(20, false) do |numbers_group|
          `rm -rf #{numbers_group.join(' ')}`
        end

        system("/usr/local/m2/m2_invoices #{invoices_ids_for_script} &")
        flash[:status] = _('bg_task_for_recalculating_invoices_seccesfully_created')
        (manager? ? redirect_to(controller: 'm2_invoices', action: 'list') :
          redirect_to(controller: 'functions', action: 'background_tasks')) && (return false)
      elsif action == _('send_selected') && invoices_ids_for_script.present?
        M2Invoice.send_selected_email(invoices_ids_for_script)
        system('/usr/local/m2/m2_invoices_report &')
        flash[:status] = _('Invoices_are_scheduled_to_send')
      elsif action == _('delete_selected')
        bulk_delete(invoices_ids)
      end
    else
      flash[:notice] = _('No_invoice_found_to_recalculate')
    end
    (redirect_to action: :list) && (return false)
  end

  def edit
    @page_title = _('Invoice_edit', @m2_invoice.number)
    @page_icon = 'edit.png'
    @m2_invoice_user = User.where(id: @m2_invoice.user_id).first
    @countries = Direction.all
    @m2_invoice.issue_date = nice_date_time(@m2_invoice.issue_date, ofset = 0)
    @m2_invoice.due_date = nice_date_time(@m2_invoice.due_date, ofset = 0)
    @m2_invoice.status_changed = nice_date_time(@m2_invoice.status_changed, ofset = 0)
  end

  def update
    @page_title = _('Invoice_edit', params[:number])
    @page_icon = 'edit.png'
    @countries = Direction.all
    @m2_invoice_user = User.where(id: @m2_invoice.user_id).first
    params[:issue_date].delete_if { |_k, value| value.empty? }
    params[:status_changed].delete_if { |_k, value| value.empty? }
    issue_date = params[:issue_date]

    params[:issue_date_system_tz] = user_time_from_params(*issue_date.values, true) if issue_date.present?
    params[:due_date_system_tz] = user_time_from_params(*params[:due_date].values, true)

    params[:status_changed_system_tz] = change_issue_date(@m2_invoice, params) if params[:status_changed].present?

    if @m2_invoice.validates_dates_from_update(params) && @m2_invoice.update_attributes(invoice_attributes)
      flash[:status] = _('invoice_updated')
      redirect_to action: 'list'
    else
      flash_errors_for(_('invoice_not_updated'), @m2_invoice)
      Application.change_separators(params[:m2_invoice], @nbsp)
      render :edit
    end
  end

  def generate_invoices_status
    MorLog.my_debug " ********* \n for period #{session_from_date} - #{session_till_date}"
    MorLog.my_debug "for period #{session_from_date} - #{session_till_date}"

    date_frmt = '%Y-%m-%d'
    date_till = parse_datetime(params[:date_till]).strftime(date_frmt)
    period_start = parse_datetime(params[:period_start]).strftime(date_frmt)
    issue = parse_datetime(params[:issue]).strftime(date_frmt)

    s_user_id = params[:s_user_id]
    s_user = params[:s_user].to_s
    time = {from: period_start, till: date_till, issue: issue}

    if [-2, -1].include?(s_user_id.to_i) || s_user == ''
      session[:time] = {from: period_start, till: date_till, issue: issue}
      flash[:notice] = _('Invoice_was_not_generated') + '<br> * ' + _('User_not_found')
      redirect_to(action: 'list') && (return false)
    else
      s_user_id = -1 if s_user == 'All' || s_user_id.to_s == 'all'

      valid_period = true
      period_end = Time.parse(date_till + ' 23:59:59')
      if s_user_id == -1
        unless validate_period(period_end)
          flash[:notice] = _('Period_not_over_for_some_users')
          valid_period = false
        end
      else
        unless validate_period_user(s_user_id, period_end)
          flash[:notice] = _('Period_not_over_for_this_user')
          valid_period = false
        end
      end
      redirect_to(action: :list) && (return false) unless valid_period

      BackgroundTask.generate_invoice_background(time, s_user_id, current_user_id)
      flash[:status] = _('bg_task_for_generating_invoice_successfully_created')
      system('/usr/local/m2/m2_invoices generate &')

      if admin?
        redirect_to(controller: 'functions', action: 'background_tasks') && (return false)
      else
        redirect_to(action: 'list') && (return false)
      end
    end
  end

  def invoice_lines
    @page_title = _('Invoice_details')
    @page_icon = 'view.png'

    @options = initialize_options(params[:action].to_s)
    @m2_invoice = M2Invoice.where(id: params[:id].to_i).first
    @m2_invoice_lines_all, @m2_invoice_lines_in_page, @total_pages, @options, @clear_search = nice_invoice_lines_list(@options, session[:items_per_page].to_i, @m2_invoice.id)
    session[:m2_invoice_lines_options] = @options
    Application.change_separators(@options, @nbsp)
  end

  def destroy
    delete_invoice(@m2_invoice)

    redirect_to action: 'list', search_on: 1
  end

  def export_to_xlsx
    if user? && (@m2_invoice.user_id != current_user_id)
      flash[:notice] = _('invoice_not_found')
      redirect_to(action: :user_invoices) && (return false)
    end

    require 'templateXL/templateXL/templates/m2_invoice_template'
    invoice_user = @m2_invoice.user
    template_path, invoice_cells_confline_owner_id = invoice_user.custom_invoice_xlsx_template_preparation
    m2_invoice_number = @m2_invoice.number
    file_path = "/tmp/m2/invoices/#{m2_invoice_number}.xlsx"
    file_name = "#{m2_invoice_number}.xlsx"
    as_pdf = params[:as_pdf].to_i == 1
    test = params[:test].to_i == 1

    if File.exists?(file_path) and !test
      data = File.open(file_path).try(:read)
      if as_pdf
        send_xlsx_as_pdf('/tmp/m2/invoices', m2_invoice_number, :list)
      else
        send_data(data, filename: file_name, type: 'application/octet-stream')
      end
    else
      m2_invoice_template = TemplateXL::M2InvoiceTemplate.new(template_path, file_path, invoice_cells_confline_owner_id)
      M2InvoiceLine.do_not_include
      m2_invoice_template.m2_invoice, m2_invoice_template.m2_invoice_lines = @m2_invoice.copy_for_xslx
      begin
        m2_invoice_template.generate
      rescue => rubyxl_error
        flash[:notice] = (rubyxl_error.to_s == 'Row and Column arguments must be nonnegative' ? _('rubyxl_cell_invalid_format') : rubyxl_error.to_s)
        redirect_to(action: :list) && (return false)
      end

      if test
        test_data = m2_invoice_template.test
        render text: test_data.to_s
      else
        m2_invoice_template.save
        if as_pdf
          system("rm -rf /tmp/m2/invoices/#{m2_invoice_number}.pdf")
          send_xlsx_as_pdf('/tmp/m2/invoices', m2_invoice_number, :list)
        else
          send_data(m2_invoice_template.content, filename: file_name, type: 'application/octet-stream')
        end
      end
    end
  end

  def user_invoices
    @invoices = M2Invoice.where(user_id: current_user_id).order(status_changed: :desc).all
    @invoice_totals = user_invoice_totals(@invoices)
  end

  def user_invoice_details
    if user? && @m2_invoice.user_id != current_user_id
      flash[:notice] = _('invoice_not_found')
      redirect_to(action: :user_invoices) && (return false)
    end

    @user_invoice_lines = M2InvoiceLine.find_user_invoice_details(@m2_invoice)
    @totals = {
      time: @user_invoice_lines.sum(:total_time),
      price: (@user_invoice_lines.sum(:price) * @m2_invoice.exchange_rate.to_f),
      calls: @user_invoice_lines.sum(:calls)
    }
    @user_invoice_lines = @user_invoice_lines.page(params[:page]).per(session[:items_per_page])
  end

  def recalculate_invoice
    @user = User.where(id: @m2_invoice.user_id).first
    if @user && @user.address
      @m2_invoice.recalculate_invoice(@user)
      invoices_id = params[:id]
      system("/usr/local/m2/m2_invoices #{invoices_id}") if invoices_id.present?
      system("rm -rf /tmp/m2/invoices/#{@m2_invoice.number}.{xlsx,pdf}")
      # recalculate_invoice_xlsx(@m2_invoice)
      flash[:status] = _('Invoice_successfully_Recalculated')
    else
      flash[:notice] = _('User_not_found')
    end
    redirect_to(action: :edit, id: @m2_invoice.id) && (return false)
  end

  private

  def recalculate_invoice_xlsx(m2_invoice)
    # This method has a bug - when getting M2Invoice and User objects it retrieves them from Rails cache, even thou
    #   they could be already updated by a C script, which results in an invalid (old) generated XLSX/PDF
    # If there is an intention to use this method, make sure to fix DB retrieval by bypassing old cache
    m2_invoice = M2Invoice.where(id: m2_invoice.id).first
    inv_number = m2_invoice.number.to_s
    invoice_user = m2_invoice.user
    require 'templateXL/templateXL/templates/m2_invoice_template'

    template_path, invoice_cells_confline_owner_id = invoice_user.custom_invoice_xlsx_template_preparation
    file_path = "/tmp/m2/invoices/#{inv_number}.xlsx"
    file_name = "#{inv_number}.xlsx"

    File.delete(file_path) if File.exist?(file_path)

    m2_invoice_template = TemplateXL::M2InvoiceTemplate.new(template_path, file_path, invoice_cells_confline_owner_id)
    M2InvoiceLine.do_not_include
    m2_invoice_template.m2_invoice, m2_invoice_template.m2_invoice_lines = @m2_invoice.copy_for_xslx
    m2_invoice_template.generate
    m2_invoice_template.save

    system("rm -rf /tmp/m2/invoices/#{inv_number}.pdf")
    convert_xlsx_to_pdf('/tmp/m2/invoices', inv_number)
  end

  def user_invoice_totals(invoices)
    invoice_totals = {total_amount: 0, total_amount_with_tax: 0}
    currencies = {
      show_currency: session[:show_currency].to_s.upcase,
      default_currency: session[:default_currency].to_s.upcase
    }

    invoices.each do |invoice|
      amounts = {
        amount: invoice.total_amount,
        amount_with_tax: invoice.total_amount_with_taxes,
        currency: invoice.currency.to_s.upcase,
        exchange_rate: invoice.currency_exchange_rate.to_f
      }

      if currencies[:show_currency] == amounts[:currency]
        amounts[:amount] *= amounts[:exchange_rate]
        amounts[:amount_with_tax] *= amounts[:exchange_rate]
      elsif currencies[:show_currency] != currencies[:default_currency]
        show_exchange_rate = Currency.where(name: currencies[:show_currency]).first.exchange_rate.to_f
        amounts[:amount] *= show_exchange_rate
        amounts[:amount_with_tax] *= show_exchange_rate
      end

      invoice_totals[:total_amount] += amounts[:amount].round(2)
      invoice_totals[:total_amount_with_tax] += amounts[:amount_with_tax].round(2)
    end

    invoice_totals
  end

  def invoice_attributes
    params[:m2_invoice].merge({issue_date: params[:issue_date_system_tz],
                               due_date: params[:due_date_system_tz],
                               status_changed: params[:status_changed_system_tz]
                              }
                             )
  end

  def total_amounts(m2_invoices)
    @totals = {amount: 0, amount_with_tax: 0}
    options_exchange_rate = @options[:exchange_rate].to_d
    m2_invoices.each do |m2_invoice|
      @totals[:amount] += nice_invoice_amount(m2_invoice.total_amount.to_d, m2_invoice, options_exchange_rate, '.').to_d
      @totals[:amount_with_tax] += nice_invoice_amount(m2_invoice.total_amount_with_taxes.to_d, m2_invoice, options_exchange_rate, '.').to_d
    end
  end

  def total_inv_line_amount(m2_invoice_lines, m2_invoice)
    @total_amount = 0

    m2_invoice_lines.each do |m2_invoice_line|
      @total_amount += nice_invoice_amount(m2_invoice_line.price.to_d, m2_invoice, @options[:exchange_rate], '.').to_d
    end
  end

  def find_m2_invoice
    @m2_invoice = M2Invoice.where(id: params[:id]).first

    unless @m2_invoice
      flash[:notice] = _('invoice_not_found')
      redirect_to(action: 'list') && (return false)
    end
  end

  def check_manual_invoice
    return if @m2_invoice.manual_payment_invoice.to_i != 1
    flash[:notice] = _('invoice_not_found')
    redirect_to(action: 'list') && (return false)
  end

  def init_help_link
    @help_link = "http://wiki.ocean-tel.uk/index.php/Main_Page"
  end

  def nice_list(options, items_per_page)
    options[:s_issue_date] = current_user.system_time(options[:s_issue_date]) if options[:s_issue_date].present?
    options[:current_user] = current_user
    selection_all, clear_search = M2Invoice.filter(options, session[:show_currency].to_s)
    fpage, total_pages, options = Application.pages_validator(session, options, selection_all.size)
    selection_in_page = selection_all.order_by(options, fpage, items_per_page)
    return selection_all, selection_in_page, total_pages, options, clear_search
  end

  def nice_invoice_lines_list(options, items_per_page, invoice_id)
    selection_all, clear_search = M2InvoiceLine.invoice_lines_filter(options, invoice_id)
    fpage, total_pages, options = Application.pages_validator(session, options, selection_all.size)
    selection_in_page = selection_all.invoice_lines_order_by(options, fpage, items_per_page)
    return selection_all, selection_in_page, total_pages, options, clear_search
  end

  def clear_options(options)
    [:s_nice_user, :s_number, :s_period_start, :s_period_end, :s_issue_date, :s_status, :s_min_amount, :s_max_amount, :s_currency, :s_prefix].each do |key|
      options[key] = ''
    end

    options
  end

  def initialize_options(action)
    if action == 'invoice_lines'
      options = session[:m2_invoice_lines_options] || {}
      param_keys = ['order_by', 'order_desc', 'search_on', 'page', 's_prefix']
    else
      options = session[:m2_invoices_options] || {}
      param_keys = ['order_by', 'order_desc', 'search_on', 'page', 's_nice_user', 's_number', 's_period_start', 's_period_end',
                    's_issue_date', 's_status', 's_min_amount', 's_max_amount', 's_currency']
    end

    params.select{|key, _| param_keys.member?(key)}.each do |key, value|
      options[key.to_sym] = value.to_s
    end

    Application.change_separators(options, '.')
    options[:csv] = params[:csv].to_i

    options = clear_options(options) if params[:clear]
    options[:clear] = ([:s_nice_user, :s_number, :s_period_start, :s_period_end, :s_issue_date, :s_status,
                        :s_min_amount, :s_max_amount, :s_currency].any? {|key| options[key].present?})
    options[:exchange_rate] = change_exchange_rate

    options
  end

  def change_issue_date(invoice, params)
    old_date = invoice.status_changed
    params[:status_changed_time] = { 'year' => old_date.year,
                                     'month' => old_date.month,
                                     'day' => params[:status_changed]['status_changed(3i)'],
                                     'hour' => params[:status_changed]['status_changed(4i)'],
                                     'minute' => params[:status_changed]['status_changed(5i)'] }

    new_date = user_time_from_params(*params[:status_changed_time].values, true)

    if old_date.month != new_date.month
      new_date = old_date.end_of_month
    end

    new_date
  end

  def status_changed_present
    return if @m2_invoice.status_changed.present?
    flash[:notice] = _('Database_Error')
    redirect_to(:root) && (return false)
  end

  def validate_period(till_time)
    users = User.where(generate_invoice_manually: 1)
    users.try(:each) do |user|
      next if usertime_over?(user, till_time)
      flash[:notice] = _('Period_not_over_for_some_users')
      return false
    end
    true
  end

  def validate_period_user(user_id, till_time)
    user = User.find_by(id: user_id)
    return false unless user.present?
    return true if usertime_over?(user, till_time)
    flash[:notice] = _('Period_not_over_for_this_user')
    false
  end

  def authorize_assigned_users
    user_id = M2Invoice.where(id: params[:id].to_i).first.try(:user_id)
    return if User.check_responsability(user_id)
    flash[:notice] = _('Dont_be_so_smart')
    redirect_to(action: :root) && (return false)
  end

  def check_es_sync_status
    options = {
      till: parse_datetime(params[:date_till]),
      from: parse_datetime(params[:period_start])
    }
    unless EsQuickStatsTechnicalInfo.get_data_for_invoice(options)
      flash[:notice] = _('invoice_generate_error_data')
      redirect_to(action: 'list') && (return false)
    end
  end

  def delete_invoice(inv)

    if inv.destroy
      flash[:status] = _('invoice_deleted')
    else
      dont_be_so_smart
    end
  end

  def bulk_delete(inv_ids)
    invoices_ids = inv_ids.split(' ')
    invoices_ids.each do |inv_id|
      inv = M2Invoice.where(id: inv_id.to_s).first
      delete_invoice(inv)
    end
    flash[:status] = _('invoices_deleted')
  end

  def remove_manual_payment_ids_from_list(inv_ids)
    invoices_ids = inv_ids.split(' ')
    invoices = M2Invoice.select(:id).where(id: invoices_ids, manual_payment_invoice: 0)
    ids_list = ''
    invoices.each { |inv| ids_list += inv.id.to_s + ' ' }
    ids_list
  end

end
