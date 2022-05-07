# Tariff Rate Notification Jobs Helper
module TariffRateNotificationJobsHelper
  def tariff_rate_notification_jobs_json(tariff_rn_jobs_in_page)
    result = []

    tariff_rn_jobs_in_page.try(:each) do |tariff_rn_job|
      result << {
          id: tariff_rn_job.id,
          created_at: tariff_rn_job.created_at.try(:strftime, '%Y-%m-%d %H:%M:%S'),
          status: tariff_rn_jobs_nice_status(tariff_rn_job.status.to_s),
          tariff_id: tariff_rn_job.tariff_id,
          tariff_name: tariff_rn_job.try(:tariff).try(:name),
          user_id: tariff_rn_job.user_id,
          user_name: tariff_rn_job.try(:user).try(:nice_user),
          rate_notification_template_id: tariff_rn_job.rate_notification_template_id,
          rate_notification_template_name: tariff_rn_job.try(:rate_notification_template).try(:name).to_s,
          email_id: tariff_rn_job.email_id,
          email_name: tariff_rn_job.try(:email).try(:name),
          rate_notification_type: tariff_rn_jobs_nice_rn_type(tariff_rn_job.rate_notification_type),
          agreement_timeout_datetime: tariff_rn_job.agreement_timeout_datetime.try(:strftime, '%Y-%m-%d %H:%M:%S'),
          send_email: (tariff_rn_job.send_once.to_i == 1) ? _('Once') : _('Every_day'),
          client_agreement: tariff_rn_jobs_nice_client_agreement(tariff_rn_job.client_agreement),
          client_agreement_datetime: tariff_rn_job.client_agreement_datetime.try(:strftime, '%Y-%m-%d %H:%M:%S').to_s,
          delete: 'DELETE'
      }
    end

    result.to_json.html_safe
  end

  def tariff_rn_jobs_nice_rn_type(rn_type)
    case rn_type
      when 0
        _('Delta_Only')
      when 1
        _('Full')
      else
        ''
    end
  end

  def tariff_rn_jobs_nice_client_agreement(client_agreement_value)
    case client_agreement_value
      when 0
        _('No_Response')
      when 1
        _('Agreed')
      when 2
        _('Disagreed')
      when 3
        _('Ignored')
      else
        ''
    end
  end

  def tariff_rn_jobs_nice_status(status)
    case status
      when 'temp_importing'
        _('Importing_into_Temporary_Table')
      else
        status.titleize
    end
  end
end
