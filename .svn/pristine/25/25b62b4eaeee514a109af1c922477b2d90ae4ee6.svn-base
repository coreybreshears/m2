# Mnp Carrier Groups
class MnpCarrierGroupsController < ApplicationController
  layout :determine_layout

  before_filter :check_post_method, only: [:create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :access_denied, unless: :mnp_active?
  before_filter :set_mnp_carrier_params, only: [:list, :create]
  before_filter :find_carrier_group, only: [:edit, :destroy, :update]
  before_filter :check_if_request_ajax, only: [:get_carrier_codes, :create_carrier_code, :delete_carrier_code]

  def list
  end

  def create
    carrier_group = MnpCarrierGroup.new(name: params[:name].to_s)
    if carrier_group.save
      flash[:status] = _('MNP_Carrier_Group_successfully_created')
      redirect_to(action: :edit, id: carrier_group.id) && (return false)
    else
      flash_errors_for(_('MNP_Carrier_Group_was_not_created'), carrier_group)
      render :list
    end
  end

  def edit
  end

  def update
    @group.name = params[:name].to_s
    if @group.save
      flash[:status] = _('MNP_Carrier_Group_successfully_updated')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('MNP_Carrier_Group_was_not_updated'), @group)
      render :edit
    end
  end

  def destroy
    if @group.destroy
      flash[:status] = _('MNP_Carrier_Group_successfully_deleted')
    else
      flash_errors_for(_('MNP_Carrier_Group_was_not_deleted'), @group)
    end

    redirect_to(action: :list) && (return false)
  end

  def get_carrier_codes
    group = MnpCarrierGroup.where(id: params[:id]).first
    codes = group.try(:mnp_carrier_codes)

    respond_to do |format|
      format.json { render(json: codes) }
    end
  end

  def create_carrier_code
    carrier_code = MnpCarrierCode.new(code: params[:code], mnp_carrier_group_id: params[:id].to_i)
    response = {status: 0}
    if carrier_code.save
      response[:msg] = _('MNP_Carrier_Code_successfully_created')
    else
      response[:status] = 1
      response[:msg] = _('MNP_Carrier_Code_was_not_created')
      response[:errors] = carrier_code.errors
    end
    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  def delete_carrier_code
    code = MnpCarrierCode.where(id: params[:id].try(:to_i)).first

    response = {status: 0}
    if code && code.destroy
      response[:msg] = _('MNP_Carrier_Code_successfully_deleted')
    else
      response[:msg] =  _('MNP_Carrier_Code_was_not_deleted')
      response[:status] = 1
    end

    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  private

  def set_mnp_carrier_params
    @carriers = {
      groups: MnpCarrierGroup.all,
      name: params[:name].present? ? params[:name].to_s : ''
    }
  end

  def find_carrier_group
    @group = MnpCarrierGroup.where(id: params[:id]).first
    if @group.blank?
      flash[:notice] = _('MNP_Carrier_Group_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def mnp_active?
    Confline.get_value('Use_Number_Portability', 0, 0).to_i == 1
  end

  def check_if_request_ajax
    unless request.xhr?
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to(:root) && (return false)
    end
  end
end
