# Routing Groups managing.
class RoutingGroupsController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { user? }
  before_filter :check_post_method, only: [:create, :update, :destroy, :rgroup_dpeer_add, :rgroup_dpeer_destroy]
  before_filter :authorize
  before_filter :find_routing_group,
                only: [
                  :edit, :update, :destroy, :rgroup_dpeers_list, :rgroup_dpeer_add, :dial_peers_management
                ]
  before_filter :find_failover_routing_groups, only: [:new, :create, :edit, :update, :destroy]
  before_filter :find_rgroup_dpeers, only: [:rgroup_dpeer_destroy, :rgroup_dpeer_status_change]
  before_filter :find_dial_peer, only: [:stop_hunting_status_change]
  before_filter :set_session, only: [:list]
  before_filter :manager_access, only: [:edit, :update, :destroy, :rgroup_dpeers_list, :dial_peers_management]

  def list
    # @page_title = _('routing_groups')
    @page_icon = 'arrow_switch.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Routing_groups'
    @options = session[:routing_group_options] || {}

    set_options_from_params(@options, params, page: 1, order_desc: 0, order_by: 'id')

    if params.member?(:s_name)
      @options[:s_name] = params[:clear] ? nil : params[:s_name]
    end

    option_order_desc = @options[:order_desc]
    if option_order_desc.present?
      order_desc = (option_order_desc.to_i == 1) ? ' DESC' : ' ASC'
      order_sql = @options[:order_by].to_s + order_desc
    end

    fpage, @total_pages, @options = Application.pages_validator(session, @options, RoutingGroup.count)
    name_wcard = @options[:s_name]
    name_wcard = '%' if name_wcard.blank?
    @routing_groups = RoutingGroup.routing_group_list(wcard: name_wcard, order_by: order_sql, fpage: fpage, items_limit: session[:items_per_page], user: current_user)

    session[:routing_group_options] = @options
  end

  def new
    @page_title = _('new_routing_group')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Routing_groups'
    @is_rg_failover_possible = is_rg_failover_possible
  end

  def create
    routing_groups_params = params[:routing_group]
    routing_groups_params[:name].to_s.strip!
    routing_groups_params[:comment].to_s.strip!
    @routing_group = RoutingGroup.new(routing_groups_params)
    if @routing_group.save
      flash[:status] = _('routing_group_successfully_created')
      redirect_to(action: 'list') && (return false)
    else
      flash_errors_for(_('routing_group_was_not_created'), @routing_group)
      new
      render :new
    end
  end

  def edit
    @page_title = _('routing_group_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Routing_groups'
    @is_rg_failover_possible = is_rg_failover_possible
    @failover_routing_groups = remove_assigned_groups(@failover_routing_groups, @routing_group)
    @rgroup_dpeers_count = params[:rgdp] || RgroupDpeer.where(routing_group_id: params[:id]).count
    get_rg_cps(params[:id])
  end

  def update
    routing_groups_params = params[:routing_group]
    routing_groups_params[:name].to_s.strip!
    routing_groups_params[:comment].to_s.strip!

    if @routing_group.update_attributes(routing_groups_params)
      flash[:status] = _('routing_group_successfully_updated')
      redirect_to(action: 'list') && (return false)
    else
      flash_errors_for(_('routing_group_was_not_updated'), @routing_group)
      edit
      render :edit
    end
  end

  def destroy
    if @routing_group.destroy
      flash[:status] = _('routing_group_successfully_deleted')
    else
      flash_errors_for(_('routing_group_was_not_deleted'), @routing_group)
      redirect_to(action: 'edit', id: @routing_group.id) && (return false) if m4_functionality?
    end
    redirect_to(action: 'list') && (return false)
  end

  def is_rg_failover_possible
    @rg1 = RoutingGroup.where(parent_routing_group_id: params[:id]).first

    if @rg1 && @rg1.parent_routing_group_id.to_i != -1
      @rg2 = RoutingGroup.where(parent_routing_group_id: @rg1.id).first

      return 'failover' if @rg2 && @rg2.parent_routing_group_id != -1
    end

    ' '
  end

  def dial_peers_management
  end

  def retrieve_dial_peers_management_remote
    routing_group_id = params[:routing_group_id].to_s
    mask = ActiveRecord::Base::sanitize(params[:mask].to_s)[1..-2]

    rg_dp = RgroupDpeer.select(:dial_peer_id).where(routing_group_id: routing_group_id).all.pluck(:dial_peer_id)

    # Not Assigned Dial Peers
    where_not_in = rg_dp.present? ? "id NOT IN (#{rg_dp.join(', ')}) AND " : ''
    # Assigned Dial Peers
    where_in = rg_dp.present? ? "id IN (#{rg_dp.join(', ')}) AND " : '1 != 1 AND'

    not_assigned_dial_peers = DialPeer.select(:id, :name)
                                      .where("#{where_not_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci")
                                      .order(:name).all

    assigned_dial_peers = DialPeer.select(:id, :name)
                                  .where("#{where_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci")
                                  .order(:name).all

    result = {
      assigned: assigned_dial_peers.map { |dial_peer| {id: dial_peer.id, name: dial_peer.name} },
      not_assigned: not_assigned_dial_peers.map { |dial_peer| {id: dial_peer.id, name: dial_peer.name} }
    }

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def dial_peers_management_assignment_remote
    routing_group_id = params[:routing_group_id].to_i
    assignment_direction = params[:assignment_direction].to_s
    dial_peer_id = params[:dial_peer_id].to_i
    mask = ActiveRecord::Base::sanitize(params[:mask].to_s)[1..-2]

    routing_group = RoutingGroup.where(id: routing_group_id).first unless routing_group_id == -1

    if routing_group_id != -1 && routing_group.blank?
      respond_to do |format|
        format.json do
          render json: {error: 'Routing Group was not found', status: 400}, status: :bad_request
          return false
        end
      end
    end

    dial_peer = DialPeer.where(id: dial_peer_id).first unless dial_peer_id == -1

    if dial_peer_id != -1 && dial_peer.blank?
      respond_to do |format|
        format.json do
          render json: {error: 'Dial Peer was not found', status: 400}, status: :bad_request
          return false
        end
      end
    end

    if routing_group_id == -1 && dial_peer_id == -1
      respond_to do |format|
        format.json do
          render json: {error: 'Routing Group and Dial Peer IDs incorrect request', status: 400}, status: :bad_request
          return false
        end
      end
    end

    unless %[assign unassign].include?(assignment_direction)
      respond_to do |format|
        format.json do
          render json: {error: 'Incorrect Assignment value', status: 400}, status: :bad_request
          return false
        end
      end
    end

    if dial_peer_id == -1
      rg_dp = RgroupDpeer.select(:dial_peer_id).where(routing_group_id: routing_group_id).all.pluck(:dial_peer_id)

      case assignment_direction
        when 'assign'
          where_not_in = rg_dp.present? ? "id NOT IN (#{rg_dp.join(', ')}) AND " : ''
          not_assigned_dial_peers = DialPeer.where("#{where_not_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci").pluck(:id)

          not_assigned_dial_peers.each do |dp_id|
            if RgroupDpeer.where(routing_group_id: routing_group_id, dial_peer_id: dp_id).first.blank?
              RgroupDpeer.create(routing_group_id: routing_group_id, dial_peer_id: dp_id, dial_peer_priority: 1)
            end
          end
        when 'unassign'
          where_in = rg_dp.present? ? "id IN (#{rg_dp.join(', ')}) AND " : '1 != 1 AND'
          assigned_dial_peers = DialPeer.where("#{where_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci").pluck(:id)

          deleted = RgroupDpeer.where(routing_group_id: routing_group_id, dial_peer_id: assigned_dial_peers).delete_all
          if deleted > 0
            routing_group.device_op_routing_group_changed
            routing_group.changes_present_set_1
          end
      end
    elsif routing_group_id == -1
      rg_dp = RgroupDpeer.select(:routing_group_id).where(dial_peer_id: dial_peer_id).all.pluck(:routing_group_id)

      case assignment_direction
        when 'assign'
          where_not_in = rg_dp.present? ? "id NOT IN (#{rg_dp.join(', ')}) AND " : ''
          not_assigned_routing_groups = RoutingGroup.where("#{where_not_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci").pluck(:id)

          not_assigned_routing_groups.each do |rg_id|
            if RgroupDpeer.where(routing_group_id: rg_id, dial_peer_id: dial_peer_id).first.blank?
              RgroupDpeer.create(routing_group_id: rg_id, dial_peer_id: dial_peer_id, dial_peer_priority: 1)
            end
          end
        when 'unassign'
          where_in = rg_dp.present? ? "id IN (#{rg_dp.join(', ')}) AND " : '1 != 1 AND'
          assigned_routing_groups = RoutingGroup.where("#{where_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci").pluck(:id)

          deleted = RgroupDpeer.where(routing_group_id: assigned_routing_groups, dial_peer_id: dial_peer_id).delete_all
          if deleted > 0
            dial_peer.dial_peer_data_changed
          end
      end
    else
      rgroup_dpeer = RgroupDpeer.where(routing_group_id: routing_group_id, dial_peer_id: dial_peer_id).first
      case assignment_direction
        when 'assign'
          if rgroup_dpeer.blank?
            RgroupDpeer.create(routing_group_id: routing_group_id, dial_peer_id: dial_peer_id, dial_peer_priority: 1)
          end
        when 'unassign'
          rgroup_dpeer.destroy if rgroup_dpeer.present?
      end
    end

    respond_to do |format|
      format.json do
        render json: {status: 200}, status: 200
      end
    end
  end

  def rgroup_dpeers_list
    @page_title = _('routing_group_dial_peers')
    @page_icon = 'actions.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Routing_groups'
    @options = session[:rgroup_dpeers] || {}

    @options.merge!(params.dup.symbolize_keys.reject { |key, _| %i[controller action].member? key })

    @options[:page] = 1 if @options[:page].blank?
    routing_group_id = params[:id].to_i

    if params.member?(:s_name)
      @options[:s_name] = params[:clear] ? nil : params[:s_name]
    end
    name_wcard = @options[:s_name]
    name_wcard = '%' if name_wcard.blank?

    total_dp_in_rg = RgroupDpeer.joins('JOIN dial_peers ON (rgroup_dpeers.dial_peer_id = dial_peers.id)')
                                .where(routing_group_id: routing_group_id)
                                .where('dial_peers.name LIKE ?', name_wcard)
                                .count

    fpage, @total_pages, @options = Application.pages_validator(session, @options, total_dp_in_rg)
    order_desc = params[:order_desc]
    order_by = params[:order_by]

    order_sql = order_by.to_s + ((order_desc.to_i == 1) ? ' DESC' : ' ASC') if order_desc.present?

    @rgroup_dpeers = RgroupDpeer.select('rgroup_dpeers.id as id, rgroup_dpeers.active as active,
                    rgroup_dpeers.routing_group_id as routing_group_id, dial_peers.id as dial_peers_id,
                    dial_peers.name as name, dial_peers.dst_regexp as dst_regexp, dial_peers.active as dp_active,
                    dial_peers.dst_mask as dst_mask, dial_peers.stop_hunting as stop_hunting,
                    dial_peers.tp_priority as tp_priority, rgroup_dpeers.dial_peer_priority as dial_peer_priority,
                    COUNT(dpeer_tpoints.dial_peer_id) AS tp_list')
                                .joins('JOIN dial_peers ON rgroup_dpeers.dial_peer_id = dial_peers.id')
                                .joins('LEFT JOIN dpeer_tpoints ON dpeer_tpoints.dial_peer_id = dial_peers.id')
                                .group('dial_peers.id')
                                .where(routing_group_id: routing_group_id)
                                .where('dial_peers.name LIKE ?', name_wcard)
                                .order(order_sql)
                                .offset(fpage)
                                .limit(session[:items_per_page])

    @free_dial_peers = DialPeer.where("NOT EXISTS (SELECT * FROM rgroup_dpeers where rgroup_dpeers.routing_group_id = #{routing_group_id} AND rgroup_dpeers.dial_peer_id = dial_peers.id)")
                               .order('name')

    # Dial _peer assignment
    @new_dial_peer = DialPeer.new
    session[:rgroup_dpeers] = @options
  end

  def rgroup_dpeer_status_change
    @rgroup_dpeers.active, flash[:status] =
        case @rgroup_dpeers.active.to_i
          when 1
            [0, _('Dial_Peer_disabled')]
          when 0
            [1, _('Dial_Peer_enabled')]
        end

    @rgroup_dpeers.save

    redirect_to(action: :rgroup_dpeers_list, id: @rgroup_dpeers.routing_group_id) && (return false)
  end

  def rgroup_dpeer_add
    params_id = params[:id]
    params_dial_peer_id = params[:dial_peer_id]
    priority = (params[:priority] || 1).to_i
    priority = 0 if priority < 0
    @rgroup_dpeer = RgroupDpeer.new(
      routing_group_id: params_id,
      dial_peer_id: params_dial_peer_id,
      dial_peer_priority: priority
    )
    if @rgroup_dpeer.save
      flash[:status] = _('dial_peer_successfully_assigned')
      close_m2_form(:routing_groups, 'rgroup_dpeers_list')
      redirect_to(action: 'rgroup_dpeers_list', id: params_id) && (return false)
    else
      flash_errors_for(_('dial_peer_not_updated'), @rgroup_dpeer)
      redirect_to action: :rgroup_dpeers_list, priority: priority, dial_peer_id: params_dial_peer_id, id: @routing_group.id
    end
  end

  def rgroup_dpeer_destroy
    if @rgroup_dpeers.destroy
      flash[:status] = _('dial_peer_successfully_unassigned')
    else
      flash_errors_for(_('dial_peer_was_not_unassigned'), @rgroup_dpeers)
    end
    redirect_to(action: 'rgroup_dpeers_list', id: @rgroup_dpeers.routing_group_id) && (return false)
  end

  def update_rgroup_dpeers
    rgroup_dpeer = RgroupDpeer.where(id: params[:id]).first
    params_priority = params[:rgroup_dpeers][:priority]

    if rgroup_dpeer
      priority = params_priority
      rgroup_dpeer.dial_peer_priority = priority
    end

    if rgroup_dpeer && rgroup_dpeer.save
      flash.clear
      respond_to do |format|
        format.json { render(json: ['success', _('dial_peer_successfully_updated')]) }
      end
    else
      flash_errors_for(_('dial_peer_not_updated'), rgroup_dpeer)
      errors = flash[:notice]
      flash.clear
      respond_to do |format|
        format.json { render(json: [errors]) }
      end
    end
  end

  def set_session
    param_order_by = params[:order_by]
    param_order_desc = params[:order_desc]
    if param_order_by && param_order_desc
      order_by, order_desc = param_order_by, param_order_desc
      options = {} if params[:clear] or !options
      options = params if params[:search_pressed]
      options[:order_by], options[:order_desc] = order_by, order_desc.to_i if order_by
      @options = options
    end
  end

  def stop_hunting_status_change
    messages = [_('Hunting_started'), _('Hunting_stopped')]
    value = 1 - @dial_peer.stop_hunting.to_i
    @dial_peer.stop_hunting = value
    flash[:status] = messages[value]
    @dial_peer.save
    redirect_to(action: :rgroup_dpeers_list, id: params[:routing_group_id]) && (return false)
  end

  def get_rg_cps(id)
    sql = 'op_routing_group_id = ? OR op_match_rg_id = ? OR (mnp_use = 1 AND mnp_routing_group_id = ?)'\
     ' OR (us_jurisdictional_routing = 1 AND (op_rg_inter = ? OR op_rg_intra = ? OR op_rg_indeter = ?))'
    @rg_cps = Device.where(sql, *([id] * 6)).limit(10)
    @rg_cps_count = Device.where(sql, *([id] * 6)).size
  end

  private

  def find_routing_group
    @routing_group = RoutingGroup.where(id: params[:id]).first
    return if @routing_group
    flash[:notice] = _('routing_group_was_not_found')
    redirect_to(action: 'list') && (return false)
  end

  def find_dial_peer
    @dial_peer = DialPeer.where(id: params[:id]).first
    return if @dial_peer
    flash[:notice] = _('dial_peer_not_found')
    redirect_to(action: :rgroup_dpeers_list, id: params[:routing_group_id]) && (return false)
  end

  def find_rgroup_dpeers
    @rgroup_dpeers = RgroupDpeer.where(id: params[:id]).first
    return if @rgroup_dpeers
    flash[:notice] = _('rgroup_dpeers_was_not_found')
    redirect_to(action: 'rgroup_dpeers_list') && (return false)
  end

  # This method finds failover routing groups for dropdown
  def find_failover_routing_groups
    # Failed_routing_groups finds routing groups which shouldnt be displayed in dropdown
    failed_routing_groups = RoutingGroup.all.map do |group|
      @rg1 = RoutingGroup.where(parent_routing_group_id: group.id).first
      if @rg1 && @rg1.parent_routing_group_id.to_i != -1
        @rg2 = RoutingGroup.where(parent_routing_group_id: @rg1.id).first
        if @rg2 && @rg2.parent_routing_group_id != -1
          [@rg2.name, @rg2.id]
        end
      end
    end

    @failover_routing_groups = RoutingGroup.rg_dropdown(current_user).map { |group| [group.name, group.id] if group.id.to_s != params[:id].to_s}.compact
    @failover_routing_groups -= failed_routing_groups if !failed_routing_groups.empty? # takes out routing groups which shouldnt be displayed

    return if @failover_routing_groups
    flash[:notice] = _('routing_groups_were_not_found')
    redirect_to(action: 'list') && (return false)
  end

  def remove_assigned_groups(groups, group)
    groups_to_remove = RoutingGroup.where(parent_routing_group_id: group.id).all.pluck(:id)
    groups.reject { |group| groups_to_remove.include?(group[1]) }
  end

  def manager_access
    routing_groups = RoutingGroup.manager_rg(current_user, true).include?(params[:id])
    if current_user.show_only_assigned_users? && !routing_groups
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end
end
