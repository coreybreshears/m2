# -*- encoding : utf-8 -*-

# MOR Provider Deviations controller. Part of a Monitorings Addon.
class TpDeviationsController < ApplicationController
  layout 'm2_admin_layout'

  before_action :authorize, :check_localization, :not_authorized, except: %i(report_deviations)
  before_action :access_denied, unless: -> { admin? || manager? }, except: %i(report_deviations)
  before_action :find_tp_deviation, only: %i(details edit destroy update)
  before_action :find_main_tp, only: %i(details)
  before_action :formatting_options, only: %i(details)
  before_action :find_dps, only: %i(new)
  before_action :find_dp, only: %i(edit update details)
  before_action :check_post_method, only: %i(destroy create update)

  def list
    @tp_deviations = TpDeviation.order('id DESC')
  end

  def new
    @tp_deviation = TpDeviation.new
    form_data
  end

  def create
    @tp_deviation = TpDeviation.new(permitted_params)
    if @tp_deviation.save
      flash[:status] = _('TP_Deviation_Observer_created')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('TP_Deviation_Observer_not_created'), @tp_deviation)
      form_data
      render :new
    end
  end

  def edit
    form_data
  end

  def update
    if @tp_deviation.update_attributes(permitted_params)
      flash[:status] = _('TP_Deviation_Observer_updated')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('TP_Deviation_Observer_not_updated'), @tp_deviation)
      form_data
      render :edit
    end
  end

  def destroy
    if @tp_deviation.destroy
      flash[:status] = _('TP_Deviation_Observer_deleted')
    else
      flash[:notice] = _('TP_Deviation_Observer_not_deleted')
    end
    redirect_to(action: :list) && (return false)
  end

  def details
    @report = @tp_deviation.deviation_report
  end

  def report_deviations
    return render nothing: true, status: 403 unless request.local?
    send_warning_emails(TpDeviation.generate_emails.reject(&:nil?))
    render nothing: true, status: 200
  end

  private

  # Send all warning emails to all addresses
  def send_warning_emails(emails)
    return if Confline.get_value('Email_Sending_Enabled', 0).to_i.zero? || emails.empty?
    options = Email.smtp_options

    emails.each do |email|
      email_data = email[:email]
      # Send to all email addresses
      email[:to].each do |to|
        next if defined?(NO_EMAIL) && NO_EMAIL.to_i == 1
        # Send an email
        system(
          ApplicationController.send_email_dry(
            options[:from], to, nice_email_sent(email_data, email[:variables]),
            nice_email_sent(email_data, email[:variables], 'subject'), '', options[:connection], email_data[:format]
          )
        )
      end
    end
  end

  # Params permitted for mass assignment
  def permitted_params
    params[:tp_deviation][:user_id] = params[:s_user_id]
    params.require(:tp_deviation)
      .permit(:device_id, :check_period, :check_since, :asr_deviation,
              :acd_deviation, :user_id, :email_id, :dial_peer_id)
  end

  # Finds a deviation observer due to an id passed as an HTTP parameter
  def find_tp_deviation
    @tp_deviation ||= TpDeviation.find_by(id: params[:id])
    return unless @tp_deviation.blank?

    flash[:notice] = _('TP_Deviation_Observer_not_found')
    redirect_to(action: :list) && (return false)
  end

  # Finds a main provider in case some associations have changed
  def find_main_tp
    @tp_deviation ||= TpDeviation.find_by(id: params[:id])
    return if @tp_deviation.try(:main_active?) && @tp_deviation.device
    flash[:notice] = _('tp_not_found')
    redirect_to(action: :list) && (return false)
  end

  def find_dps
    return if DialPeer.where(active: 1).count > 0
    flash[:notice] = _('no_active_dp_found')
    redirect_to(action: :list) && (return false)
  end

  def find_dp
    @tp_deviation ||= TpDeviation.find_by(id: params[:id])
    return if @tp_deviation.try(:dial_peer).present?
    flash[:notice] = _('dial_peer_not_found')
    redirect_to(action: :list) && (return false)
  end

  # Retrieves formatting options used in views
  def formatting_options
    @formatting ||= {time_format: Confline.get('time_format').try(:value) || '%M:%S'}
  end

  # Gathers data used in form inputs
  def form_data
    # Retrieves all the active dps
    @dps = DialPeer.where(active: 1).order(:name).pluck(:name, :id).map { |dp| [dp[0], dp[1]] }
    # Retrieves all the email templates owned by the administrator
    @emails = Email.where(owner_id: 0).order(:name).pluck(:name, :id).map { |em| [em[0], em[1]] }
    # Retrieves all the active tps in the dp
    @tps = @tp_deviation.tps.sort_by(&:nice_name).map { |tp| [tp.nice_name, tp.id] }
  end

  # Pages can only be reached with several additional permission
  def not_authorized
    return unless manager?
    return if authorize_manager_permissions(controller: :dial_peers, action: :list, no_redirect_return: 1) &&
              authorize_manager_permissions(controller: :users, action: :list, no_redirect_return: 1) &&
              authorize_manager_permissions(controller: :emails, action: :list, no_redirect_return: 1)
    flash[:notice] = _('You_are_not_authorized_to_view_this_page')
    redirect_to(:root) && (return false)
  end
end