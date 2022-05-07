# -*- encoding : utf-8 -*-
# M2 Dial Peers
class DialPeersController < ApplicationController
  layout :determine_layout

  before_filter :check_post_method, only: [:destroy, :create, :update, :remove_termination_point,
                                           :change_status_termination_point]
  before_filter :access_denied, if: -> { user? }
  before_filter :authorize
  before_filter :find_dial_peer, only: [:edit, :update, :destroy, :termination_points_list, :remove_termination_point,
                                        :assign_termination_point, :routing_groups_management]
  before_filter :find_termination_point, only: [:update_termination_point]
  before_filter :strip_params, only: [:update, :create]
  before_filter :change_separator, only: [:create, :update]
  before_filter :find_tariffs, only: [:new, :create, :update, :edit]
  before_filter :set_session, only: [:list]

  def index
    redirect_to controller: :dial_peers, action: :list
  end

  def list
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
    @options = session[:dial_peer_options] || {}

    set_options_from_params(@options, params, page: 1, order_desc: 0, order_by: 'id')
    if params.member?(:s_name)
      @options[:s_name] = params[:clear] ? nil : params[:s_name]
    end

    order_desc = @options[:order_desc]
    order_by = @options[:order_by]
    if order_desc.present?
      order_desc = (order_desc.to_i == 1) ? ' DESC' : ' ASC'
      order_sql = order_by.to_s + order_desc
    end

    fpage, @total_pages, @options = Application.pages_validator(session, @options, DialPeer.count)
    name_wcard = @options[:s_name]
    name_wcard = '%' if name_wcard.blank?
    @dial_peers = DialPeer.dial_peer_list(wcard: name_wcard, order_by: order_sql, fpage: fpage, items_limit: session[:items_per_page])

    session[:dial_peer_options] = @options
  end

  def new
    @page_title = _('dial_peer_new')

    @dial_peer = DialPeer.new
    session[:minimal_rate_margin] = ''
    session[:minimal_rate_margin_percent] = ''
  end

  def create
    @page_title = _('dial_peer_new')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
    dialpeer_attributes = params[:dial_peer]

    @dial_peer = DialPeer.new(dialpeer_attributes)
    minimal_rate_margin = dialpeer_attributes[:minimal_rate_margin]
    minimal_rate_percent = dialpeer_attributes[:minimal_rate_percent]
    session[:minimal_rate_margin] = is_numeric?(minimal_rate_margin) ? '' : minimal_rate_margin.to_s
    session[:minimal_rate_margin_percent] = is_numeric?(minimal_rate_percent) ? '' : minimal_rate_percent.to_s

    @dial_peer.no_follow = 0 if dialpeer_attributes[:tp_priority] == 'weight'

    if @dial_peer.save
      flash[:status] = _('dial_peer_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('dial_peer_not_created'), @dial_peer)
      render :new
    end
  end

  def edit
    @page_title = _('dial_peer_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'

    session[:minimal_rate_margin] = ''
    session[:minimal_rate_margin_percent] = ''
  end

  def update
    @page_title = _('dial_peer_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
    dialpeer_attributes = params[:dial_peer]
    session[:minimal_rate_margin] = is_numeric?(dialpeer_attributes[:minimal_rate_margin]) ? '' : dialpeer_attributes[:minimal_rate_margin].to_s
    session[:minimal_rate_margin_percent] = is_numeric?(dialpeer_attributes[:minimal_rate_margin_percent]) ? '' : dialpeer_attributes[:minimal_rate_margin_percent].to_s

    dp_before = @dial_peer.dup
    @dial_peer.update_from_params(dialpeer_attributes)

    if @dial_peer.save
      @dial_peer.change_action(dp_before)
      flash[:status] = _('dial_peer_successfully_updated')
      redirect_to action: 'list'
    else
      flash_errors_for(_('dial_peer_not_updated'), @dial_peer)
      render :edit
    end
  end

  def destroy
    if @dial_peer.destroy
      flash[:status] = _('dial_peer_deleted')
    else
      flash_errors_for(_('dial_peer_was_not_deleted'), @dial_peer)
    end

    redirect_to action: 'list'
  end

  # Dial Peer Termination Points
  def termination_points_list
    @active_devices = Device.where(tp: 1, tp_active: 1).where.not(id: @dial_peer.dpeer_tpoints.map(&:device_id))
  end

  def assign_termination_point
    params_new_termination_point = params[:new_termination_point]
    termination_point = DpeerTpoint.new(params_new_termination_point) { |new| new.dial_peer_id = @dial_peer.id }
    if termination_point.save
      Action.add_action_hash(current_user.id, action: 'assign_termination_point_to_dp',
                                              data: _('termination_point_successfully_assigned'),
                                              target_type: 'tp_dial_peer',
                                              target_id: @dial_peer.id,
                                              data2: "Dial Peer id: #{@dial_peer.id}",
                                              data3: "Termination Point id: #{params_new_termination_point[:device_id]}")
      flash[:status] = _('termination_point_successfully_assigned')
      close_m2_form(:dial_peers, 'termination_points_list')
      redirect_to(action: :termination_points_list, id: @dial_peer) && (return false)
    else
      flash_errors_for(_('termination_point_not_assigned'), termination_point)
    end
    redirect_to action: :termination_points_list, id: @dial_peer, new_termination_point: params_new_termination_point
  end

  def remove_termination_point
    termination_point = DpeerTpoint.where(id: params[:tp_id]).first
    device_id = termination_point.try(:device_id)
    if termination_point && termination_point.destroy
      Action.add_action_hash(current_user.id, action: 'remove_termination_point_from_dp',
                                              data: _('termination_point_successfully_removed'),
                                              target_type: 'tp_dial_peer',
                                              target_id: @dial_peer.id,
                                              data2: "Dial Peer id: #{@dial_peer.id}",
                                              data3: "Termination Point id: #{device_id}")
      flash[:status] = _('termination_point_successfully_removed')
    end
    redirect_to action: 'termination_points_list', id: @dial_peer.id
  end

  def change_status_termination_point
    termination_point = DpeerTpoint.where(id: params[:id]).first

    if termination_point.blank?
      flash[:notice] = _('termination_point_not_found')
      redirect_to(:root) && (return false)
    end

    if termination_point.active == 1
      termination_point.active = 0
      flash[:status] = _('Termination_Point_disabled')
    else
      termination_point.active = 1
      flash[:status] = _('Termination_Point_enabled')
    end
    termination_point.save
    redirect_to action: 'termination_points_list', id: termination_point.dial_peer_id
  end

  def update_termination_point
    params_termination_point = params[:termination_point]
    filter_cps_and_call_limit(params_termination_point)
    tp_assign_value(params_termination_point, params[:attribute_name])
    msg = save_tp_with_message

    respond_to do |format|
      format.json { render(json: msg) }
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

  def active_tps
    @select_name = params[:select_name]
    @tps = DialPeer.find_by(id: params[:id]).try(:active_tps) || []
    render layout: false
  end

  def routing_groups_management
  end

  def retrieve_routing_groups_management_remote
    dial_peer_id = params[:dial_peer_id].to_s
    mask = ActiveRecord::Base::sanitize(params[:mask].to_s)[1..-2]

    rg_dp = RgroupDpeer.select(:routing_group_id).where(dial_peer_id: dial_peer_id).all.pluck(:routing_group_id)

    # Not Assigned Routing Groups
    where_not_in = rg_dp.present? ? "id NOT IN (#{rg_dp.join(', ')}) AND " : ''
    # Assigned Routing Groups
    where_in = rg_dp.present? ? "id IN (#{rg_dp.join(', ')}) AND " : '1 != 1 AND'

    not_assigned_routing_groups = RoutingGroup.select(:id, :name).
      where("#{where_not_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci").
      order(:name).all

    assigned_routing_groups = RoutingGroup.select(:id, :name).
      where("#{where_in} name LIKE '%#{mask}%' COLLATE utf8_general_ci").
      order(:name).all

    result = {
      assigned: assigned_routing_groups.map { |routing_group| {id: routing_group.id, name: routing_group.name} },
      not_assigned: not_assigned_routing_groups.map { |routing_group| {id: routing_group.id, name: routing_group.name} }
    }

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def routing_groups_management_assignment_remote
    dial_peer_id = params[:dial_peer_id].to_i
    assignment_direction = params[:assignment_direction].to_s
    routing_group_id = params[:routing_group_id].to_i
    mask = ActiveRecord::Base::sanitize(params[:mask].to_s)[1..-2]

    routing_group = RoutingGroup.where(id: routing_group_id).first

    if routing_group.blank?
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

  private

  def save_tp_with_message
    msg = []
    if @termination_point.save
      msg = ['success', _('Termination_Point_successfully_updated')]
    else
      flash_errors_for(_('Termination_Point_was_not_updated'), @termination_point)
      msg = [flash[:notice]]
    end
    flash.clear
    msg
  end

  def tp_assign_value(params = {}, attribute_name = '')
    params_attr = params[attribute_name.to_sym].presence
    @termination_point.send("tp_#{attribute_name}=", params_attr.strip) if params_attr.present? || params_attr == ''
  end

  def filter_cps_and_call_limit(params = {})
    %i[cps call_limit].each do |attr|
      params[attr] = '0' if params[attr] == ''
    end
  end

  def find_dial_peer
    @dial_peer = DialPeer.where(id: params[:id]).first
    unless @dial_peer
      flash[:notice] = _('dial_peer_not_found')
      redirect_to action: 'list' and return false
    end
  end

  def change_separator
    separator = Confline.get_value('Global_Number_Decimal')
    params[:dial_peer][:minimal_rate_margin].gsub!(/[\,\;]/, '.')
    params[:dial_peer][:minimal_rate_margin_percent].gsub!(/[\,\;]/, '.')
  end

  def find_tariffs
    @tariffs = Tariff.where("owner_id = #{current_user.get_corrected_owner_id}").order('name')
    @prov_tariffs_device = @tariffs.select { |tariff| tariff.purpose == 'provider' || @dial_peer && tariff.id == @dial_peer.tariff_id.to_i }
  end

  def find_termination_point
    @termination_point = DpeerTpoint.where(id: params[:id]).first
    unless @termination_point
      flash[:notice] = _('termination_point_not_found')
      respond_to do |format|
        format.html { redirect_to(:root) && (return false) }
        format.json { render text: flash[:notice] }
      end
    end
  end
end