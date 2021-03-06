# M4 Disconnect codes
class DisconnectCodesController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, unless: -> { admin? && m4_functionality? }
  before_filter :check_post_method, only: [:add_new_group, :update_group,
    :delete_group, :delete_code, :reset_global_code, :reset_to_defaults]
  before_filter :check_if_request_ajax, only: [:get_codes_ajax, :update_code_data_ajax, :reset_global_code,
    :delete_code]
  before_action :check_for_resetable_groups, only: [:reset_to_defaults]
  before_action :check_for_editable_groups, only: [:update_group, :delete_group]
  before_action :set_dc_group, only: [:list]

  def list
    @list_data = DisconnectCode.list_data(dc_group_id: @dc_group_id)
  end

  def get_codes_ajax
    @disconnect_codes = DisconnectCode.get_codes(params[:dc_group_id].to_i)
    session[:dc_group_id] = params[:dc_group_id].to_i
    @dc_group_id = session[:dc_group_id]
    respond_to { |format| format.js }
  end

  def update_code_data_ajax
    @code = DisconnectCode.update_code(params[:code].to_i, params[:dc_group_id].to_i, params[:data])
    session[:dc_group_id] = params[:dc_group_id].to_i
    @dc_group_id = session[:dc_group_id]
    respond_to { |format| format.js {render 'update_row_ajax.js.erb'} }
  end

  def reset_to_defaults
    group_was_reset = @group.reset_to_defaults
    if group_was_reset
      flash[:status] = _('Disconnect_group_was_reset')
    else
      flash[:notice] = _('Disconnect_group_was_not_reset')
    end
    redirect_to(action: :list) && (return false)
  end

  def reset_global_code
    @code = DisconnectCode.global.where(code: params[:code].to_i).first
    @code.reset_global_to_default
    @dc_group_id = session[:dc_group_id]
    respond_to { |format| format.js {render 'update_row_ajax.js.erb'} }
  end

  def add_new_group
    @new_group = DcGroup.new(name: params[:group_name].to_s)
    if @new_group.save
      flash[:status] = _('Disconnect_group_was_successfully_created')
      session[:dc_group_id] = @new_group.id
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('Disconnect_group_was_not_created'), @new_group)
      @dc_group_id = session[:dc_group_id]
      @list_data = DisconnectCode.list_data(dc_group_id:  @dc_group_id)
      render(action: :list) && (return false)
    end
  end

  def update_group
    @group.name = params[:group_name].to_s
    if @group.save
      flash[:status] = _('Disconnect_group_was_successfully_updated')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('Disconnect_group_was_not_updated'), @group)
      @dc_group_id = session[:dc_group_id]
      @list_data = DisconnectCode.list_data(dc_group_id: @dc_group_id)
      render(action: :list) && (return false)
    end
  end

  def delete_group
    if @group.destroy
      session[:dc_group_id] = 2
      flash[:status] = _('Disconnect_group_was_successfully_deleted')
    else
      flash[:notice] = _('Disconnect_group_was_not_deleted')
    end
    redirect_to(action: :list) && (return false)
  end

  def delete_code
    code = DisconnectCode.where(id: params[:id]).first

    if code.present? && code.dc_group_id > 2
      @dc_group_id = session[:dc_group_id]

      if code.destroy
        @code = DisconnectCode.global.where(code: code.code).first
        DcGroup.where(id: @dc_group_id).first.changes_present_set_1
      else
        @code = code
      end

      respond_to { |format| format.js {render 'update_row_ajax.js.erb'} }
    else
      error = {message: _('Disconnect_code_was_not_found')}
      respond_to { |format| format.json { render json: error } }
    end
  end

  private

  def check_for_resetable_groups
    @group = DcGroup.where(id: params[:id].to_i).first
    return if @group.present? && @group.id > 1
    flash[:notice] = _('Disconnect_group_was_not_found')
    redirect_to(action: :list) && (return false)
  end

  def check_for_editable_groups
    @group = DcGroup.where(id: params[:id].to_i).first
    return if @group.present? && @group.id > 2
    flash[:notice] = _('Disconnect_group_was_not_found')
    redirect_to(action: :list) && (return false)
  end

  def check_if_request_ajax
    unless request.xhr?
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to(:root) && (return false)
    end
  end

  def set_dc_group
    session[:dc_group_id] = params[:dc_group_id] if params[:dc_group_id].present?
    @dc_group_id = session[:dc_group_id].present? ? session[:dc_group_id].to_i : 2
  end
end
