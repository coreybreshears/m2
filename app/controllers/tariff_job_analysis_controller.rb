# Tariff Import v2 Tariff Job Analysis
class TariffJobAnalysisController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) }
  before_filter :authorize
  before_filter :check_post_method, only: [:confirm, :schedule_confirm, :cancel]
  before_filter :find_tariff_job, only: [:list, :confirm, :schedule_confirm, :cancel]

  def list
    check_tariff_job_status(@tariff_job)
    @tariff_job.alter_tmp_table_for_new_columns
    set_session_variables
    results = @tariff_job.tariff_job_analysis_results(params)
    @analysis_results = Kaminari.paginate_array(results.to_a).page(params[:page] ||= 1).per(session[:items_per_page])

    if params[:csv].to_i == 1
      filename = tariff_job_analysis_download_table_csv(results)
      filename = archive_file_if_size(filename, 'csv', Confline.get_value('CSV_File_size').to_d)

      cookies['fileDownload'] = 'true'
      send_data(File.open(filename).read, filename: filename.sub('/tmp/', ''))
    end
  end

  def confirm
    @tariff_job.confirm
    flash[:status] = _('Tariff_Job_was_successfully_confirmed')
    redirect_to(controller: :tariff_jobs, action: :list) && (return false)
  end

  def schedule_confirm
    @tariff_job.confirm("#{params[:date]} #{params[:time]}:00")
    flash[:status] = _('Tariff_Job_was_successfully_confirmed_and_scheduled')
    redirect_to(controller: :tariff_jobs, action: :list) && (return false)
  end

  def cancel
    @tariff_job.cancel
    flash[:status] = _('Tariff_Job_was_successfully_cancelled')
    redirect_to(controller: :tariff_jobs, action: :list) && (return false)
  end

  private

  def check_tariff_job_status(tariff_job)
    unless %w[analyzed rejected cancelled importing imported failed_import].include?(tariff_job.status)
      flash[:notice] = _('Tariff_Job_Analysis_results_does_not_exist')
      redirect_to(controller: :tariff_jobs, action: :list) && (return false)
    end
  end

  def find_tariff_job
    @tariff_job = TariffJob.where(id: params[:id]).first

    unless @tariff_job
      flash[:notice] = _('Tariff_Job_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def set_session_variables
    session[:tariff_job_analysis_search] = params[:search] if params[:search].present?
    session[:tariff_job_analysis_search] = { show_only: { rejected: 2 } } if params[:clear].present? || session[:tariff_job_analysis_search].blank?
    params[:search] = session[:tariff_job_analysis_search] || {}
  end

  def tariff_job_analysis_download_table_csv(results)
    require 'csv'

    filename = 'Tariff_Job_Analysis'
    sep, dec = current_user.csv_params

    CSV.open('/tmp/' + filename + '.csv', 'w', {col_sep: sep, quote_char: "\""}) do |csv|
      headers = [
          _('Prefix'), _('Destination'), _('Rate'), _('Connection_Fee'), _('Increment'), _('Min_Time'),
          _('Effective_From'), _('Blocked'), _('Deleted'), _('Reason')
      ]

      csv << headers

      results.each do |result|
        result_reasons = TariffJob.tariff_job_analysis_result_reason(result, true).
            map { |key, value| "#{value[0]}: #{value[1]}" }.join('; ')

        data_line = [
            result['prefix'],
            result['destination'],
            result['rate'].to_f.to_s.gsub('.', dec),
            result['connection_fee'].to_f.to_s.gsub('.', dec),
            result['increment'],
            result['min_time'],
            nice_date_time(result['effective_from']),
            (result['blocked'].to_i == 0 ? _('No') : _('Yes')),
            (result['deleted'].to_i == 0 ? _('No') : _('Yes')),
            result_reasons
        ]

        csv << data_line
      end
    end

    filename
  end
end
