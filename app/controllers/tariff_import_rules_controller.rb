# Tariff Import v2 rules
class TariffImportRulesController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) }
  before_filter :authorize
  before_filter :check_post_method, only: [:create, :update, :destroy, :change_status, :priority_update]
  before_filter :find_tariff_import_rule, only: [:edit, :update, :destroy, :change_status]

  def list
    @tariff_import_rules = TariffImportRule.order(:priority).all
  end

  def new
    @tariff_import_rule = TariffImportRule.new(
        mail_sender: '%', mail_subject: '%', mail_text: '%', file_name: '%',
        reject_if_errors: 0, stop_processing_more_rules: 1, effective_date_timezone: current_user.time_zone.to_s
    )
  end

  def create
    @tariff_import_rule = TariffImportRule.new(params[:tariff_import_rule])

    if @tariff_import_rule.save
      flash[:status] = _('Tariff_Import_Rules_successfully_created')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Tariff_Import_Rules_were_not_created'), @tariff_import_rule)
      render :new
    end
  end

  def edit
    if @tariff_import_rule.active_tariff_jobs_present?
      flash[:warning] = _('Tariff_Job_is_currently_being_processed_with_this_Tariff_Import_Rule_some_settings_are_disabled')
    end
  end

  def update
    if @tariff_import_rule.active_tariff_jobs_present?
      flash[:warning] = _('Tariff_Job_is_currently_being_processed_with_this_Tariff_Import_Rule_some_settings_are_disabled')
    end

    if @tariff_import_rule.update_attributes(params[:tariff_import_rule])
      flash[:status] = _('Tariff_Import_Rules_successfully_updated')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Tariff_Import_Rules_were_not_updated'), @tariff_import_rule)
      render :edit
    end
  end

  def destroy
    if @tariff_import_rule.destroy
      flash[:status] = _('Tariff_Import_Rules_successfully_deleted')
    else
      flash_errors_for(_('Tariff_Import_Rules_were_not_deleted'), @tariff_import_rule)
    end
    redirect_to(action: :list)
  end

  def change_status
    @tariff_import_rule.change_status
    flash[:status] = _('Tariff_Import_Rules_Active_Status_successfully_changed')
    redirect_to action: :list
  end

  def priority_update
    render text: TariffImportRule.all_priority_update(params[:priorities])
  end

  private

  def find_tariff_import_rule
    @tariff_import_rule = TariffImportRule.where(id: params[:id]).first

    unless @tariff_import_rule
      flash[:notice] = _('Tariff_Import_Rules_were_not_found')
      redirect_to(action: :list) && (return false)
    end
  end
end
