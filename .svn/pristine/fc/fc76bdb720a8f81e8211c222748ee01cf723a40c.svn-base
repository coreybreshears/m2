# Tariff Import v2 Templates
class TariffTemplatesController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) }
  before_filter :authorize
  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :find_tariff_template, only: [:edit, :update, :destroy]

  def list
    @tariff_templates = TariffTemplate.order(:name).all
  end

  def new
    @tariff_template = TariffTemplate.new
  end

  def create
    @tariff_template = TariffTemplate.new(params[:tariff_template])

    if @tariff_template.save
      flash[:status] = _('Template_successfully_created')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Template_was_not_created'), @tariff_template, %w[tariff_template_exceptions])
      render :new
    end
  end

  def edit
  end

  def update
    if @tariff_template.update_attributes(params[:tariff_template])
      flash[:status] = _('Template_successfully_updated')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Template_was_not_updated'), @tariff_template, %w[tariff_template_exceptions])
      render :edit
    end
  end

  def destroy
    if @tariff_template.destroy
      flash[:status] = _('Template_successfully_deleted')
    else
      flash_errors_for(_('Template_was_not_deleted'), @tariff_template, %w[tariff_template_exceptions])
    end
    redirect_to(action: :list)
  end

  private

  def find_tariff_template
    @tariff_template = TariffTemplate.where(id: params[:id]).first

    unless @tariff_template
      flash[:notice] = _('Template_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end
end
