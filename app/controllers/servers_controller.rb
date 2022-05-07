# Servers' managing.
class ServersController < ApplicationController
  layout :determine_layout

  before_filter :check_post_method,
                only: [:destroy, :server_add, :server_update, :delete_device, :server_change_status]
  before_filter :check_localization, except: [:server_status_check]
  before_filter :authorize, except: [:server_status_check]
  before_filter :find_server,
                only: [
                    :show, :edit, :destroy, :server_change_gui, :server_change_db, :server_change_core,
                    :server_change_status, :server_change_gateway_status, :server_test, :server_update,
                    :server_devices_list, :assign_to_all_connection_points, :unassign_from_all_connection_points,
                    :server_change_es, :server_change_fs, :server_change_proxy, :server_change_b2bua,
                    :server_change_media
                ]
  before_filter :check_server_ip, only: [:server_update]

  def index
    if user? || reseller?
      dont_be_so_smart
      redirect_to :root && (return false)
    else
      redirect_to(action: :list) && (return false)
    end
  end

  def list
    @page_title = _('Servers')
    @page_icon = 'server.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Multi_Server_support'
    @servers = Server.order('id').all
    @select_server_type = %w[freeswitch other proxy]
  end

  def show
  end

  def new
    @page_title = _('Server_new')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Multi_Server_support'
    @server = Server.new
  end

  def edit
    @page_title = _('Server_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Multi_Server_support'
    @server_type = @server.server_type
    default_types = %w[freeswitch other proxy]
    @select_server_type = (default_types.exclude?(@server.server_type) && @server_type.present?) ? default_types << @server_type : default_types
  end

  def server_add
    param_new_server = params[:new_server]
    server = Server.server_add(param_new_server.presence || params) # fake form compatibility

    if server.valid? && server.save
      Server.m2_reload
      flash[:status] = _('Server_created')
      close_m2_form(:servers)
      redirect_to(action: :list) && (return false)
    else
      flash_errors_for(_('Server_not_created'), server)
    end

    redirect_to action: :list, new_server: param_new_server
  end

  def server_update
    server_type = params[:server_type_edit][:server_type].to_s.strip

    # Unnasign fs devices if changing from fs to another server type
    un_cond = server_type != 'freeswitch' && @server.server_type == 'freeswitch'
    ServerDevice.where("server_id = #{@server.id}").destroy_all if un_cond

    # Unset proxy server ip if changing from proxy to another server type
    @server.unset_proxy_server_confline if server_type != 'proxy' && @server.server_type == 'proxy'

    dev, @server, errors = Server.server_update(params, @server)

    if errors.zero? && @server.save
      # Update device
      if dev
        dev.assign_attributes(
            host: @server.hostname,
            ipaddr: @server.server_ip
        )
        dev.save
      end
      Server.m2_reload
      flash[:status] = _('Server_update')
    else
      flash_errors_for(_('Server_not_updated'), @server)
    end

    redirect_to action: :list
  end

  def delete_device
    param_id = params[:id]
    device = Device.where(id: param_id).first
    unless device
      flash[:notice] = _('Device_not_found')
      redirect_to(action: 'server_devices_list') && (return false)
    end
    param_server_id = params[:serv_id]
    server = Server.where(id: param_server_id).first
    unless server
      flash[:notice] = _('Server_not_found')
      redirect_to action: 'server_devices_list' && (return false)
    end
    server_device = ServerDevice.where(server_id: param_server_id, device_id: param_id).first
    server_device.destroy
    flash[:status] = _('device_deleted')
    redirect_to action: 'server_devices_list', id: param_server_id
  end

  def destroy
    if @server.destroy
      Server.elasticsearch_status_check(true)
      flash[:status] = _('Server_deleted')
    else
      flash_errors_for(_('Server_Not_Deleted'), @server)
    end
    redirect_to action: :list
  end

  def server_change_gui
    @server.gui = (@server.gui == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_db
    @server.db = (@server.db == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_core
    @server.core = (@server.core == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_es
    @server.es = (@server.es == 1) ? 0 : 1
    if @server.save
      Confline.set_value('ES_IP', (@server.es == 1 ? @server.server_ip : '127.0.0.1'))
      Server.elasticsearch_status_check(true)
    else
      flash_errors_for(_('Server_not_updated'), @server)
    end
    redirect_to action: :list, id: params[:id]
  end

  def server_change_fs
    @server.fs = (@server.fs == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_proxy
    @server.proxy = (@server.proxy == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_b2bua
    @server.b2bua = (@server.b2bua == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_media
    @server.media = (@server.media == 1) ? 0 : 1
    flash_errors_for(_('Server_not_updated'), @server) unless @server.save
    redirect_to action: :list, id: params[:id]
  end

  def server_change_status
    if @server.active == 1
      value = 0
      flash[:status] = _('Server_disabled')
    else
      value = 1
      flash[:status] = _('Server_enabled')
    end
    server_id = @server.id
    sql = "UPDATE servers SET active = #{value} WHERE id = #{server_id}"
    ActiveRecord::Base.connection.update(sql)
    redirect_to action: :list, id: server_id
  end


  def server_change_gateway_status
    server_id = params[:id]
    if @server.gateway_active == 1
      @server.gateway.destroy
      value = 0
      flash[:notice] = _('Server_marked_as_not_gateway')
    else
      gtw = Gateway.new(setid: 1, destination: "sip:#{@server.server_ip}:#{@server.port}", server_id: server_id)
      gtw.save
      value = 1
      flash[:status] = _('Server_marked_as_gateway')
    end
    sql = "UPDATE servers SET gateway_active = #{value} WHERE id = #{server_id}"
    res = ActiveRecord::Base.connection.update(sql)
    redirect_to action: :list, id: server_id
  end

  # When ccl_active = 1 shows all devices of a certain server
  def server_devices_list
    if !ccl_active? or (session[:usertype] != 'admin' and ccl_active?)
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @page_title = _('Server_devices')
    @page_icon = 'server.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Multi_Server_support'

    param_id = params[:id]
    # IP_auth + server_devices.server_id is null + server_devices.server_id is not that server + not server device(which were created with server creation)
    @devices = Device.select('devices.*, server_devices.server_id AS serv_id')
                     .joins("LEFT JOIN server_devices ON (server_devices.device_id = devices.id AND server_devices.server_id = #{param_id.to_i}) LEFT JOIN users ON (users.id = devices.user_id)")
                     .where("device_type != 'SIP' AND users.owner_id = #{current_user.id} AND server_devices.server_id IS NULL AND user_id != -1 AND name NOT LIKE 'mor_server_%'")
                     .order('extension ASC').all
  end

  def add_device_to_server
    @device = Device.where(id: params[:device_add].to_i).first
    device_id = @device.id
    unless @device
      flash[:notice] = _('Device_not_found')
      redirect_to(action: 'server_devices_list', id: param_id) && (return false)
    end
    serv_dev = ServerDevice.where(server_id: param_id, device_id: device_id).first

    if serv_dev
      flash[:notice] = _('Device_already_exists')
    else
      server_device = ServerDevice.new_relation(param_id, device_id)
      server_device.save
      flash[:status] = _('Device_added')
    end
    redirect_to(action: 'server_devices_list', id: param_id) && (return false)
  end

  def assign_unassign_connection_points(type)
    error = 0
    if @server.active != 1
      flash[:notice] = _('Server_must_be_active')
      error = 1
    end

    if @server.server_type != 'freeswitch'
      flash[:notice] = _('Server_Type_must_be_Freeswitch')
      error = 1
    end

    if Server.proxy_server_active
      flash[:notice] = _('Proxy_Server_is_active')
      error = 1
    end

    if Server.sip_proxy_server_present
      flash[:notice] = _('SIP_Proxy_Server_is_present')
      error = 1
    end

    if error == 0
      if type == 'assign'
        devices = Device.where("user_id != -1 AND devices.name NOT LIKE 'mor_server_%' AND accountcode != 0").pluck(:id)
        devices.each {|device_id| ServerDevice.where(server_id: @server.id, device_id: device_id).first_or_create }
        notice = _('Server_was_successfully_assigned_to_all_Connection_Points')
      elsif type == 'unassign'
        ServerDevice.where("server_id = #{@server.id}").destroy_all
        notice = _('Server_was_successfully_unassigned_to_all_Connection_Points')
      end
      flash[:status] = notice
    end

    redirect_to(action: :edit, id: @server.id) && (return false)
  end

  def assign_to_all_connection_points
    assign_unassign_connection_points('assign')
  end

  def unassign_from_all_connection_points
    assign_unassign_connection_points('unassign')
  end

  def server_status_check
    return render nothing: true, status: 403 unless request.local?
    Server.check_server_status
    render nothing: true, status: 200
  end

  def manual_server_status_check
    Server.server_statuses(true)
    flash[:status] = _('Servers_were_checked')
    redirect_to(action: :list) && (return false)
  end

  private

  def find_server
    @server = Server.where(id: params[:id]).first
    unless @server
      flash[:notice] = _('Server_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def check_server_ip
    server_id = params[:server_id]
    if server_id && Server.where(id: params[:id], server_id: server_id).first
      flash[:notice] = _('Server_ID_collision')
      redirect_to(action: :list) && (return false)
    end
  end
end
