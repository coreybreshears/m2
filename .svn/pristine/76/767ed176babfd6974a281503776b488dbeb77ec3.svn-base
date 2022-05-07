# M2 aggregate Export controller.
class AggregateExportController < ApplicationController
  layout :determine_layout

  before_action :check_localization
  before_action :authorize

  before_action :prepare_attributes_from_params, only: %i[create update]
  before_action :find_agg_export, only: %i[edit update destroy]
  before_action :set_edit_options, only: %i[edit]
  before_action :check_post_method, only: %i[create update]

  def index
    @page_title = _('Aggregate_Templates')
    @page_icon = 'excel.png'

    @agg_exports = AutoAggregateExport.where(owner_id: current_user.id)
  end

  def edit
    @page_title = _('Blank_edit')
    @page_icon = 'edit.png'
  end

  def new
    @page_title = _('New_Aggregate_Template')
    @page_icon = 'add.png'
    @auto_aggregate_export = AutoAggregateExport.new
    set_initialize_options
  end

  def create
    @auto_aggregate_export = AutoAggregateExport.new(@attributes)
    @auto_aggregate_export.last_run_at = @auto_aggregate_export.from
    safe_save 'created' do
      set_edit_options
      render(:new) && (return false)
    end
    AggregateExportRuns.new(@auto_aggregate_export).set_run_at
    redirect_to(action: :index) && (return false)
  end

  def update
    @auto_aggregate_export.update(@attributes)
    safe_save 'updated' do
      set_edit_options
      render(:edit) && (return false)
    end
    AggregateExportRuns.new(@auto_aggregate_export).set_run_at
    redirect_to(action: :index) && (return false)
  end

  def destroy
    safe_destroy
    redirect_to(action: :index) && (return false)
  end

  private

  def set_initialize_options
    @options = {
      s_user_id: -2,
      s_user: '',
      from: Time.now.at_beginning_of_day,
      till: Time.now.at_end_of_day
    }
    @auto_aggregate_export.frequency = nil
    @auto_aggregate_export.period = nil
  end

  def set_edit_options
    @options = {
      s_user_id: @auto_aggregate_export.user_id || -2,
      s_user: User.where(id: @auto_aggregate_export.user_id).first.try(:nice_user),
      from: @auto_aggregate_export.from,
      till: @auto_aggregate_export.till
    }
  end

  def prepare_attributes_from_params
    @attributes = params[:auto_aggregate_export]
    @attributes.merge!(
      from: to_default_date(params[:date_from] + ' ' + params[:time_from]).to_time,
      till: to_default_date(params[:date_till] + ' ' + params[:time_till]).to_time,
      user_id: params[:s_user_id],
      owner_id: current_user.id
    )
  end

  def safe_save(action_name)
    if @auto_aggregate_export.save
      flash[:status] = _("Auto_Aggregate_Export_successfully_#{action_name}")
    else
      flash_errors_for(_("Auto_Aggregate_Export_was_not_#{action_name}"), @auto_aggregate_export)
      yield
    end
  end

  def find_agg_export
    @auto_aggregate_export = AutoAggregateExport.where(id: params[:id], owner_id: current_user.id).first
    return if @auto_aggregate_export
    flash[:notice] = _('Automatic_Aggregate_Export_was_not_found')
    redirect_to(action: :index) && (return false)
  end

  def safe_destroy
    if @auto_aggregate_export.destroy
      flash[:status] = _('Auto_Aggregate_Export_successfully_deleted')
    else
      flash_errors_for(_('Auto_Aggregate_Export_was_not_deleted'), @template)
    end
  end
end
