# Tariff Rate Notification creation
class TariffRateNotificationsController < ApplicationController
  layout :determine_layout
  before_filter :access_denied, if: -> { !(admin? || manager?) }
  before_filter :authorize

  def list
    @tariffs_users = Tariff.all_for_rate_notification_list(current_user)
  end

  def new
    selected_tariff_user_ids = params[:tariff_user_ids]
    if selected_tariff_user_ids.blank?
      flash[:notice] = _('At_least_one_Tariff_User_association_must_be_selected')
      redirect_to(action: :list) && (return false)
    end

    @selected_tariffs_users = selected_tariffs_users_nice_list(selected_tariff_user_ids)
  end

  def create
    selected_tariff_user_ids = params[:tariff_user_ids]
    if selected_tariff_user_ids.blank?
      flash[:notice] = _('At_least_one_Tariff_User_association_must_be_selected')
      redirect_to(action: :list) && (return false)
    end

    errors = []
    email_id = params[:tariff_rate_notification_job_options][:email_id]
    rate_notification_type = params[:tariff_rate_notification_job_options][:rate_notification_type]
    agreement_timeout_days = params[:tariff_rate_notification_job_options][:agreement_timeout_days].to_i
    send_once = params[:tariff_rate_notification_job_options][:send_once].to_i
    #show_destination_group = params[:tariff_rate_notification_job_options][:show_destination_group].to_i if m4_functionality?
    rate_notification_template_id = params[:tariff_rate_notification_job_options][:rate_notification_template_id].to_i

    Confline.set_value('tariff_rate_notification_sending_options_email_template_id', email_id)
    Confline.set_value('tariff_rate_notification_sending_options_rate_notification_type', rate_notification_type)
    Confline.set_value('tariff_rate_notification_sending_options_agreement_timeout_days', agreement_timeout_days)
    Confline.set_value('tariff_rate_notification_sending_options_send_once', send_once)
    #Confline.set_value('tariff_rate_notification_sending_options_show_destination_group', show_destination_group) if m4_functionality?
    Confline.set_value('tariff_rate_notification_sending_options_rate_notification_template_id', rate_notification_template_id)

    if agreement_timeout_days < 1
      errors << _('Agreement_Timeout_must_be_greater_than_or_equal_to_1')
    end

    if errors.blank?
      selected_tariffs_users_create_jobs(selected_tariff_user_ids, params[:tariff_rate_notification_job_options])

      flash[:status] = _('Tariff_Rate_Notification_Jobs_successfully_created')
      redirect_to(controller: :tariff_rate_notification_jobs, action: :list) && (return false)
    else
      flash_array_errors_for(_('Tariff_Rate_Notification_Jobs_was_not_created'), errors)
      redirect_to(action: :new, tariff_user_ids: params[:tariff_user_ids]) && (return false)
    end
  end

  private

  def selected_tariffs_users_nice_list(tariff_user_ids)
    tariff_users = {}

    tariff_user_ids = tariff_user_ids.keys
    return tariff_users if tariff_user_ids.blank?

    tariff_user_ids.each do |tariff_user|
      tariff_id, user_id = tariff_user.split('-')

      unless tariff_users.key?(tariff_id)
        tariff = Tariff.where(id: tariff_id, owner_id: corrected_user_id).first
        next if tariff.blank?
        tariff_users[tariff_id] = {tariff_name: tariff.name, assigned_users: []}
      end

      user = if current_user.show_only_assigned_users?
               User.where(id: user_id, owner_id: corrected_user_id, responsible_accountant_id: current_user_id).first
             else
               User.where(id: user_id, owner_id: corrected_user_id).first
             end

      next if user.blank?
      tariff_users[tariff_id][:assigned_users] << {id: user_id, name: user.nice_user}
    end

    tariff_users
  end

  def selected_tariffs_users_create_jobs(tariff_user_ids, tariff_rate_notification_job_options)
    tariff_user_ids = tariff_user_ids.keys
    return false if tariff_user_ids.blank?

    email_id = tariff_rate_notification_job_options[:email_id].to_i
    email = Email.where(id: email_id).first
    return false if email.blank?

    rate_notification_type = tariff_rate_notification_job_options[:rate_notification_type].to_i
    return false unless [0, 1].include?(rate_notification_type)

    agreement_timeout_days = tariff_rate_notification_job_options[:agreement_timeout_days].to_i
    return false if agreement_timeout_days < 1

    tariff_user_ids.each do |tariff_user|
      tariff_id, user_id = tariff_user.split('-')

      tariff = Tariff.where(id: tariff_id, owner_id: corrected_user_id).first
      next if tariff.blank?

      user = if current_user.show_only_assigned_users?
               User.where(id: user_id, owner_id: corrected_user_id, responsible_accountant_id: current_user_id).first
             else
               User.where(id: user_id, owner_id: corrected_user_id).first
             end
      next if user.blank?

      rate_notification_template = RateNotificationTemplate.where(id: tariff_rate_notification_job_options[:rate_notification_template_id].to_i).first
      user_rate_notification_template = RateNotificationTemplate.where(id: user.rate_notification_template_id.to_i).first
      rate_notification_template = user_rate_notification_template if user_rate_notification_template.present?
      next if rate_notification_template.blank?

      rnj = RateNotificationJob.new(
          created_at: Time.now,
          status: 'Assigned',
          status_reason: '',
          tariff_id: tariff_id,
          user_id: user_id,
          email_id: email_id,
          rate_notification_type: rate_notification_type,
          agreement_timeout: agreement_timeout_days,
          agreement_timeout_datetime: (Time.now + agreement_timeout_days.days),
          client_agreement: 0,
          send_once: tariff_rate_notification_job_options[:send_once],
          show_destination_group: 1, #(m4_functionality? ? tariff_rate_notification_job_options[:show_destination_group] : 1).to_i,
          rate_notification_template_id: rate_notification_template.id
      )

      rnj.save
    end
  end
end
