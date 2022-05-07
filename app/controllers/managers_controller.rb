# -*- encoding : utf-8 -*-
# M2 Managers (Administrator's helpers)
class ManagersController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !admin? }
  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :find_manager, only: [:edit, :update, :destroy, :gdpr_agreed_manager_details]
  before_filter :form_additional_data, only: [:new, :create, :edit, :update]

  def list
    @options = session[:managers] = load_params_to_session(session[:managers])

    if [:order_by, :order_desc].any? { |key| @options[key].blank? }
      @options[:order_by], @options[:order_type], @options[:order_desc] = 'nice_user', 'asc', '0'
    end

    params.reverse_update(@options.slice(:order_desc, :order_by))
    @managers = Manager.find_managers(@options)
    @managers = @managers.page(params[:page]).per(session[:items_per_page])
  end

  def new
    unless ManagerGroup.any?
      flash[:notice] = _('at_least_one_manager_group_must_exist')
      flash[:redirected_from] = 'manager_list'
      redirect_to(controller: :manager_groups, action: :list) && (return false)
    end
    @manager = Manager.new
  end

  def create
    @manager = Manager.new(params[:manager])
    if @manager.save
      flash[:status] = _('Manager_created')
      redirect_to action: :list
    else
      flash_errors_for(_('Manager_not_created'), @manager)
      render :new
    end
  end

  def gdpr_agreed_manager_details
    Action.add_action_hash(
        current_user, {action: 'GDPR_Agreed_manager_details', target_id: @manager.id, target_type: 'manager'}
    )
    session["gdpr_agreed_manager_details_#{@manager.id}"] = true
    render layout: false, nothing: true
  end

  def edit
  end

  def update
    if @manager.update_attributes(params[:manager])
      flash[:status] = _('Manager_updated')
      redirect_to action: :list
    else
      flash_errors_for(_('Manager_not_updated'), @manager)
      render :edit
    end
  end

  def destroy
    if @manager.destroy
      flash[:status] = _('Manager_deleted')
    else
      flash_errors_for(_('Manager_not_deleted'), @manager)
    end
    redirect_to action: :list
  end

  private

  def find_manager
    @manager = Manager.where(id: params[:id]).first
    unless @manager
      flash[:notice] = _('Manager_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def form_additional_data
    @form_data = {
      manager_groups: ManagerGroup.all,
      active_currencies: Currency.get_active,
      time_zones: ActiveSupport::TimeZone.all
    }
  end
end
