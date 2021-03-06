# M2 aggregate templates controller.
class AggregateTemplatesController < ApplicationController
  layout :determine_layout

  before_action :check_localization
  before_action :authorize
  before_action :find_template, only: %i[destroy edit update]
  before_action :set_attributes, only: %i[create update]
  before_action :check_post_method, only: %i[create update]

  def index
    @page_title = _('Aggregate_Templates')
    @page_icon = 'excel.png'

    @templates = AggregateTemplate.where(user_id: current_user_id)
  end

  def new
    @page_title = _('New_Aggregate_Template')
    @page_icon = 'add.png'
    @template = AggregateTemplate.new
    prepare_options_hash
    set_global_options
    set_default_options unless returned?
  end

  def edit
    @page_title = _('Edit_Aggregate_Template')
    @page_icon = 'edit.png'
    prepare_options_hash
    set_global_options
  end

  def destroy
    safe_destroy
    redirect_to(action: :index) && (return false)
  end

  def update
    @template.update(@attributes)
    safe_save 'updated' do
      redirect_to(action: :edit, id: @template.id, params: @attributes) && (return false)
    end
    redirect_to(action: :index) && (return false)
  end

  def create
    @template = AggregateTemplate.new(@attributes)
    safe_save 'created' do
      redirect_to(action: :new, params: @attributes) && (return false)
    end
    redirect_to(action: :index) && (return false)
  end

  def ajax_create_template
    return unless request.xhr?
    aatr = slice_params
    AggregateTemplate.create(aatr)
  end

  def ajax_get_template
    return unless request.xhr?
    @options = {}
    responses = if params[:id].to_i > 0
                  AggregateTemplate.where(id: params[:id]).first
                else
                  set_default_options
                  @options
                end
    render json: {data: responses}
  end

  private

  def find_template
    @template = AggregateTemplate.where(id: params[:id], user_id: current_user_id).first
    return if @template
    flash[:notice] = _('Template_was_not_found')
    redirect_to(action: :index) && (return false)
  end

  def prepare_options_hash
    @options = returned? ? params : @template.to_hash
  end

  def set_global_options
    @options.merge!(
      op_devices: (@options[:s_originator_id].to_i > 0) ? Device.where(user_id: @options[:s_originator_id].to_i, op: 1, op_active: 1) : [],
      tp_devices: (@options[:s_terminator_id].to_i > 0) ? Device.where(user_id: @options[:s_terminator_id].to_i, tp: 1, tp_active: 1) : [],
      originator: @options[:s_originator],
      originator_id: @options[:s_originator_id],
      terminator: @options[:s_terminator],
      terminator_id: @options[:s_terminator_id]
    )
  end

  def slice_params
    attributes = params.slice(
      *(
        AggregateTemplate.text_inputs.map(&:to_sym) +
        AggregateTemplate.checkboxes.map(&:to_sym) +
        AggregateTemplate.radio_buttons.map(&:to_sym)
       )
    )
    attributes[:user_id] = current_user_id
    attributes[:name] = params[:name]
    attributes
  end

  def merge_default_attributes(attributes)
    hidden_options = {}
    AggregateTemplate.checkboxes.each { |var| hidden_options[var.to_sym] = nil }
    hidden_options.merge!(attributes)
    hidden_options
  end

  def set_default_options
    @options.merge!(
      originator: '', originator_id: '-1', terminator: '', terminator_id: '-1', dst: '',
      src: '', s_op_device: '', s_tp_device: '', op_devices: [], tp_devices: [], from_user_perspective: 0,
      answered_calls: 1, use_real_billsec: 0, dst_group: '',
      search_on: 0, s_duration: '', s_originator: '', s_originator_id: '-1', s_terminator: '', s_terminator_id: '-1',
      s_manager: ''
    )
    agg_default_columns
  end

  def agg_default_columns
    checkboxes = AggregateTemplate.checkboxes.map(&:to_sym)
    checkboxes.each do |check|
      @options[check] = %i[group_by_op group_by_tp group_by_dst profit_show profit_percent_show group_by_manager].member?(check) ? 0 : 1
    end
  end

  def safe_save(action_name)
    if @template.save
      flash[:status] = _("Aggregate_Template_successfully_#{action_name}")
    else
      flash_errors_for(_("Aggregate_Template_was_not_#{action_name}"), @template)
      @attributes[:returned] = 1
      yield
    end
  end

  def returned?
    params[:returned].to_i == 1
  end

  def set_attributes
    @attributes = merge_default_attributes(slice_params)
  end

  def safe_destroy
    if @template.destroy
      flash[:status] = _('Aggregate_Template_successfully_deleted')
    else
      flash_errors_for(_('Aggregate_Template_was_not_deleted'), @template)
    end
  end
end
