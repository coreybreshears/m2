# Tariff Import v2 Tariff Link Attachment Rules
class TariffLinkAttachmentRulesController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) }
  before_filter :authorize
  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :find_rule, only: [:edit, :update, :destroy]

  def list
    @rules = TariffLinkAttachmentRule.ordered_by_priority
  end

  def new
    @tariff_link_attachment_rule = TariffLinkAttachmentRule.new
  end

  def create
    @tariff_link_attachment_rule = TariffLinkAttachmentRule.new(params[:tariff_link_attachment_rule])

    if @tariff_link_attachment_rule.save
      flash[:status] = _('Tariff_Link_Attachment_Rules_successfully_created')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Tariff_Link_Attachment_Rules_were_not_created'), @tariff_link_attachment_rule)
      render :new
    end
  end

  def edit
  end

  def update
    if @tariff_link_attachment_rule.update_attributes(params[:tariff_link_attachment_rule])
      flash[:status] = _('Tariff_Link_Attachment_Rules_successfully_updated')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Tariff_Link_Attachment_Rules_was_not_updated'), @tariff_link_attachment_rule)
      render :edit
    end
  end

  def destroy
    if @tariff_link_attachment_rule.destroy
      flash[:status] = _('Tariff_Link_Attachment_Rules_successfully_deleted')
    else
      flash_errors_for(_('Tariff_Link_Attachment_Rules_was_not_deleted'), @tariff_link_attachment_rule)
    end
    redirect_to(action: :list)
  end

  def priority_update
    render text: TariffLinkAttachmentRule.all_priority_update(params[:priorities])
  end

  def get_priorities
    if request.xhr?
      priorities = TariffLinkAttachmentRule.select(:id, :priority).all
      render json: {data: priorities}
    else
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  private

  def find_rule
    @tariff_link_attachment_rule = TariffLinkAttachmentRule.where(id: params[:id]).first

    return if @tariff_link_attachment_rule
    flash[:notice] = _('Tariff_Link_Attachment_Rules_was_not_found')
    redirect_to(action: :list) && (return false)
  end
end
