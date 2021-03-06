# Tariff Import v2 Tariff Jobs
module TariffJobsHelper
  def tariff_jobs_json(tariff_jobs_in_page)
    result = []

    tariff_jobs_in_page.try(:each) do |tariff_job|
      result << {
        id: tariff_job.id,
        created_at: tariff_job.created_at.try(:strftime, '%Y-%m-%d %H:%M:%S'),
        status: tariff_jobs_nice_status(tariff_job.status.to_s),
        status_raw: tariff_job.status.to_s,
        status_reason: tariff_job.status_reason.to_s.gsub('"', '&quot;').gsub("'", '&#92;&#39;'),
        status_waiting_for_job_id: tariff_job.currently_processed_tariff_job_id.to_s,
        tariff_import_rule_id: tariff_job.tariff_import_rule_id,
        tariff_import_rule_name: tariff_job.tariff_import_rule.try(:name),
        target_tariff_id: tariff_job.tariff_import_rule.try(:tariff_id),
        target_tariff_name: tariff_job.tariff_import_rule.try(:tariff).try(:name),
        import_type: tariff_jobs_nice_import_type(tariff_job.tariff_import_rule.try(:import_type).to_s),
        auto: (tariff_job.tariff_import_rule.try(:manual_review).to_i == 1 ? '-' : 'Yes'),
        trigger_received_email_notification_sent:
            (tariff_job.trigger_received_email_notification_sent.to_i == 1 ? 'Yes' : '-'),
        rate_changes: (tariff_job.rate_changes.to_i + tariff_job.rejected.to_i),
        alerted: tariff_job.alerted.to_i,
        rejected: tariff_job.rejected.to_i,
        delete: 'DELETE',
        tariff_attachment_file_name: tariff_job.tariff_attachment.try(:file_name),
        tariff_rate_import_rule_id: tariff_job.tariff_import_rule.try(:tariff_rate_import_rule_id),
        tariff_rate_import_rule_name: tariff_job.tariff_import_rule.try(:tariff_rate_import_rule).try(:name),
        reviewed: tariff_job.reviewed.to_i,
        schedule_import_at: tariff_job.schedule_import_at.try(:strftime, '%Y-%m-%d %H:%M:%S'),
        show_loading_indicator: tariff_jobs_show_loading_indicator_by_status(tariff_job.status.to_s)
      }
    end

    result.to_json.html_safe
  end

  def tariff_jobs_nice_import_type(import_type)
    case import_type
    when 'add_update'
      'Update'
    when 'replace'
      'Full'
    else
      ''
    end
  end

  def tariff_jobs_nice_status(status)
    case status
      when 'temp_importing'
        _('Importing_into_Temporary_Table')
      when 'temp_imported'
        _('Preparing_to_analyze')
      when 'failed_temp_import'
        _('Failed_to_Import_into_Temporary_Table')
      when 'assigned'
        _('Preparing_to_convert')
      when 'converted'
        _('Preparing_for_import')
      when 'analyzed'
        _('Import_in_Progress')
      else
        status.titleize
    end
  end

  def tariff_jobs_show_loading_indicator_by_status(status)
    loading_indicator_statuses = %w[assigned converting converted temp_importing temp_imported analyzing analyzed importing]
    loading_indicator_statuses.include?(status) ? 1 : 0
  end
end
