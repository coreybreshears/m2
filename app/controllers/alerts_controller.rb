# -*- encoding : utf-8 -*-
# Controller to show Alerts in GUI.
class AlertsController < ApplicationController
  layout :determine_layout

  before_filter(:check_post_method,
                only: [:alert_add, :alert_update, :alert_destroy, :contact_add, :contact_update, :contact_destroy,
                       :group_add, :group_update, :group_destroy, :schedule_destroy, :schedule_add,
                       :schedule_update, :group_contact_add
                     ]
               )
  before_filter :check_localization
  before_filter :access_denied, if: -> { user? || reseller? }
  before_filter :authorize
  before_filter :find_contact, only: [:contact_toggle, :contact_destroy, :contact_edit, :contact_update]
  before_filter :find_group, only: [:group_contacts, :group_edit, :group_update, :group_destroy, :group_toggle]
  before_filter :find_schedule, only: [:schedule_toggle, :schedule_destroy, :schedule_edit, :schedule_update]
  before_filter :find_alert, only: [:alert_edit, :alert_update, :alert_destroy, :alert_toggle]
  before_filter :set_alert_check_data, only: [:alert_update, :alert_add]
  before_filter :set_alert_parameters, only: [:alert_new, :alert_add, :alert_edit, :alert_update]

  after_filter(:update_alerts_service,
               only: [:alert_add, :alert_update, :alert_destroy, :contact_add, :contact_update, :contact_destroy,
                      :group_add, :group_update, :group_destroy, :schedule_destroy, :schedule_add, :schedule_update,
                      :contact_toggle, :group_toggle, :schedule_toggle, :alert_toggle,
                      :group_contact_add, :group_contact_destroy
                    ]
              )

  def index
    redirect_to action: 'list'
  end

  def list
    @page_title = _('Alerts')
    @page_icon = 'bell.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alerts'

    @options = session[:alerts_list_options] || {}

    set_options_from_params(@options, params, page: 1, order_desc: 0, order_by: 'id')

    order_by = Alert.alerts_order_by(@options)

    total_alerts = Alert.where(owner_id: corrected_user_id).count

    @fpage, @total_pages, @options = Application.pages_validator(session, @options, total_alerts)

    @search = @options[:s_name].blank? ? 0 : 1
    joins = []
    joins << 'LEFT JOIN routing_groups l_a ON (l_a.id = alerts.action_alert_change_routing_group_id)'
    joins << 'LEFT JOIN routing_groups l_c ON (l_c.id = alerts.action_clear_change_routing_group_id)'
    joins << 'LEFT JOIN alert_groups ON (alert_groups.id = alerts.alert_groups_id)'
    sel = []
    sel << 'alerts.*'
    sel << 'l_a.id AS routing_group_alert_id, l_a.name AS rg_alert_name'
    sel << 'l_c.id AS routing_group_clear_id, l_c.name AS rg_clear_name'
    sel << 'alert_groups.id AS alert_group_id, alert_groups.name AS alert_group_name'

    @alerts = Alert.select(sel.join(', ')).joins(joins.join(' '))
                   .where(owner_id: corrected_user_id).order(order_by)
                   .limit("#{@fpage}, #{session[:items_per_page]}").all

    session[:alerts_list_options] = @options
  end

  def alert_new
    @page_title = _('New_Alert')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alerts'
    @action_link = 'alert_add'

    @check_types = %w[user termination_point origination_point destination destination_group]
    @alert_count_type = %w[ABS]

    @alert ||= Alert.new
    @routing_groups = RoutingGroup.all
    @groups = AlertGroup.all
    @destination_groups = Destinationgroup.select('id, name as gname').order('name ASC').all
    @alert_dependencies = session[:alert_dependencies] = []
    @alerts_for_select = Alert.all
    session[:current_alert_id] = nil
    params[:s_device_user] = ''
    render(:alert_new) && (return false)
  end

  def alert_edit
    @page_title = _('Alert_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alerts'
    @action_link = 'alert_update'

    @routing_groups = RoutingGroup.all
    @groups = AlertGroup.all
    @destination_groups = Destinationgroup.select('id, name as gname').order('name ASC').all

    if params[:action] == 'alert_update'
      @alert_dependencies = session[:alert_dependencies]
    else
      session[:alert_dependencies] = @alert_dependencies = @alert.alert_dependency.all
    end

    alert_id = @alert.id
    alerts_in_dependencies = (@alert_dependencies.map { |alert| alert.alert_id } + [alert_id]).to_s.gsub(/[\]\[]/, '')
    @alerts_for_select = Alert.where("id NOT IN (#{alerts_in_dependencies}) && check_type = '#{@alert.check_type}'")
    session[:current_alert_id] = alert_id

    render(:alert_edit) && (return false)
  end

  def alert_add
    param_alert = params[:alert]
    alert_attributes = param_alert

    if alert_attributes[:check_type] == 'user'
      alert_attributes[:check_data] = params[:all_users] ? 'all' : params[:s_user_id]

      case params[:s_user].to_s.downcase
        when 'postpaid'
          alert_attributes[:check_data] = 'postpaid'
        when 'prepaid'
          alert_attributes[:check_data] = 'prepaid'
      end
    end

    alert_attributes[:check_data_secondary] = (param_alert[:check_type_secondary] == 'destination') ? param_alert[:check_data_secondary1] : param_alert[:check_data_secondary2]
    alert_attributes = alert_attributes.reject { |key, _| %w[check_data_secondary1 check_data_secondary2].include?(key.to_s) }
    alert_attributes[:action_alert_disable_dp_in_rg] = (alert_attributes[:dial_peer_id].to_i > 0) ? 1 : 0

    session[:alert_dependencies] ||= []
    alert_dependencies = session[:alert_dependencies]
    alert_dependencies_number = alert_dependencies.to_a.size

    alert_attribute = alert_attributes[:alert_when_more_than]
    allert_number = alert_attribute.to_i
    if alert_attribute.present? && allert_number != 0
      if allert_number >= alert_dependencies_number.to_i
        alert_attributes[:alert_when_more_than] = (alert_dependencies_number - 1).to_i
      end
      alert_attributes[:alert_when_more_than] = 0 if alert_dependencies_number == 0
    end

    alert_attributes[:alert_groups_id] = alert_attributes[:alert_groups_id].to_i
    alert_attributes[:disable_tp_in_dial_peer] = alert_attributes[:disable_tp_in_dial_peer].to_i

    @alert = Alert.new(alert_attributes)
    @alert.apply_limitations

    clear_on_date_blank = 0
    param_clear_on_date = params[:clear_on_date]
    if param_clear_on_date
      param_clear_on_date.each_value do |value|
        clear_on_date_blank += 1 if value.blank?
      end
    end

    clear_date = params[:clear_date]
    clear_time = params[:clear_time]

    # needs rework after alert_new rework with design
    clear_on_date_blank = 1 if clear_date.blank? && clear_time.present?

    if param_alert[:disable_clear].to_i == 1
      @alert.clear_on_date = nil
    elsif clear_on_date_blank == 0
      @alert.clear_on_date = user_time_from_params(*params['clear_on_date'].values)
    end

    alert_check_type = @alert.check_type.to_s

    @alert.assign_attributes({
                                notify_to_user: (0 unless %w[user origination_point termination_point].include?(alert_check_type)),
                                hgc: (0 unless ['hgc_absolute', 'hgc_percent'].include?(@alert.alert_type))
                             }.reject { |key, val| !val })

    if @alert.validation(corrected_user_id, clear_on_date_blank, alert_dependencies) && @alert.save
      alert_dependencies.try(:each) do |group|
        group.owner_alert_id = @alert.id
        group.save
      end

      flash[:status] = _('alert_successfully_created')
      redirect_to(action: 'list') && (return false)
    else
      reset_device_check_data(params)
      flash_errors_for(_('alert_was_not_created'), @alert)
      alert_new
    end
  end

  def alert_update
    param_alert = params[:alert]
    alert_attributes = param_alert
    alert_dependencies = session[:alert_dependencies]
    alert_dependencies_number = alert_dependencies.to_a.size

    %i[alert_if_more alert_if_less clear_if_more clear_if_less].each do |key|
      alert_attributes[key] = alert_attributes[key].to_d
    end

    alert_attributes[:action_alert_disable_dp_in_rg] = (alert_attributes[:dial_peer_id].to_i > 0) ? 1 : 0

    alert_attribute = alert_attributes[:alert_when_more_than]
    allert_number = alert_attribute.to_i
    if alert_attribute.present? && allert_number != 0
      if allert_number >= alert_dependencies_number.to_i
        alert_attributes[:alert_when_more_than] = (alert_dependencies_number - 1).to_i
      end
      alert_attributes[:alert_when_more_than] = 0 if alert_dependencies_number == 0
    end

    @alert.attributes = @alert.attributes.merge(alert_attributes)
    @alert.apply_limitations

    clear_date = params[:clear_date]
    clear_time = params[:clear_time]

    # needs rework after alert_new rework with design
    clear_on_date_blank = 1 if clear_date.blank? && clear_time.present?

    if param_alert[:disable_clear].to_i == 1
      @alert.clear_on_date = nil
    elsif clear_date
      @alert.clear_on_date = to_default_date(clear_date.to_s + ' ' + clear_time.to_s)
    end

    if @alert.validation(corrected_user_id, clear_on_date_blank, alert_dependencies) && @alert.save
      @alert.alert_dependency = alert_dependencies
      flash[:status] = _('alert_successfully_updated')
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('alert_was_not_updated'), @alert)
      alert_edit
    end
  end

  def alert_destroy
    if @alert.destroy
      flash[:status] = _('alert_successfully_deleted')
    else
      flash[:notice] = _('alert_was_not_deleted')
    end
    redirect_to action: 'list'
  end

  def contacts
    @page_title = _('alert_contacts')
    @page_icon = 'vcard.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Contacts'

    @cache = session[:alerts_new_contact]
    session.try(:delete, :alerts_new_contact)

    @options = params.reject { |key, _| %w[controller action].member? key.to_s }

    option_order_by = @options[:order_by]
    if option_order_by
      order_by = "#{option_order_by} " + ((@options[:order_desc].to_i == 1) ? 'DESC' : 'ASC')
    else
      order_by = 'id ASC'
    end

    @contacts = AlertContact.order(order_by).all
    @new_contact = AlertContact.new

    # blank new contact object as form_for template
    @new_contact.attributes.each { |key, _| @new_contact[key] = nil }

    # filling form template with failed to create contact details (if exists)
    @cache.try(:each) do |key, value|
      @new_contact[key] = value
    end
  end

  def contact_toggle
    if @contact.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('contact_successfully_disabled')
      flash_error = _('contact_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success = _('contact_successfully_enabled')
      flash_error = _('contact_was_not_enabled')
    end
    @contact.status = new_status
    if @contact.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @contact)
    end
    redirect_to(action: :contacts, params: params.reject { |key, _| %w[action controller].member? key.to_s }) && (return false)
  end

  def alert_toggle
    if @alert.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('alert_successfully_disabled')
      flash_error = _('alert_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success = _('alert_successfully_enabled')
      flash_error = _('alert_was_not_enabled')
    end
    @alert.status = new_status
    if @alert.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @alert)
    end
    redirect_to(action: :list) && (return false)
  end

  def contact_add
    where_blank = where_blank_proc
    defaults = AlertContact.new.attributes.reject(&where_blank) || {}
    form_fields	= params[:new_contact].try(:reject, &where_blank)
    new_contact	= AlertContact.new(defaults.merge(form_fields || {}))

    if new_contact.save
      flash[:status] = _('contact_successfully_created')
    else
      flash_errors_for(_('contact_was_not_created'), new_contact)
      session[:alerts_new_contact] = form_fields
    end
    redirect_to(action: :contacts) && (return false)
  end

  def schedule_add
    where_blank = where_blank_proc
    defaults = AlertSchedule.new.attributes.reject(&where_blank) || {}
    form_fields = params[:new_schedule].try(:reject, &where_blank)
    new_schedule = AlertSchedule.new(defaults.merge(form_fields || {}))

    if new_schedule.save
      AlertSchedulePeriod.new(alert_schedule_id: new_schedule.id).save
      flash[:status] = _('schedule_successfully_created')
    else
      flash_errors_for(_('schedule_was_not_created'), new_schedule)
      session[:alerts_new_schedule] = form_fields
    end

    clean_params = params.select { |key, _| %w[order_by order_desc].member?(key) }

    redirect_to(action: :schedules, params: clean_params) && (return false)
  end

  def schedule_edit
    @page_title = _('alert_schedule_edit') + ': ' + @schedule.name
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Schedules'

    @cache = session[:alerts_edit_schedule]
    session.try(:delete, :alerts_edit_schedule)

    @cache.try(:each) do |key, value|
      @schedule[key] = value
    end
  end

  def contact_edit
    @page_title = _('alert_contact_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Contacts'

    @cache = session[:alerts_edit_contact]
    session.try(:delete, :alerts_edit_contact)

    @cache.try(:each) do |key, value|
      @contact[key] = value
    end
  end

  def contact_update
    form_fields = params[:contact]
    form_fields.try(:each) do |key, value|
      @contact[key] = value
    end
    if @contact.save
      flash[:status] = _('contact_successfully_updated')
      redirect_to(action: 'contacts') && (return false)
    else
      flash_errors_for(_('contact_was_not_updated'), @contact)
      session[:alerts_edit_contact] = form_fields
      redirect_to(action: :contact_edit, id: @contact.id) && (return false)
    end
  end

  def contact_destroy
    if @contact.destroy
      flash[:status] = _('contact_successfully_deleted')
    else
      flash_errors_for(_('contact_was_not_deleted'), @contact)
    end
    redirect_to action: 'contacts'
  end

  def schedule_destroy
    if @schedule.destroy
      flash[:status] = _('schedule_successfully_deleted')
    else
      flash_errors_for(_('schedule_was_not_deleted'), @schedule)
    end
    redirect_to(action: :schedules) && (return false)
  end

  def schedules
    @page_title	= _('alert_schedules')
    @page_icon = 'clock.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Schedules'

    @options = params.reject { |key, _| %w[controller action].member? key.to_s }

    order_by_opts = @options[:order_by]
    order_desc_opts = @options[:order_desc].to_i

    if order_by_opts
      order_by = "#{order_by_opts} " + (order_desc_opts == 1 ? 'DESC' : 'ASC')
    else
      order_by = 'id ASC'
    end

    @schedules = AlertSchedule.order(order_by).all
    @new_schedule = AlertSchedule.new

    @cache = session[:alerts_new_schedule]
    session.try(:delete, :alerts_new_schedule)
  end

  def schedule_update
    form_fields = params[:schedule]
    periods	= params[:periods]
    form_fields.try(:each) do |key, value|
      @schedule[key] = value
    end

    err = Alert.schedule_update(@schedule, periods)

    if err.blank? && @schedule.save
      flash[:status] = _('schedule_successfully_updated')
      redirect_to(action: :schedules) && (return false)
    else
      first_error = err.first
      @schedule.errors.add(:time, first_error) unless first_error.blank?
      flash_errors_for(_('schedule_was_not_updated'), @schedule)
      session[:alerts_edit_schedule] = form_fields
      redirect_to(action: :schedule_edit, id: @schedule.id) && (return false)
    end
  end

  def groups
    @page_title = _('alert_groups')
    @page_icon = 'groups.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Groups'

    @cache = session[:alerts_new_group]
    session.try(:delete, :alerts_new_group)

    @options = session[:groups_list_order] || {order_by: 'id', order_desc: 0}

    set_options_from_params(@options, params, order_by: 'id', order_desc: 0)

    session[:groups_list_order] = @options

    order_by = order_groups(@options)

    @schedules = AlertSchedule.order('name ASC').all

    @groups = AlertGroup.select('alert_groups.*, email_schedules.name AS email_schedule_name')
                        .joins('LEFT JOIN alert_schedules AS email_schedules ON email_schedules.id = alert_groups.email_schedule_id')
                        .order(order_by).all

    @new_group = AlertGroup.new

    # blank new contact object as form_for template
    @new_group.attributes.each { |key, _| @new_group[key] = nil }

    # filling form template with failed to create contact details (if exists)
    @cache.try(:each) do |key, value|
      @new_group[key] = value
    end

    @new_group.status = 'enabled' if @cache.blank?
  end

  def group_add
    where_blank = where_blank_proc
    defaults = AlertGroup.new.attributes.reject(&where_blank)
    form_fields = params[:new_group].try(:reject, &where_blank)
    new_group = AlertGroup.new(defaults.merge(form_fields || {}))

    new_group = Alert.group_add(new_group)

    if new_group.save
      flash[:status] = _('alert_group_successfully_created')
    else
      flash_errors_for(_('alert_group_was_not_created'), new_group)
      session[:alerts_new_group] = form_fields
    end
    redirect_to(action: :groups) && (return false)
  end

  def group_contacts
    @page_title = _('Add_New_Contact')
    @page_icon = 'vcard.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Contacts'

    param_id = params[:id]
    @group_contacts = AlertContactGroup.select('alert_contact_groups.*, alert_contacts.name, alert_contacts.email')
                                       .where(['alert_contact_groups.alert_group_id = ?', param_id])
                                       .joins('JOIN alert_contacts ON alert_contacts.id = alert_contact_groups.alert_contact_id')

    @selectable_contacts = AlertContact.select('alert_contacts.id, alert_contacts.name')
                                       .where("alert_contacts.id NOT IN (SELECT alert_contact_groups.alert_contact_id AS id FROM alert_contact_groups WHERE alert_contact_groups.alert_group_id = #{param_id})")

    @group_name = @group.name
  end

  def group_contact_add
    alert_contact_group = AlertContactGroup.new(params[:new_group_contact])

    if alert_contact_group.save
      flash[:status] = _('contact_successfully_assigned')
    else
      flash_errors_for(_('contact_was_not_added'), alert_contact_group)
    end
    redirect_to(action: :group_contacts, id: alert_contact_group.alert_group_id) && (return false)
  end

  def group_contact_destroy
    if AlertContactGroup.where(id: params[:id]).first.destroy
      flash[:status] = _('contact_successfully_deleted')
    end
    redirect_to(action: :group_contacts, id: params[:group_id]) && (return false)
  end

  def group_toggle
    if @group.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('alert_group_successfully_disabled')
      flash_error = _('alert_group_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success = _('alert_group_successfully_enabled')
      flash_error = _('alert_group_was_not_enabled')
    end

    @group.status = new_status
    if @group.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @group)
    end
    redirect_to(action: :groups) && (return false)
  end

  def group_edit
    @group_name = @group.name
    @page_title = _('alert_group_edit') + ': ' + @group_name
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Groups'

    @schedules = AlertSchedule.order('name ASC').all

    @cache = session[:alert_group_edit]

    session.try(:delete, :alert_group_edit)
    @cache.try(:each) do |key, value|
      @group[key] = value
    end
  end

  def group_update
    @page_title = _('alert_groups')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Alert_Groups'

    form_fields = params[:group]
    form_fields.try(:each) do |key, value|
      @group[key] = value
    end

    @group = Alert.group_update(@group)

    if @group.save
      flash[:status] = _('alert_group_successfully_updated')
      redirect_to(action: :groups) && (return false)
    else
      flash_errors_for(_('alert_group_was_not_updated'), @group)
      session[:alert_group_edit] = form_fields
      redirect_to(action: :group_edit, id: @group.id) && (return false)
    end
  end

  def group_destroy
    if @group.destroy
      flash[:status] = _('alert_group_successfully_deleted')
    else
      flash_errors_for(_('alert_group_was_not_deleted'), @group)
    end
    redirect_to action: 'groups'
  end

  def schedule_toggle
    if @schedule.status == 'enabled'
      new_status = 'disabled'
      flash_success = _('schedule_successfully_disabled')
      flash_error = _('schedule_was_not_disabled')
    else
      new_status = 'enabled'
      flash_success = _('schedule_successfully_enabled')
      flash_error = _('schedule_was_not_enabled')
    end
    @schedule.status = new_status
    if @schedule.save
      flash[:status] = flash_success
    else
      flash_errors_for(flash_error, @schedule)
    end
    redirect_to(action: :schedules, params: params) && (return false)
  end

  def new_schedule
    begin
      js_new = Alert.new_schedule(params)

      render partial: 'schedule_periods', locals: {day: params[:day_type], js_new: js_new}
    rescue
      render text: ''
    end
  end

  def drop_period
    period = AlertSchedulePeriod.where(id: params[:id]).first
    if period.try(:destroy)
      render text: 'OK'
    else
      render text: 'BLANK'
    end
  end

  def ajax_get_dial_peers
    @alert = Alert.new if @alert.blank?
    @alert.disable_tp_in_dial_peer = params[:dis].to_i
    device_id = params[:device_id]

    if device_id == 'all'
      @dial_peers = DialPeer.all
    elsif device_id.blank?
      @dial_peers = DpeerTpoint.where(device_id: nil).try(:dial_peer)
    else
      @dial_peers = Device.where(id: device_id.to_i).first.try(:dial_peers)
    end
    render layout: false
  end

  def add_alert_to_group
    alert_dependencies = session[:alert_dependencies] <<
      AlertDependency.new(alert_id: params[:alert_id].to_i)
    alert_ids = alert_dependencies.map(&:alert_id).join(', ')
    alerts_for_select = Alert.where(check_type: params[:check_type]).where("id NOT IN (#{alert_ids})")
    render partial: 'alert_dependencies', layout: false,
           locals: {alerts: alerts_for_select, alert_dependencies: alert_dependencies}
  end

  def remove_alert_from_group
    alert_dependencies = session[:alert_dependencies].reject do |element|
      element.alert_id == params[:alert_id].to_i
    end
    session[:alert_dependencies] = alert_dependencies

    alert_ids = alert_dependencies.map(&:alert_id).join(', ')

    if alert_ids.length > 0
      alerts_for_select = Alert.where(check_type: params[:check_type]).where("id NOT IN (#{alert_ids})")
    else
      alerts_for_select = Alert.where(check_type: params[:check_type])
    end

    render partial: 'alert_dependencies', layout: false,
           locals: {alerts: alerts_for_select, alert_dependencies: alert_dependencies}
  end

  def update_dependency_selector
    session[:alert_dependencies] = []
    alerts_for_select = Alert.where(check_type: params[:check_type])
    render partial: 'alert_dependencies', layout: false,
           locals: {alerts: alerts_for_select, alert_dependencies: []}
  end

  def get_cp_rg_dial_peers
    if request.xhr?
      r_group = RoutingGroup.where(id: params[:routing_group_id].to_i).first

      d_peers = {}
      if r_group.present?
        d_peers[:routing_group_name] = r_group.name
        rgroup_dps = r_group.rgroup_dpeers.pluck(:id)
        d_peers[:d_peers] = DialPeer.select(:id, :name).where(id: rgroup_dps).all if rgroup_dps.present?
      end
      render json: d_peers.to_json
    else
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def get_cp_routing_group_id
    if request.xhr?
      r_group = {}
      r_group = Device.select(:op_routing_group_id)
                      .where(id: params[:device_id].to_i)
                      .first
      return render json: r_group.to_json
    else
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  private

  def reset_device_check_data(hash)
    @alert_check_data_user_id = hash[:device_user]
    @alert_check_data_user_id = hash[:device_tp] if hash[:device_tp].present?
    @alert_check_data_user_id = hash[:device_op] if hash[:device_op].present?
  end

  def order_groups(options)
    order_by = ''

    case options[:order_by].to_s
      when 'id'
        order_by += 'alert_groups.id'
      when 'name'
        order_by += 'alert_groups.name'
      when 'status'
        order_by += 'alert_groups.status'
      when 'email_schedule'
        order_by += 'email_schedule_name'
      when 'max_emails_month'
        order_by += 'alert_groups.max_emails_per_month'
      when 'emails_this_month'
        order_by += 'alert_groups.emails_this_month'
      when 'comment'
        order_by += 'alert_groups.comment'
    end

    if order_by != ''
      case options[:order_desc].to_i
        when 0
          order_by += ' ASC'
        when 1
          order_by += ' DESC'
      end
    end

    order_by
  end

  def set_alert_check_data
    params[:tp_device] = 'all' if params[:device_tp] == 'all'
    params[:op_device] = 'all' if params[:device_op] == 'all'
    alert_attributes = params[:alert]
    unless alert_attributes.blank?
      param_keys = [:s_user, :alert_check_data2, :alert_check_data3, :alert_check_data4, :tp_device, :op_device]
      check_data = nil
      param_keys.each do |key|
        param_value = params[key]
        check_data = param_value if param_value
      end
      alert_attributes[:check_data] = check_data if check_data
    end
  end

  def set_alert_parameters
    @alert_type_parameters = {}

    parameters_base = %w[asr acd pdd ttc billsec_sum calls_total calls_answered calls_not_answered
                         hgc_absolute hgc_percent group]
    @alert_type_parameters[:base] = parameters_base
    @alert_type_parameters[:user] = parameters_base + ['sim_calls', 'price_sum']
    @alert_type_parameters[:termination_point] = parameters_base + ['price_sum']
  end

  def update_alerts_service
    Confline.set_value('alerts_need_update', 1)
  end

  def find_alert
    @alert = Alert.where(id: params[:id], owner_id: corrected_user_id).first
    return if @alert
    flash[:notice] = _('alert_was_not_found')
    redirect_to(action: :list) && (return false)
  end

  def find_contact
    @contact = AlertContact.where(id: params[:id]).first
    return if @contact
    flash[:notice] = _('contact_was_not_found')
    redirect_to(action: :contacts) && (return false)
  end

  def find_schedule
    @schedule = AlertSchedule.where(id: params[:id]).first
    return if @schedule
    flash[:notice] = _('schedule_was_not_found')
    redirect_to(action: :schedules) && (return false)
  end

  def find_group
    @group = AlertGroup.where(id: params[:id]).first
    return if @group
    flash[:notice] = _('alert_group_was_not_found')
    redirect_to(action: :groups) && (return false)
  end

  def where_blank_proc
    Proc.new {|_, value| value.blank?}
  end
end
