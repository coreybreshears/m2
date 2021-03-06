# Tariff Import v2 Rate import rules
class TariffRateImportRulesController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) }
  before_filter :authorize
  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :find_tariff_rate_import_rule, only: [:edit, :update, :destroy]

  def list
    @tariff_rate_import_rules = TariffRateImportRule.order(:name).all
  end

  def new
    @tariff_rate_import_rule = TariffRateImportRule.new(zero_rate_action: 'reject rate')
  end

  def create
    @tariff_rate_import_rule = TariffRateImportRule.new(params[:tariff_rate_import_rule].merge(duplicate_rate_action: 'reject rate'))

    if @tariff_rate_import_rule.save
      flash[:status] = _('Rate_Import_Rules_successfully_created')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Rate_Import_Rules_was_not_created'), @tariff_rate_import_rule)
      render :new
    end
  end

  def edit
  end

  def update
    if @tariff_rate_import_rule.update_attributes(params[:tariff_rate_import_rule])
      flash[:status] = _('Rate_Import_Rules_successfully_updated')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Rate_Import_Rules_was_not_updated'), @tariff_rate_import_rule)
      render :edit
    end
  end

  def destroy
    if @tariff_rate_import_rule.destroy
      flash[:status] = _('Rate_Import_Rules_successfully_deleted')
    else
      flash_errors_for(_('Rate_Import_Rules_was_not_deleted'), @tariff_rate_import_rule)
    end
    redirect_to(action: :list)
  end

  private

  def find_tariff_rate_import_rule
    @tariff_rate_import_rule = TariffRateImportRule.where(id: params[:id]).first

    return if @tariff_rate_import_rule
    flash[:notice] = _('Rate_Import_Rules_was_not_found')
    redirect_to(action: :list) && (return false)
  end
end
