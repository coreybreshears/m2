# Tariff Import v2 Tariff Jobs
class TariffJobsController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) },
                except: [
                  :convert_all_assigned, :temp_import_all_converted, :all_analyze_import_by_tariff, :check_for_hanging_jobs, :do_all
                ]
  before_filter :authorize,
                except: [
                  :convert_all_assigned, :temp_import_all_converted, :all_analyze_import_by_tariff, :check_for_hanging_jobs, :do_all
                ]
  before_filter :check_post_method, only: [:destroy, :delete_all_imported]
  before_filter :find_tariff_job, only: [:destroy]

  def list
    @tariff_jobs = TariffJob.select("tariff_jobs.*, processing_tariff_jobs.id AS 'currently_processed_tariff_job_id'").
        joins("
          LEFT JOIN tariff_jobs AS processing_tariff_jobs
                    ON (
                        (SELECT tariff_id FROM tariff_import_rules WHERE id = processing_tariff_jobs.tariff_import_rule_id) = (SELECT tariff_id FROM tariff_import_rules WHERE id = tariff_jobs.tariff_import_rule_id)
                        AND processing_tariff_jobs.id != tariff_jobs.id
                        AND processing_tariff_jobs.status IN ('temp_imported', 'analyzing', 'analyzed', 'importing')
                        AND (processing_tariff_jobs.created_at < tariff_jobs.created_at OR processing_tariff_jobs.id < tariff_jobs.id)
                        AND tariff_jobs.status = 'temp_imported'
                    )
        ").
        group('tariff_jobs.id').all
  end

  def destroy
    if @tariff_job.destroy
      flash[:status] = _('Tariff_Job_successfully_deleted')
    else
      flash_errors_for(_('Tariff_Job_was_not_deleted'), @tariff_job)
    end
    redirect_to(action: :list)
  end

  def convert_all_assigned
    TariffJob.convert_all_assigned
    render nothing: true, status: 200
  end

  def temp_import_all_converted
    TariffJob.temp_import_all_converted
    render nothing: true, status: 200
  end

  def all_analyze_import_by_tariff
    TariffJob.all_analyze_import_by_tariff
    render nothing: true, status: 200
  end

  def check_for_hanging_jobs
    TariffJob.check_for_hanging_jobs
    render nothing: true, status: 200
  end

  def do_all
    TariffJob.convert_all_assigned
    TariffJob.temp_import_all_converted
    TariffJob.all_analyze_import_by_tariff
    TariffJob.check_for_hanging_jobs
    render nothing: true, status: 200
  end

  def delete_all_imported
    if TariffJob.delete_all_imported > 0
      flash[:status] = _('Imported_Tariff_Jobs_successfully_deleted')
    else
      flash[:status] = _('None_Imported_Tariff_Jobs_are_present_to_Delete')
    end

    redirect_to(action: :list)
  end

  private

  def find_tariff_job
    @tariff_job = TariffJob.where(id: params[:id]).first

    unless @tariff_job
      flash[:notice] = _('Tariff_Job_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end
end
