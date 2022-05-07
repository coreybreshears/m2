# M2 CDR Dispute
class CdrDisputesController < ApplicationController
  layout 'm2_admin_layout'

  before_action :authorize, :check_localization
  before_action :access_denied, unless: -> { admin? }
  before_action :find_dispute, only: [:report, :detailed_report, :edit, :update, :destroy]
  before_action :formatting_options, only: [:report, :detailed_report]
  before_action :form_lists, only: [:new, :edit, :create, :update]
  before_action :allow_waiting, only: [:edit, :update, :proceed_to_import]
  before_action :allow_completed, only: [:report, :detailed_report]
  before_action :check_xhr, only: [:compute_exchange_rate, :template_data]
  before_action :check_post_method, only: [:create, :update]

  def list
    @disputes = Dispute.order('id DESC')
  end

  def new
    @dispute = Dispute.new
  end

  def create
    @dispute = Dispute.new(permitted_params)
    set_periods
    if @dispute.save
      flash[:status] = _('Dispute_created')
      to_import
    else
      flash_errors_for(_('Dispute_not_created'), @dispute)
      render :new
    end
  end

  def edit; end

  def update
    set_periods
    if @dispute.update_attributes(permitted_params)
      flash[:status] = _('Dispute_updated')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('Dispute_not_updated'), @dispute)
      render :edit
    end
  end

  def destroy
    # Disputed CDRs are drestroyed alongside
    if @dispute.destroy
      flash[:status] = _('Dispute_deleted')
    else
      flash[:notice] = _('Dispute_not_deleted')
    end
    redirect_to(action: :list) && (return false)
  end

  # CDR dispute report aggregated by mismatch type
  def report
    compose_messages
    @dispute_groups ||= @dispute.report(@formatting)
  end

  # Detailed CDR dispute report. Shows all disputes
  def detailed_report
    set_options
    @disputed_cdrs ||= @dispute.detailed_report(
      @options.merge(@formatting)
    )
  end

  # Ajax services for exchange rate and template data
  def compute_exchange_rate
    curr = Currency.find_by(id: params[:currency_id])
    return render text: 1.0 if curr.blank?

    render text: Currency.count_exchange_rate(
      curr.name, session[:default_currency]
    ).round(6)
  end

  def template_data
    render json: DisputeTemplate.find_by(id: params[:template_id])
  end

  def proceed_to_import
    to_import
  end

  protected

  # Check messages from the script
  def compose_messages
    flash[:notice] ||=
      case @dispute.message.to_i
        when 1 then _('Could_not_retrieve_Local_CDRs')
        when 2 then _('Could_not_retrieve_External_CDRs')
        when 3 then _('Could_not_find_time_shift')
      end
  end

  # Reject if disputes is in progress or complated
  def allow_waiting
    find_dispute
    return if @dispute.waiting?
    flash[:notice] = _('Cannot_edit_Dispute')
    redirect_to(action: :list) && (return false)
  end

  # In progress or complated disputes cannot be edited
  def allow_completed
    find_dispute
    return if @dispute.completed?
    flash[:notice] = _('Dispute_is_not_yet_complated')
    redirect_to(action: :list) && (return false)
  end

  # Redirects to CDR import
  def to_import
    flash[:dispute_id_cdr_import] = @dispute.id
    redirect_to(controller: :cdr, action: :import_csv, step: 0) && (return false)
  end

  # Mass assignment protection
  def permitted_params
    params[:dispute][:user_id] =
      if params[:dispute][:direction].to_i.zero?
        params[:s_originator_id]
      else
        params[:s_terminator_id]
      end

    params.require(:dispute)
    .permit(
        :direction, :dispute_template_id, :billsec_tolerance, :user_id, :cost_tolerance, :cmp_last_src_digits,
        :cmp_last_dst_digits, :currency_id, :exchange_rate, :template_name, :new_template, :check_only_answered_calls
    )
  end

  # Sets period_start and period_end for a dispute
  def set_periods
    @dispute.period_start = "#{params[:period_start_date]} #{params[:period_start_time]}"
    @dispute.period_end = "#{params[:period_end_date]} #{params[:period_end_time]}"
  end

  # Initializes data used in a form
  def form_lists
    @currencies = Currency.all.map { |curr| [curr.name, curr.id] }
    @templates = [[_('None'), '']]
    @templates += DisputeTemplate.order(:name).map { |tpl| [tpl.name, tpl.id] }
  end

  # Sets options for filtering, sorting, paging,
  #   and session persistence
  def set_options
    # Clears search if needed
    clear_search = params[:clear].present?
    session[:detailed_report_filters] = {} if clear_search
    @options = session[:detailed_report_filters] || {}

    # Updates the page params
    page_params

    if !clear_search && params[:search_on]
      @options.merge!(params.slice('src', 'dst', 'code'))
        .symbolize_keys!
    end

    # Renews the session values
    session[:detailed_report_filters] = @options
  end

  # Sets the paging and sorting settings
  def page_params
    # Update the sort and page information
    @options.merge!(params.slice('order_by', 'order_desc', 'page'))
      .symbolize_keys!
    # Save the sort information for the headers (needs to be in params)
    params.merge! @options.slice(:order_by, :order_desc)
  end

  def find_dispute
    @dispute ||= Dispute.find_by(id: params[:id])
    return unless @dispute.blank?

    flash[:notice] = _('CDR_Dispute_was_not_found')
    redirect_to(action: :list) && (return false)
  end

  def formatting_options
    @formatting ||= {
      time_format: Confline.get('time_format').try(:value) || '%M:%S',
      date_format: Confline.get('Date_format').try(:value) || '%Y-%m-%d %H:%M:%S',
      s_curr: session[:show_currency],
      d_curr: session[:default_currency],
      page_size: session[:items_per_page].to_i
    }
  end
end
