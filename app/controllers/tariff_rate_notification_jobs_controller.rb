# Tariff Rate Notification Jobs handling
class TariffRateNotificationJobsController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || manager?) },
                except: [
                  :do_all, :generate_data_for_all_assigned, :send_email_for_all_generated_data,
                  :agree, :disagree, :ignore_for_all_email_sent
                ]
  before_filter :authorize,
                except: [
                  :do_all, :generate_data_for_all_assigned, :send_email_for_all_generated_data,
                  :agree, :disagree, :ignore_for_all_email_sent
                ]
  before_filter :check_post_method, only: [:destroy]
  before_filter :find_tariff_rate_notification_job, only: [:download_generated_data, :destroy]

  def list
    @rate_notification_jobs = if current_user.show_only_assigned_users?
                                RateNotificationJob.joins(:user).where('users.responsible_accountant_id = ?', current_user_id).all
                              else
                                RateNotificationJob.all
                              end
  end

  def download_generated_data
    if %w[assigned generating_data].include?(@rate_notification_job.status.to_s.downcase)
      flash[:notice] = _('File_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    filename = "/tmp/m2/tariff_rate_notifications/rate_notification_data_#{@rate_notification_job.id}.xlsx"
    @rate_notification_job.generate_data_file unless File.exist?(filename)

    if File.exist?(filename)
      file_xlsx = File.open(filename).read
      send_data(file_xlsx, filename: "rate_notification_data_#{@rate_notification_job.id}.xlsx", type: 'application/octet-stream')
      cookies['fileDownload'] = 'true'
    else
      flash[:notice] = _('File_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def destroy
    if @rate_notification_job.destroy
      flash[:status] = _('Tariff_Rate_Notification_Job_successfully_deleted')
    else
      flash_errors_for(_('Tariff_Rate_Notification_Job_was_not_deleted'), @rate_notification_job)
    end

    redirect_to(action: :list)
  end

  def agree
    @rate_notification_job = RateNotificationJob.
            where(status: :email_sent, client_agreement: 0, unique_url_agree: params[:id]).
            where('agreement_timeout_datetime >= NOW()').
            first

    if @rate_notification_job
      @rate_notification_job.agreed
      flash[:status] = _('Tariff_Rate_changes_successfully_agreed')
    else
      flash[:notice] = _('Link_expired_or_does_not_exist')
    end

    if current_user
      redirect_to(:root) && (return false)
    else
      redirect_to(controller: :callc, action: :login) && (return false)
    end
  end

  def disagree
    @rate_notification_job = RateNotificationJob.
        where(status: :email_sent, client_agreement: 0, unique_url_disagree: params[:id]).
        where('agreement_timeout_datetime >= NOW()').
        first

    if @rate_notification_job
      @rate_notification_job.disagreed
      flash[:status] = _('Tariff_Rate_changes_successfully_disagreed')
    else
      flash[:notice] = _('Link_expired_or_does_not_exist')
    end

    if current_user
      redirect_to(:root) && (return false)
    else
      redirect_to(controller: :callc, action: :login) && (return false)
    end
  end

  def generate_data_for_all_assigned
    RateNotificationJob.generate_data_for_all_assigned
    render nothing: true, status: 200
  end

  def send_email_for_all_generated_data
    RateNotificationJob.send_email_for_all_generated_data
    render nothing: true, status: 200
  end

  def ignore_for_all_email_sent
    RateNotificationJob.ignore_for_all_email_sent
    render nothing: true, status: 200
  end

  def do_all
    RateNotificationJob.generate_data_for_all_assigned
    RateNotificationJob.send_email_for_all_generated_data
    RateNotificationJob.ignore_for_all_email_sent
    render nothing: true, status: 200
  end

  private

  def find_tariff_rate_notification_job
    @rate_notification_job = RateNotificationJob.where(id: params[:id]).first

    if current_user.show_only_assigned_users? && (@rate_notification_job.try(:user).try(:responsible_accountant_id).to_i != current_user_id)
      @rate_notification_job = nil
    end

    return if @rate_notification_job
    flash[:notice] = _('Tariff_Rate_Notification_Job_was_not_found')
    redirect_to(action: :list) && (return false)
  end
end
