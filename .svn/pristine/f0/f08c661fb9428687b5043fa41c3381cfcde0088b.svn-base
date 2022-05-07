# M2 Managers' Groups (Administrator's helpers)
class ManagerGroupsController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !admin? }
  before_filter :check_post_method, only: [:destroy]
  before_filter :find_manager_group, only: [:edit, :update, :destroy]

  def list
    @manager_groups = ManagerGroup.order('name asc').all
  end

  def new
    flash[:status] = 'Add New Manager Group still in progress...'
    redirect_to action: :list
  end

  def create
    manager_group = ManagerGroup.new(params[:new_manager_group])
    if manager_group.save
      # manager_group.create_permissions
      flash[:status] = _('Manager_Group_successfully_created')
      close_m2_form(:manager_groups)
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('Manager_Group_not_created'), manager_group)
    end
    redirect_to action: :list, new_manager_group: params[:new_manager_group]
  end

  def edit
    possible_rights = ManagerRight.select('name, 0 AS value, id').order(:nice_name).all
    @rights = if params[:rights]
                params[:rights].map { |name, value| {name: name, value: value} }.reverse
              else
                @manager_group.manager_group_rights
                              .select('manager_rights.name AS name, manager_group_rights.value AS value')
                              .joins('JOIN manager_rights ON manager_rights.id = manager_group_rights.manager_right_id')
              end
    @rights = possible_rights.map do |pr|
      {name: pr.name, value: @rights.select { |right| right[:name].to_s == pr.name.to_s }.first.try(:value).to_i}
    end

    @manager_group.assign_attributes(params[:manager_group])
  end

  def update
    @manager_group.assign_attributes(params[:manager_group])
    if @manager_group.save
      @manager_group.update_rights(params[:permissions])
      flash[:status] = _('Manager_Group_successfully_updated')
      redirect_to action: :list
    else
      flash_errors_for(_('Manager_Group_not_updated'), @manager_group)
      redirect_to action: :edit, id: params[:id].to_i, manager_group: params[:manager_group], rights: params[:permissions]
    end
  end

  def destroy
    if @manager_group.destroy
      flash[:status] = _('Manager_Group_deleted')
    else
      flash_errors_for(_('Manager_Group_not_deleted'), @manager_group)
    end
    redirect_to action: :list
  end

  private

  def find_manager_group
    @manager_group = ManagerGroup.where(id: params[:id]).first
    return if @manager_group
    flash[:notice] = _('Manager_Group_not_found')
    redirect_to(action: :list) && (return false)
  end
end
