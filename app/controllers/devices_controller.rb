# Device managing.
class DevicesController < ApplicationController
  require 'net/ssh'

  layout :determine_layout
  before_filter :access_denied, except: [:user_devices], if: -> { user? }
  before_filter :check_post_method, only: [:create, :update, :destroy, :device_update, :disconnect_code_changes_create,
                                           :disconnect_code_changes_destroy, :delete_dynamic_reg_info
  ]
  before_filter :check_localization
  before_filter :authorize_assigned_users, only: [:show_devices, :new], if: -> { current_user.try(:show_only_assigned_users?) }
  before_filter :authorize
  before_filter :find_device, only: [:destroy, :device_edit, :device_update, :device_extlines,
                                     :try_to_forward_device, :device_all_details, :user_device_edit,
                                     :user_device_update, :erase_ipaddr_fullcontact, :disconnect_code_changes,
                                     :disconnect_code_changes_create, :device_hide, :delete_dynamic_reg_info
  ]
  before_filter :find_cli, only: [:cli_delete, :cli_user_delete, :cli_device_delete, :cli_edit,
                                  :cli_update, :cli_device_edit, :cli_user_edit,
                                  :cli_device_update, :cli_user_update
  ]
  before_filter :verify_params, only: [:create]
  before_filter :check_with_integrity, only: [:create, :device_update, :device_edit, :show_devices]
  before_filter :load_cli_params, only: [:cli_new, :cli_add]
  before_filter :erase_ipaddr_fullcontact, only: [:device_update]
  before_filter :check_if_sip_proxy_active, only: [:new, :create, :device_edit, :default_device]
  before_filter :check_m4_functionality, only: [:disconnect_code_changes]

  def index
    redirect_to(action: :user_devices) && (return false)
  end

  def new
    @page_title = _('New_device')
    @page_icon = 'add.png'
    @ccl_active = ccl_active?

    check_reseller_conflines(User.where(id: session[:user_id]).first) if reseller?

    @user = User.where(id: params[:user_id]).first
    user = @user

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    if %w[admin accountant reseller].include?(user.usertype)
      flash[:notice] = _('Deprecated_functionality') +
                       " <a href='http://wiki.ocean-tel.uk/index.php/Deprecated_functionality' target='_blank'><img alt='Help' " +
                       "src='#{Web_Dir}/images/icons/help.png'/></a>".html_safe
      redirect_to(:root) && (return false)
    end

    check_owner_for_device(user)

    device_type = Confline.get_value('Default_device_type', correct_owner_id)
    @device = Device.new(device_type: device_type, pin: new_device_pin)
    @device_type = 'SIP'
    @audio_codecs = audio_codecs
    @video_codecs = video_codecs
    @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split
    @allow_dynamic_op_auth_with_reg = Confline.get_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration').to_i
    set_qualify_time
    @new_device = true
  end

  def create
    user = User.where(id: params[:user_id]).includes(:address).first

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    session_pin = session[:device][:pin]
    params[:device][:pin] = session_pin if session[:device] && session_pin
    notice, par = Device.validate_before_create(current_user, user, params, allow_dahdi?, allow_virtual?)
    user_id = user.id
    if notice.present?
      flash[:notice] = notice
      redirect_to(controller: :devices, action: :new, user_id: user_id, device: params[:device]) && (return false)
    end

    par_device = par[:device]
    device = user.create_default_device(
      device_ip_authentication_record: par[:ip_authentication].to_i,
      description: par_device[:description], device_type: par_device[:device_type],
      pin: par_device[:pin], ipaddr: par_device[:ipaddr], create_rg_for_op: params[:create_rg_for_op].to_i,
      op: params[:device][:op], tp: params[:device][:tp]
    )

    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").first
    @allow_dynamic_op_auth_with_reg = Confline.get_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration').to_i
    device.set_server(device, ccl_active?, @sip_proxy_server, reseller?)
    device.set_ports(params[:port]) if device.ipaddr.present?
    # If someday dynamic devices will exist again, this should be changed
    # device.ipauth_insecurities_on_create

    if device.save
      device.create_server_relations(device, @sip_proxy_server, ccl_active?)
      flash[:status] = _('device_created')
    else
      flash_errors_for(_('device_not_created'), device)
      redirect_to(controller: 'devices', action: 'show_devices', id: user_id) && (return false)
    end

    redirect_to(controller: 'devices', action: 'device_edit', id: device.id) && (return false)
  end

  def edit
    @user = User.where(id: params[:id]).first

    unless @user
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    @ccl_active = ccl_active?
  end

  # in before filter : device (:find_device)
  def destroy
    @return_controller = 'devices'
    @return_action = 'show_devices'
    set_return_controller
    set_return_action
    #device_server_id = @device.server_id
    device_user_id = @device.user_id

    return false unless check_owner_for_device(device_user_id)

    err = ''
    notice = @device.validate_before_destroy(current_user)
    if notice.present?
      flash[:notice] = notice
      if params[:action_from].present?
        redirect_to(action: :cp_list, only_hidden: params[:only_hidden].to_i == 1 ? 1 : 0) && (return false)
      else
        redirect_to(controller: @return_controller, action: @return_action, id: device_user_id) && (return false)
      end
    else
      err = @device.destroy_all
    end

    flash[:status] = _('device_deleted')
    flash[:notice] = err.first if err.present?
    if params[:action_from].present?
      redirect_to(action: :cp_list, only_hidden: params[:only_hidden].to_i == 1 ? 1 : 0)
    else
      redirect_to(controller: @return_controller, action: @return_action, id: device_user_id)
    end
  end

  def show_devices
    @page_title = _('connection_points')
    @page_icon = 'device.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Devices'

    @user = User.where(['id = ? AND (owner_id = ? or users.id = ?)', params[:id], correct_owner_id, current_user_id])
                .includes(:devices).first
    user = @user

    unless user.try :is_user?
      flash[:notice] = _('User_not_found')
      redirect_to(:root) && (return false)
    end

    dev_owner = check_owner_for_device(user)
    return false unless dev_owner

    @return_controller = 'users'
    @return_action = 'list'
    set_return_controller
    set_return_action

    set_page_and_devices_for_it(user.devices.visible)

    store_location
  end

  # in before filter : device (:find_device)
  def device_edit
    @page_title = _('device_settings')
    # @page_icon = 'edit.png'

    set_return_controller
    set_return_action

    if reseller?
      reseller = User.where(id: session[:user_id]).first
      check_reseller_conflines(reseller)
    end

    @user = @device.user
    return false unless check_owner_for_device(@user)

    if @device.name.to_s =~ /\Amor_server_\d+\z/
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @device_type = @device.device_type
    device_type = @device_type
    @device_trunk = @device.trunk
    set_cid_name_and_number

    @server_devices = []
    @device.server_devices.each { |device| @server_devices[device.server_id] = 1 }

    @device_cids = @device.cid_number_nice
    @device_caller_id_number = @device.device_caller_id_number
    @device_callerid_number_pool_type = @device.callerid_number_pool_type
    @device_callerid_number_pool_deviation = @device.callerid_number_pool_deviation
    @sticky_contact = @device.sticky_contact
    #sticky_contact = @sticky_contact
    get_number_pools

    @audio_codecs = @device.codecs_order('audio') # audio_codecs
    @video_codecs = @device.codecs_order('video') # video_codecs

    @allow_dynamic_op_auth_with_reg = Confline.get_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration').to_i
    # -------multi server support------

    @asterisk_servers = Server.order('id ASC')
    @sip_proxy_server = [Server.where("server_type = 'sip_proxy'").first]

    set_servers(device_type)

    # ------ permits --------
    @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split

    # ------ advanced --------
    set_qualify_time
    @extension = @device.extension
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i

    # TP/OP related
    get_tariffs
    @custom_tariffs = Tariff.where("purpose = 'user_custom' AND owner_id = #{correct_owner_id}").order('name ASC').all
    @prov_tariffs_device = @tariffs.select { |tariff| tariff.purpose == 'provider' || tariff.id == @device.tp_tariff_id.to_i }
    @user_wholesale_tariffs_device = @tariffs.select { |tariff| tariff.purpose == 'user_wholesale' || tariff.id == @device.op_tariff_id.to_i }

    @routing_algorithms = [[_('LCR'), 'lcr'], [_('weight'), 'weight'], [_('Percent'), 'percent'], [_('By_Dial_Peer'), 'by_dialpeer'], [_('Quality'), 'quality']]
    @qrs = QualityRouting.order('name ASC')

    @routing_groups = RoutingGroup.rg_dropdown(current_user)
  end

  # in before filter : device (:find_device)
  def device_update
    (redirect_to(:root) && (return false)) unless params[:device]

    # if higher than zero -> do not update device
    device_update_errors = 0

    return false unless check_owner_for_device(@device.user)
    device_server_id = @device.server_id
    @device_old = @device.dup

    @device.set_old_name
    params[:device][:op_tech_prefix].to_s.strip!
    params[:device][:description] = params[:device][:description].to_s.strip
    params[:device][:max_timeout] = params[:device][:max_timeout].to_s.strip
    params[:ip_authentication_dynamic] = 1
    device_type = @device.device_type
    device_type_is_sip = (device_type == 'SIP')
    device_type_not_virtual = (device_type != 'Virtual')
    grace_time_params = params[:grace_time].to_i
    @device.grace_time = (grace_time_params > 0) ? grace_time_params : 0

    if ['SIP'].include?(device_type)
      if params[:ip_authentication_dynamic].to_i > 0
        params[:dynamic_check] = (params[:ip_authentication_dynamic].to_i == 2) ? 1 : 0
        params[:ip_authentication] = (params[:ip_authentication_dynamic].to_i == 1) ? 1 : 0
      else
        @device.username.blank? ? params[:ip_authentication] = 1 : params[:dynamic_check] = 1
      end
    end

    params[:device][:device_type] = device_type

    @sip_proxy_server_active = Server.where(server_type: 'proxy').count

    # If we don't have proxy server, keep only selected servers
    # Otherwise assign all freeswitch servers to device
    server_devices = if !Server.proxy_server_active && !Server.single_fs_server_active
                       params[:add_to_servers].try(:reject) { |_, value| value.to_i == 0 }
                     elsif Server.proxy_server_active
                       Server.where("server_type = 'freeswitch' OR fs = 1").all.pluck(:id).map { |id| [id, '1'] }
                     elsif Server.single_fs_server_active
                       [[Server.where(active: 1).first.id, '1']]
                     end

    # if server_devices.blank? && !ccl_active?
    #  @device.errors.add(:add_to_servers_error, _('Please_select_server'))
    #  device_update_errors += 1
    # end

    @allow_dynamic_op_auth_with_reg = Confline.get_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration').to_i
    # ============multi server support===========
    @asterisk_servers = Server.order('id ASC')
    @sip_proxy_server = [Server.where("server_type = 'sip_proxy'").first]

    set_servers(device_type)

    # ========= Reseller device server ==========

    if reseller?
      if ccl_active? && params[:device][:device_type] == 'SIP' # and params[:dynamic_check] == 1
        params[:add_to_servers] = @sip_proxy_server
      else
        first_srv = Server.first.id
        def_asterisk = Confline.get_value('Resellers_server_id').to_i
        def_asterisk = first_srv if def_asterisk.to_i == 0
        params[:device][:server_id] = def_asterisk
      end
    end
    # ===========================================

    params[:device][:pin] = params[:device][:pin].to_s.strip
    if params[:call_limit]
      params[:device][:call_limit] = params[:call_limit].to_s.strip
      params[:device][:call_limit] = 0 if params[:call_limit].to_i < 0
    end

    # ========================== check input ============================================

    # because block_callerid input may be disabled and it will not be sent in
    # params and setter will not be triggered and value from enabled wouldnt be
    # set to disabled, so i we have to set it here. you may call it a little hack
    params[:device][:block_callerid] = 0 if params[:block_callerid_enable].to_s == 'no'

    if device_type_not_virtual
      params[:device][:extension] = params[:device][:extension].to_s.strip if params[:device][:extension]
      params[:device][:timeout] = params[:device_timeout].to_s.strip
    end

    device_is_dahdi = @device.is_dahdi?

    if !@new_device && device_type_not_virtual
      params[:device][:name] = params[:device][:name].to_s.strip
      params[:device][:secret] = params[:device][:secret].to_s.strip unless device_is_dahdi
    end

    unless @new_device
      params[:cid_number] = remove_zero_width_space(params[:cid_number].to_s.strip)
      params[:device_caller_id_number] = params[:device_caller_id_number].to_i
      params[:cid_name] = params[:cid_name].to_s.strip
    end

    if !@new_device && device_type_not_virtual
      unless device_is_dahdi
        params[:host] = params[:host].to_s.strip
        params[:port] = params[:port].to_s.strip if @device.host != 'dynamic'

        if ccl_active? && device_type_is_sip # and (@device.host == "dynamic" or @device.host.blank?)
          qualify = 2000
          params[:qualify] = 'no'
        else
          qualify = params[:qualify_time].to_s.strip.to_i
          qualify = 2000 unless params[:qualify_time]
          if qualify < 500
            @device.errors.add(:qualify, _('qualify_must_be_greater_than_500'))
            device_update_errors += 1
          end
        end
        params[:qualify_time] = qualify
      end
    end

    if !@new_device && device_type_not_virtual
      params[:callgroup] = params[:callgroup].to_s.strip
      params[:pickupgroup] = params[:pickupgroup].to_s.strip
    end

    if !@new_device && device_type_not_virtual
      unless device_is_dahdi
        [:ip_first, :ip_second, :ip_third, :mask_first, :mask_second, :mask_third].each do |var|
          params[var] = params[var].to_s.strip
        end

        if device_type_is_sip
          params[:custom_sip_header] = params[:custom_sip_header].to_s.strip if params[:custom_sip_header]
        end
      end
    end

    unless @new_device
      params[:device][:tell_rtime_when_left] = params[:device][:tell_rtime_when_left].to_s.strip
      params[:device][:repeat_rtime_every] = params[:device][:repeat_rtime_every].to_s.strip
    end

    # ============================= end  ============================================================

    if params[:device][:name] && !params[:device][:name].to_s.scan(/[^\w\.\@\$\-]/).compact.empty?
      @device.errors.add(:device_name_error, _('Device_username_must_consist_only_of_digits_and_letters'))
      device_update_errors += 1
    end

    regexp_array = []
    regexp_array.concat [params[:device][:op_src_regexp], params[:device][:op_src_deny_regexp]] if params[:device][:op].to_i == 1
    regexp_array.concat [params[:device][:tp_src_regexp], params[:device][:tp_src_deny_regexp]] if params[:device][:tp].to_i == 1

    regexp_array.each { |regexp|
      begin
        Regexp.new(regexp.to_s.strip)
      rescue RegexpError => e
        @device.errors.add(:device_regexp_error, _('Invalid_regexp') + ' - ' + e.to_s)
        device_update_errors += 1
      end
    }

    is_params_device_dynamic = params[:device][:dynamic].to_s == 'yes'
    unless is_params_device_dynamic
      @device, device_update_errors = Device.validate_ip_address_format(params, @device, device_update_errors)
    end

    # ticket 5055. ip auth or dynamic host must checked
    if params[:dynamic_check].to_i != 1 && params[:ip_authentication].to_i != 1 && ['SIP'].include?(device_type)
      if params[:host].to_s.strip.blank?
        @device.errors.add(:dynamic_check_error, _('Must_set_either_ip_auth_either_dynamic_host'))
        device_update_errors += 1
      else
        params[:ip_authentication] = '1'
      end
    end

    if params[:device][:extension] && extension_exists?(params[:device][:extension], @device_old.extension)
      @device.errors.add(:extension_error, _('Extension_is_used'))
      device_update_errors += 1
    end
    # pin
    if Device.where(['id != ? AND pin = ?', @device.id, params[:device][:pin]]).first && params[:device][:pin].to_s != ''
      @device.errors.add(:pin_is_used_error, _('Pin_is_already_used'))
      device_update_errors += 1
    end

    unless params[:device][:pin].to_s.strip.scan(/[^0-9]/).compact.empty?
      @device.errors.add(:not_numeric_pin_error, _('Pin_must_be_numeric'))
      device_update_errors += 1
    end

    @device.device_ip_authentication_record = params[:ip_authentication].to_i
    params[:device] = params[:device].reject { |key, _| ['extension'].include?(key.to_s) } if current_user.usertype == 'reseller' && Confline.get_value('Allow_resellers_to_change_extensions_for_their_user_devices').to_i == 0

    params[:device][:pin] = @device.pin if params[:device][:pin].blank? && current_user.usertype == 'reseller'

    params[:device][:secret] = @device.secret if @device.register == 1

    params[:device][:op_tariff_id] = @device.op_tariff_id if params[:device][:op].to_i == 0
    @device.attributes = params[:device]

    @device.name = '' if @device.name.include?('ipauth') && params[:ip_authentication].to_i == 0

    # Do not leave empty name
    @device.name = (!@device.host.empty? ? @device.extension : random_password(10)) if @device.name.to_s.empty?

    if params[:ip_authentication].to_s == '1'

      if @device.register != 1
        @device.username = ''
        @device.secret = ''
      end

      unless @device.name.include?('ipauth')
        name = @device.generate_rand_name('ipauth', 8)

        while Device.where(['name= ? and id != ?', name, @device.id]).first
          name = @device.generate_rand_name('ipauth', 8)
        end

        @device.name = name
      end
    else
      @device.username = @device.name unless @device.virtual?

      @device.check_device_username if !@device_old.virtual? && @device.virtual?
    end

    if params[:device][:tp].to_i == 1
      if params[:device][:register].to_i == 1
        if params[:device][:username].blank?
          @device.errors.add(:username, _('Username_cannot_be_blank'))
          device_update_errors += 1
        end

        if params[:password][:secret].blank?
          @device.errors.add(:secret, _('Password_cant_be_empty'))
          device_update_errors += 1
        end
      end

      @device.assign_attributes(register: params[:device][:register].to_i,
                                username: params[:device][:username].to_s.strip,
                                secret: params[:password][:secret].to_s.strip)


      if params[:device][:tp_auth].to_i == 1
        if params[:device][:tp_username].blank?
          @device.errors.add(:tp_username, _('Username_cannot_be_blank'))
          device_update_errors += 1
        end

        if params[:device][:tp_password].blank?
          @device.errors.add(:tp_password, _('Password_cant_be_empty'))
          device_update_errors += 1
        end

        if params[:device][:tp_register].to_i == 1
          if params[:device][:tp_expires].to_i < 60
            params[:device][:tp_expires] = 60
          end
        end
      end

      @device.assign_attributes(tp_auth: params[:device][:tp_auth].to_i,
                                tp_username: params[:device][:tp_username].to_s.strip,
                                tp_password: params[:device][:tp_password].to_s.strip,
                                tp_register: params[:device][:tp_register].to_i,
                                tp_expires: params[:device][:tp_expires].to_i
                                )

      if Confline.get_value('Use_Number_Portability', 0, 0).to_i == 1 && params[:device][:mnp_carrier_group_id].present?
        none_value = params[:device][:mnp_carrier_group_id].to_i == -1
        @device.mnp_carrier_group_id = none_value ? nil : params[:device][:mnp_carrier_group_id].to_i
      end
    # ticket 16323
    else
      # register: 0,
      # username: nil,
      # secret: nil,
      # tp_tech_prefix: nil,
      # tp_tariff_id: nil,
      # tp_capacity: 500,
      # tp_src_regexp: '.*',
      # tp_src_deny_regexp: nil
      @device.assign_attributes(tp_active: 0)

    end

    # op_tech_prefix: nil,
    # op_destination_transformation: nil,
    # op_routing_algorithm: nil,
    # quality_routing_id: 0,
    # op_routing_group_id: nil,
    # op_tariff_id: nil,
    # op_capacity: 500,
    # op_src_regexp: '.*',
    # op_src_deny_regexp: nil
    @device.assign_attributes(op_active: 0) if params[:device][:op].to_i == 0

    if Confline.get_value('Use_Number_Portability', 0, 0).to_i == 1 && params[:device][:op].to_i == 1
      @device.mnp_use = params[:device][:mnp_use].to_i if params[:device][:mnp_use].present?
      @device.mnp_routing_group_id = params[:device][:mnp_routing_group_id].to_i if params[:device][:mnp_routing_group_id].present?
    end

    @device.assign_attributes(progress_timeout: 0) if params[:device][:tp].to_i == 0 && !m4_functionality?

    qr_id = if params[:device][:op_routing_algorithm] == 'quality'
              params_qr_id = params[:device][:quality_routing_id]
              if params_qr_id.blank?
                @device.errors.add(:no_quality_routings, _('Quality_Routing_needs_Rules'))
                device_update_errors += 1
                0
              end
              params_qr_id
            else
              0
            end
    @device.assign_attributes(quality_routing_id: qr_id)

    if device_update_errors == 0
      @device.update_cid(params[:cid_name], remove_zero_width_space(params[:cid_number]), true)
      @device.assign_attributes(
          control_callerid_by_cids: (params[:device_caller_id_number].to_i == 4) ? params[:control_callerid_by_cids].to_i : 0,
          callerid_advanced_control: (params[:device_caller_id_number].to_i == 5) ? 1 : 0
      )
      if admin?
        @device.callerid_number_pool_id = (params[:device_caller_id_number].to_i == 7) ? params[:callerid_number_pool_id].to_i : 0

        if params[:device_caller_id_number].to_i == 7
          @device.callerid_number_pool_type = (%w[random pseudorandom].include?(params[:callerid_number_pool_type].to_s) ? params[:callerid_number_pool_type].to_s : 'random')

          if params[:callerid_number_pool_type].to_s == 'pseudorandom'
            callerid_number_pool_deviation = params[:callerid_number_pool_deviation].to_i
            if callerid_number_pool_deviation.between?(0, 9999999)
              @device.callerid_number_pool_deviation = callerid_number_pool_deviation
            else
              @device.errors.add(:pseudorandom_deviation_is_not_valid_error, _('Pseudorandom_Deviation_must_be_integer_value_between_0_and_9999999'))
              device_update_errors += 1
            end
          end
        end
      end
    end

    # ================ codecs ===================

    @device.update_codecs_with_priority(params[:codec], false) if params[:codec]
    # ============= PERMITS ===================
    if params[:mask_first]
      if !Device.validate_permits_ip([params[:ip_first], params[:ip_second], params[:ip_third], params[:mask_first], params[:mask_second], params[:mask_third]])
        @device.errors.add(:allowed_ip_is_not_valid_error, _('Allowed_IP_is_not_valid'))
        device_update_errors += 1
      else
        @device.permit = Device.validate_perims(ip_first: params[:ip_first], ip_second: params[:ip_second], ip_third: params[:ip_third],
                                                mask_first: params[:mask_first], mask_second: params[:mask_second], mask_third: params[:mask_third])
      end
    end

    # ------ advanced --------

    if params[:qualify] == 'yes'
      @device.qualify = params[:qualify_time]
      @device.qualify == '2000' if @device.qualify.to_i < 500
    else
      @device.qualify = 'no'
    end
    sticky_contact = params[:sticky_contact].to_s
    @device.sticky_contact = sticky_contact.presence || '0'

    # ------- Network related -------

    if is_params_device_dynamic
      params_op_username = params[:op_username].to_s.strip
      if params_op_username.present? && Device.where('id != ? AND op_username = ?', @device.id, params_op_username).first.present?
        @device.errors.add(:dynamic_auth_username_must_be_unique, _('Dynamic_Authentication_Username_must_be_unique'))
        device_update_errors += 1
        @device.dynamic = @device_old.dynamic
      else
        if @device_old.dynamic != 'yes'
          @device.host = ''
          @device.ipaddr = ''
          @device.port = nil
        end
        @device.dynamic = 'yes'

        @device.op_username = params_op_username
        @device.op_password = params[:op_password].to_s.strip
      end
    else
      @device.dynamic = nil
      @device.host = params[:host] if params[:host]
      @device.host = 'dynamic' if params[:dynamic_check].to_i == 1

      @device.ipaddr = @device.host if @device.host != 'dynamic'

      # ticket #4978, previuosly there was a validation to disallow ports lower than 100
      # we have doubts whether this made any sense. so user now can set port to any positive integer
      params_port = params[:port].to_s.strip
      @device.port = params_port if params_port
      @device.port = Device::DefaultPort['SIP'] if @device.device_type == 'SIP' && !Device.valid_port?(params[:port], @device.device_type)
    end

    @device.proxy_port = (ccl_active? && device_type_is_sip && params[:zero_port].to_i == 1) ? 0 : @device.port

    # ------Trunks-------
    case params[:trunk].to_i
      when 0
        @device.istrunk = 0
        @device.ani = 0
      when 1
        @device.istrunk = 1
        @device.ani = 0
      when 2
        @device.istrunk = 1
        @device.ani = 1
    end

    if admin?
      # ------- Groups -------
      @device.callgroup = params[:callgroup]
      @device.pickupgroup = params[:pickupgroup]
    end

    # ------- Advanced -------

    @device.adjust_insecurities(ccl_active?, params)

    @device.custom_sip_header = params[:custom_sip_header].presence || ''

    # check for errors
    @device.host = 'dynamic' unless @device.host
    @device.transfer = 'no' unless @device.transfer
    @device.canreinvite = 'no' unless @device.canreinvite
    @device.ipaddr = '0.0.0.0' unless @device.ipaddr
    @device[:timeout] = 10 if @device[:timeout].to_i < 10
    @device.tp_tariff_id = params[:device][:tp_tariff_id].to_i if params[:device][:tp_tariff_id].present?
    @device.assign_advanced_auth_settings(params[:device]) if params[:dev_auth_mode].to_i == 1
    if params[:vm_email].present?
      unless Email.address_validation(params[:vm_email])
        @device.errors.add(:incorrect_email_error, _('Email_address_not_correct'))
        device_update_errors += 1
      end
    end

    @device.mailbox = (@device.enable_mwi.to_i == 0) ? '' : @device.extension.to_s + '@default'
    @device.context = (@device.context && (@device.op == 1)) ? 'm2' : 'mor_local'

    if device_update_errors == 0 && @device.save
      #----------server_devices table changes---------
      @device.create_server_devices(server_devices)

      # cleaning asterisk cache when device details changes
      device_server = Server.where(id: @device.server_id).first

      if device_server.server_type == 'asterisk'
        if (@device.name != @device.device_old_name) || (@device.server_id != @device.device_old_server)
          @device.sip_prune_realtime_peer(@device.device_old_name, @device.device_old_server)
        end
      end

      conf_extensions = configure_extensions(@device.id, current_user: current_user)
      return false unless conf_extensions
      flash[:status] = _('phones_settings_updated')
      session_user_id = session[:user_id]

      # actions to report who changed what in device settings.
      device_old_pin = @device_old.pin
      if device_old_pin != @device.pin
        Action.add_action_hash(session_user_id, target_id: @device.id, target_type: 'device',
                                                 action: :device_pin_changed, data: device_old_pin, data2: @device.pin)
      end

      device_old_secret = @device_old.secret
      if device_old_secret != @device.secret
        Action.add_action_hash(session_user_id, target_id: @device.id, target_type: 'device',
                                                 action: :device_secret_changed, data: device_old_secret, data2: @device.secret)
      end

      if @device.tp_auth.to_i == 1 && @device.tp_register.to_i == 1
        m4_tp_refresh(@device.tp_l_uuid)
      end

      if (@device_old.tp_auth.to_i == 1 && @device.tp_auth.to_i == 0) ||
          (@device_old.tp_register.to_i == 1 && @device.tp_register.to_i == 0)
        m4_tp_remove(@device.tp_l_uuid)
      end

      redirect_to(action: :show_devices, id: @device.user_id) && (return false)
    else
      flash_errors_for(_('Device_not_updated'), @device)

      server_devices = params[:add_to_servers] || {}
      @server_devices = Hash[server_devices.keys.map(&:to_i).zip(server_devices.values)]
      @user = @device.user
      @device_type = device_type

      @device_cids = remove_zero_width_space(params[:cid_number].to_s)
      @device_caller_id_number = params[:device_caller_id_number].to_i
      @device_callerid_number_pool_type = (%w[random pseudorandom].include?(params[:callerid_number_pool_type].to_s) ? params[:callerid_number_pool_type].to_s : 'random')
      @device_callerid_number_pool_deviation = params[:callerid_number_pool_deviation].to_s
      @sticky_contact = @device.sticky_contact
      @cid_name = params[:cid_name].to_s.strip
      @cid_number = remove_zero_width_space(params[:cid_number].to_s.strip)

      @audio_codecs = audio_codecs
      @video_codecs = video_codecs

      # ------ permits --------

      @ip_first, @mask_first, @ip_second, @mask_second, @ip_third, @mask_third = @device.perims_split

      # ------ advanced --------
      set_qualify_time
      @extension = @device.extension

      @fullname = params[:vm_fullname].to_s.strip

      @number_pools = NumberPool.order('name ASC').all.collect { |number| [number.name, number.id] } if admin? || manager?

      # TP/OP related
      get_tariffs
      @custom_tariffs = Tariff.where("purpose = 'user_custom' AND owner_id = #{correct_owner_id}").order('name ASC').all
      @prov_tariffs_device = @tariffs.select { |tariff| tariff.purpose == 'provider' }
      @user_wholesale_tariffs_device = @tariffs.select { |tariff| tariff.purpose == 'user_wholesale' }
      @routing_algorithms = [[_('LCR'), 'lcr'], [_('Quality'), 'quality'], [_('Profit'), 'profit'], [_('weight'), 'weight'], [_('Percent'), 'percent'], [_('By_Dial_Peer'), 'by_dialpeer']]
      @routing_groups = RoutingGroup.order('name ASC').all

      render :device_edit
    end
  end

  # in before filter : device (:find_device)
  def device_extlines
    @page_title = _('Ext_lines')
    @page_icon = 'asterisk.png'

    @extlines = nil unless @extlines = @device.extlines

    @user = @device.user

    render(layout: false) if params[:context] == :show
  end

  def device_forward
    @page_title = _('Device_forward')
    @page_icon = 'forward.png'

    @devices = Device.where("name not like 'mor_server_%'").order(:extension)

    @device = Device.where(id: params[:id]).first
    @user = @device.user
  end

  # In before filter : device (:find_device)
  def try_to_forward_device
    @fwd_to = params[:select_fwd]
    fwd_to = @fwd_to
    fwd_to_not_zero = (fwd_to != '0')
    can_fwd = true

    device_fwd_to = Device.where(id: fwd_to).first if fwd_to_not_zero || can_fwd

    if fwd_to_not_zero
      # checking can we forward
      device = device_fwd_to
      device_forward_to = device.forward_to
      device_to_forward = (device_forward_to == @device.id)
      can_fwd = false if device_to_forward

      while !(device_forward_to == 0 || device_to_forward)
        device = Device.where(id: device_forward_to).first
        can_fwd = false if device_to_forward
      end

    end

    device_name = _('device') + ' ' + @device.name.to_s + ' '

    if can_fwd
      flash[:status] = if fwd_to_not_zero
                         device_name + _('forwarded_to') + ' ' + device_fwd_to.name.to_s
                       else
                         device_name + _('forward_removed')
                       end

      @device.forward_to = fwd_to
      @device.save

      conf_extensions = configure_extensions(@device.id, current_user: current_user)
      return false unless conf_extensions
    else
      flash[:notice] = device_name + _('not_forwarded_close_circle')
    end

    redirect_to(action: :device_forward, id: @device)
  end

  # ============ CallerIDs ===============

  def user_device_clis
    @page_title = _('CallerIDs')
    @page_icon = 'cli.png'

    unless user?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @user = User.where(id: session[:user_id]).first
    @devices = @user.devices
    @clis = []
  end

  # in before filter : device (:find_device)
  def device_clis
    redirect_to(action: :clis, device_id: params[:id]) if params[:id]
  end

  def load_cli_params
    @selected = {}
    set_options_from_params(@selected, params,
                            cli: '',
                            device_id: 0,
                            user: -1,
                            description: '',
                            comment: '',
                            banned: 0,
    )
  end

  def cli_new
    @page_title = 'CLI ' + _('Add')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/CLIs'

    @current_user_id = current_user_id

    @users = User.where(owner_id: @current_user_id)
    @users.sort_by! { |user| nice_user(user).downcase }
  end

  def cli_add
    @page_title = 'CLI ' + _('add')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/CLIs'

    @current_user_id = current_user_id

    @users = User.where(owner_id: @current_user_id)
    create_cli
    if flash[:status]
      redirect_to(action: :clis)
    else
      render :cli_new
    end
  end

  def cli_device_add
    create_cli
    redirect_to(action: :clis, id: params[:device_id]) && (return false)
  end

  def cli_user_add
    create_cli
    redirect_to(action: :user_device_clis) && (return false)
  end

  def cli_delete
    cli_cli = @cli.cli
    @cli.destroy ? flash[:status] = _('CLI_deleted') + ": #{cli_cli}" : flash[:notice] = _('CLI_is_not_deleted') + '<br/>' + '* ' + _('CID_is_assigned_to_Device')
    redirect_to(action: :clis) && (return false)
  end

  def cli_user_delete
    cli_cli = @cli.cli
    @cli.destroy
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to(action: :user_device_clis) && (return false)
  end

  def cli_device_delete
    cli_cli = @cli.cli
    device_id = @cli.device_id
    if @cli.destroy
      flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    else
      flash_errors_for(_('CLI_is_not_deleted'), @cli)
    end
    flash[:status] = _('CLI_deleted') + ": #{cli_cli}"
    redirect_to(action: :clis, id: device_id) && (return false)
  end

  def cli_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/CLIs'
    @device = @cli.device
    #  check_owner_for_device(@device.user)
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) || admin? || reseller?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def cli_update
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/CLIs'

    @device = @cli.device
    @user = @device.user

    @cli.assign_attributes(cli: params[:cli],
                            description: params[:description],
                            comment: params[:comment],
                            banned: ((params[:banned].to_i == 1) ? 1 : 0)
                           )

    if @cli.save
      flash[:status] = _('CLI_updated')
      redirect_to(action: :clis) && (return false)
    else
      flash_errors_for(_('CLI_not_created'), @cli)
      render :cli_edit
    end
  end

  def cli_device_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'

    @device = @cli.device
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) || admin?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def cli_user_edit
    @page_title = _('CLI_edit')
    @page_icon = 'edit.png'
    @device = @cli.device
    @user = @device.user
    user = @user
    session_user_id = session[:user_id].to_i

    unless user && (user.id == session_user_id) || (user.owner_id == session_user_id) || admin?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def cli_device_update
    @cli.assign_attributes(cli: params[:cli],
                            description: params[:description],
                            comment: params[:comment],
                            banned: ((params[:banned].to_i == 1) ? 1 : 0)
                           )
    if @cli.save
      flash[:status] = _('CLI_updated')
      redirect_to(action: :clis, id: @cli.device_id)
    else
      flash_errors_for(_('CLI_not_created'), @cli)
      redirect_to(action: :cli_device_edit, id: @cli.id)
    end
  end

  def cli_user_update
    params_id = params[:id]
    unless cli = Callerid.where(id: params_id).first
      flash[:notice] = _('Callerid_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    cli.assign_attributes(cli: params[:cli],
                           description: params[:description],
                           comment: params[:comment],
                           banned: ((params[:banned].to_i == 1) ? 1 : 0)
                          )
    if cli.save
      flash[:status] = _('CLI_updated')
      redirect_to(action: :user_device_clis) && (return false)
    else
      flash_errors_for(_('CLI_not_created'), cli)
      redirect_to(action: :cli_user_edit, id: params_id)
    end
  end

  def clis
    @page_title = _('CLIs')
    @page_icon = 'cli.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/CLIs'

    # Clear form

    if params[:clear] == 'true'
      @searched = false
      session[:search] = nil
    end

    # Order
    @options = session[:cli_list_options] || {}

    set_options_from_params(@options, params, order_by: 'cli', order_desc: 0)
    order_by = Device.clis_order_by(@options)

    session[:cli_list_options] = @options

    # Search

    @search = session[:search] || {}

    params_device_id = params[:device_id]
    if params_device_id && params[:s_user].blank?
      dev = Device.where(id: params_device_id).first
      params[:s_user] = dev.user_id if dev
    end

    set_options_from_params(@search, params, {
        cli: '',
        device: -1,
        user: -1,
        banned: -1,
        description: '',
        comment: ''
    }, 's_')

    @search[:device] = params_device_id.to_s.strip if params_device_id

    cond = ''

    session[:search] = @search
    search_user = @search[:user]
    search_user_number = search_user.to_i
    search_device = @search[:device]
    search_device_number = search_device.to_i
    search_cli = @search[:cli]
    search_banned = @search[:banned]
    if search_user_number != -1
      cond += "  AND devices.user_id = '#{search_user}' "
      cond += " AND callerids.device_id = '#{search_device}' " if search_device_number != -1
    end

    cond += " AND devices.user_id = '#{search_user}' " if search_user_number != -1
    cond += " AND callerids.device_id = '#{search_device}' " if search_device_number != -1
    cond += " AND callerids.cli LIKE '#{search_cli}' " unless search_cli.empty?
    cond += " AND callerids.banned =  '#{search_banned}' " if search_banned.to_i != -1
    cond += " AND callerids.description LIKE '#{@search[:description]}%' " unless @search[:description].empty?
    cond += " AND callerids.comment LIKE  '#{@search[:comment]}%' " unless @search[:comment].empty?

    @current_user_id = current_user_id

    @clis = Callerid.select('callerids.* , devices.user_id , devices.name, devices.extension, devices.device_type, devices.istrun ')
                    .joins('JOIN devices on (devices.id = callerids.device_id)')
                    .joins('JOIN users on (users.id = devices.user_id)')
                    .where(['callerids.id > 0 ' << cond << ' AND users.id = devices.user_id and users.owner_id = ?', @current_user_id]).order(order_by)

    @users = User.where(owner_id: @current_user_id).order('first_name ASC, last_name ASC')

    @searched = 'true' if cond != ''

    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@clis.size.to_d / session[:items_per_page].to_d).ceil
    @all_clis = @clis
    @clis = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_clis.size - 1 if iend > (@all_clis.size - 1)

    ((@page - 1) * session[:items_per_page]).upto(iend) { |index| @clis << @all_clis[index] }
  end

  def clis_banned_status
    @cl = Callerid.where(id: params[:id]).first
    @cl.assign_attributes(banned: ((@cl.banned.to_i == 1) ? 0 : 1))
    @cl.created_at = Time.now unless @cl.created_at
    @cl.save
    redirect_to(action: :clis)
  end

  def cli_user_devices
    @num = request.raw_post.to_s.gsub('=', '')
    params_id = params[:id]
    params_cli = params[:cli]
    dev_id = params[:dev_id]
    @num = params_id if params_id
    @include_cli = params_cli if params_cli
    @devices = Device.where(["user_id = ? AND name not like 'mor_server_%' AND name NOT LIKE 'prov%'", @num]) if @num.to_i != -1
    @search_dev = dev_id if dev_id

    @add = 1 if params[:add]

    render layout: false
  end

  def devices_all
    devices_list(params)
  end

  # in before filter : device (:find_device)
  def device_all_details
    @page_title = _('Device_details')
    @page_icon = 'view.png'

    @user = @device.user
    check_owner_for_device(@user)
  end

  # ------------------------- User devices --------------

  def user_devices
    @page_title = _('connection_points')

    unless user?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    # @devices = current_user.devices
    @op_devices = Device.select('devices.id, devices.ipaddr, devices.port, devices.op_tech_prefix AS tech_prefix,
                                 op_destination_transformation, tariffs.name AS tariff_name, devices.op_tariff_id,
                                 devices.description')
                        .joins('LEFT JOIN tariffs ON (devices.op_tariff_id = tariffs.id)')
                        .where("devices.op = 1 AND user_id = #{current_user_id}")
                        .order('devices.id')

    @tp_devices = Device.select('devices.id, devices.ipaddr, devices.port, devices.tp_tech_prefix AS tech_prefix,
                                 tariffs.name AS tariff_name, devices.tp_tariff_id, devices.description')
                        .joins('LEFT JOIN tariffs ON (devices.tp_tariff_id = tariffs.id)')
                        .where("devices.tp = 1 AND user_id = #{current_user_id}")
                        .order('devices.id')
  end

  def user_device_edit
    @page_title = _('device_settings')
    @page_icon = 'edit.png'
    @user = User.where(id: session[:user_id]).first
    user = @user
    @owner = User.where(id: user.owner_id).first

    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    if @device.user_id != user.id
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    set_cid_name_and_number
    @curr = current_user.currency
  end

  # in before filter : device (:find_device)
  def user_device_update
    @user = User.where(id: session[:user_id]).first

    if @device.user_id != @user.id
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    update_device_cid
    params_device = params[:device]

    @device.assign_attributes(description: params_device[:description])

    if @device.save
      flash[:status] = _('phones_settings_updated')
    else
      flash_errors_for(_('Update_Failed'), @device)
    end

    redirect_to(action: :user_devices) && (return false)
  end

  def default_device
    @page_title = _('Default_device')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Default_device_settings'
    session_user_id = session[:user_id]

    if reseller?
      reseller = User.where(id: session_user_id).first
      check_reseller_conflines(reseller)
      reseller.check_default_user_conflines
    end

    @device = Confline.get_default_object(Device, correct_owner_id)
    insecure = Confline.get_value('Default_device_insecure', correct_owner_id).to_s
    @device.insecure = insecure.presence || 'no'
    @device_type = 'SIP'
    @global_tell_balance = Confline.get_value('Tell_Balance').to_i
    @global_tell_time = Confline.get_value('Tell_Time').to_i

    @audio_codecs = Codec.select('codecs.*,  (conflines.value2 + 0) AS v2')
                         .joins('LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, "Default_device_codec_", ""))')
                         .where(["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'audio' and owner_id =?", correct_owner_id])
                         .order('v2')

    @video_codecs = Codec.select('codecs.*, (conflines.value2 + 0) AS v2')
                         .joins('LEFT Join conflines ON (codecs.name = REPLACE(conflines.name, "Default_device_codec_", ""))')
                         .where(["conflines.name like 'Default_device_codec%' and codecs.codec_type = 'video' and owner_id =?", correct_owner_id])
                         .order('v2')

    @owner = session_user_id

    @device_trunk = Confline.get_value('Default_device_trunk', @owner)

    @default = 1
    @cid_name = Confline.get_value('Default_device_cid_name', session_user_id)
    @cid_number = Confline.get_value('Default_device_cid_number', session_user_id)
    @qualify_time = Confline.get_value('Default_device_qualify', session_user_id)
    @sticky_contact = Confline.get_value('Default_device_sticky_contact', session_user_id)

    @grace_time = Confline.get_value('Default_device_grace_time', session_user_id)
    ddd = Confline.get_value('Default_setting_device_caller_id_number', session_user_id).to_i
    @device.control_callerid_by_cids = 1 if ddd == 4
    @device.callerid_advanced_control = 1 if ddd == 5

    @device_caller_id_number = @device.device_caller_id_number

    # -------multi server support------
    @sip_proxy_server = Server.where("server_type = 'sip_proxy'").limit(1).all
    @servers = Server.order('id ASC').all
    @server_devices = Confline.where(name: 'Default_device_server', owner_id: corrected_user_id).pluck(:value)
    @server_devices = Hash[@server_devices.map(&:to_i).product([1])]
    # @asterisk_servers = @servers
    @servers = @sip_proxy_server if !@sip_proxy_server.empty? && (@device_type == 'SIP')

    @ip_first = ''
    @mask_first = ''
    @ip_second = ''
    @mask_second = ''
    @ip_third = ''
    @mask_third = ''

    data = Confline.get_value('Default_device_permits', session_user_id).split(';')

    if data[0]
      permit = data[0].split('/')
      @ip_first = permit[0]
      @mask_first = permit[1]
    end

    if data[1]
      permit = data[1].split('/')
      @ip_second = permit[0]
      @mask_second = permit[1]
    end

    if data[2]
      permit = data[2].split('/')
      @ip_third = permit[0]
      @mask_third = permit[1]
    end
    # @call_limit = confline("Default_device_call_limit")
    @user = User.new
    @fullname = ''
    @device_enable_mwi = Confline.get_value('Default_device_enable_mwi', session_user_id)
  end

  def default_device_update
    params_call_limit, params_vm_email = [params[:call_limit], params[:vm_email]]

    if params_call_limit
      params_call_limit = params_call_limit.to_s.strip.to_i
      params_call_limit = 0 if params_call_limit < 0
      params[:call_limit] = params_call_limit
    end

    if params_vm_email.present? && !Email.address_validation(params_vm_email)
        flash[:notice] = _('Email_address_not_correct')
        redirect_to(action: :default_device) && (return false)
    end

    params_device = params[:device]

    Confline.set_value('Default_device_type', params_device[:device_type], corrected_user_id)
    Confline.set_value('Default_device_works_not_logged', params_device[:works_not_logged], corrected_user_id)
    Confline.set_value('Default_device_timeout', params[:device_timeout], corrected_user_id)
    Confline.set_value('Default_device_call_limit', params_call_limit, corrected_user_id)
    Confline.set_value('Default_device_cid_name', params[:cid_name], corrected_user_id)
    Confline.set_value('Default_device_cid_number', remove_zero_width_space(params[:cid_number]), corrected_user_id)
    Confline.set_value('Default_setting_device_caller_id_number', params[:device_caller_id_number].to_i, corrected_user_id)

    server_devices = params[:add_to_servers]

    if server_devices
      server_devices.each do |server_id, value|
        if value.to_i == 1
          confline = Confline.where(name: 'Default_device_server', value: server_id, owner_id: corrected_user_id).
              first_or_initialize
          confline.value = server_id
          confline.save
        else
          Confline.where(name: 'Default_device_server', value: server_id, owner_id: corrected_user_id).first.try(:destroy)
        end
      end
    else
      Confline.where(name: 'Default_device_server', owner_id: corrected_user_id).destroy_all
    end

    Confline.set_value('Default_device_nat', params_device[:nat], corrected_user_id)

    Confline.set_value('Default_device_tell_balance', params_device[:tell_balance], corrected_user_id)
    Confline.set_value('Default_device_tell_time', params_device[:tell_time], corrected_user_id)
    Confline.set_value('Default_device_tell_rtime_when_left', params_device[:tell_rtime_when_left], corrected_user_id)
    Confline.set_value('Default_device_repeat_rtime_every', params_device[:repeat_rtime_every], corrected_user_id)
    params_device_language = params_device[:language].to_s
    lang = params_device_language.presence || 'en'
    Confline.set_value('Default_device_language', lang, corrected_user_id)
    Confline.set_value('Default_device_enable_mwi', params_device[:enable_mwi].to_i, corrected_user_id)

    # ============= PERMITS ===================
    if params[:mask_first]
      params_ip_first = params[:ip_first]

      if !Device.validate_permits_ip([params_ip_first, params[:ip_second], params[:ip_third], params[:mask_first], params[:mask_second], params[:mask_third]])
        flash[:notice] = _('Allowed_IP_is_not_valid')
        redirect_to(action: :default_device) && (return false)
      else
        Confline.set_value('Default_device_permits', Device.validate_perims(ip_first: params_ip_first,
                                                                            ip_second: params[:ip_second], ip_third: params[:ip_third], mask_first: params[:mask_first],
                                                                            mask_second: params[:mask_second], mask_third: params[:mask_third]), corrected_user_id)
      end
    end

    # ------ advanced --------
    param_sticky_contact = params[:sticky_contact].to_s
    sticky_contact = param_sticky_contact.presence || '0'

    qualify = if params[:qualify] == 'yes'
                if ccl_active? && (params_device[:device_type] == 'SIP')
                  'no'
                else
                  (params[:qualify_time].to_i <= 1000) ? '1000' : params[:qualify_time]
                end
              else
                'no'
              end

    Confline.set_value('Default_device_qualify', qualify, corrected_user_id)
    Confline.set_value('Default_device_block_callerid', params_device[:block_callerid].to_i, corrected_user_id)
    Confline.set_value('Default_device_sticky_contact', sticky_contact, corrected_user_id)
    Confline.set_value('Default_device_grace_time', params[:grace_time], corrected_user_id)

    # ------- Network related -------
    host = (params[:dynamic_check] == '1') ? 'dynamic' : params[:host]
    Confline.set_value('Default_device_host', host, corrected_user_id)

    confline_default_device_host = Confline.get_value('Default_device_host', corrected_user_id)
    ipaddr = (confline_default_device_host != 'dynamic') ? confline_default_device_host : ''

    Confline.set_value('Default_device_ipaddr', ipaddr, corrected_user_id)
    Confline.set_value('Default_device_regseconds', params_device[:canreinvite], corrected_user_id)
    Confline.set_value('Default_device_canreinvite', params_device[:canreinvite], corrected_user_id)
    Confline.set_value('Default_device_cps_call_limit', params_device[:cps_call_limit].to_i, corrected_user_id)
    Confline.set_value('Default_device_cps_period', params_device[:cps_period].to_i, corrected_user_id)

    # time_limit_per_day can be positive integer or 0 by default
    # it should be entered as minutes and saved as minutes(cause
    # later it wil be assigned to device and device will convert to minutes..:/)
    # ----------- Codecs ------------------
    if params_device[:device_type] == (!params[:codec] or !(params[:codec][:alaw].to_i == 1 or params[:codec][:ulaw].to_i == 1))
      flash[:notice] = _('Fax_device_has_to_have_at_least_one_codec_enabled')
      redirect_to(action: :default_device) && (return false)
    end

    if params[:codec]
      Codec.all.each do |codec|
        codec_value = (params[:codec][codec.name] == '1') ? 1 : 0
        Confline.set_value("Default_device_codec_#{codec.name}", codec_value, corrected_user_id)
      end
    else
      Codec.all.each do |codec2|
        Confline.set_value("Default_device_codec_#{codec2.name}", 0, corrected_user_id)
      end
    end
    # ------Trunks-------
    istrunk, ani = case params[:trunk].to_i
                     when 0
                       [0, 0]
                     when 1
                       [1, 0]
                     when 2
                       [1, 1]
                   end

    Confline.set_value('Default_device_istrunk', istrunk, corrected_user_id)
    Confline.set_value('Default_device_ani', ani, corrected_user_id)

    # ------- Groups -------
    params_callgroup = params[:callgroup] ||= nil
    Confline.set_value('Default_device_callgroup', params_callgroup, corrected_user_id)

    params_pickupgroup = params[:pickupgroup] ||= nil
    Confline.set_value('Default_device_pickupgroup', params_pickupgroup, corrected_user_id)

    # ------- Advanced -------

    params_custom_sip_header = params[:custom_sip_header]
    Confline.set_value('Default_device_custom_sip_header', params_custom_sip_header.to_s, corrected_user_id)

    params_insecure = (params[:device][:insecure] == 'port')
    insecure = params_insecure ? 'port' : 'no'

    Confline.set_value('Default_device_insecure', insecure, corrected_user_id)

    Confline.set_value('Default_device_disable_q850', params_device[:disable_q850], corrected_user_id)
    Confline.set_value('Default_device_forward_rpid', params_device[:forward_rpid], corrected_user_id)
    Confline.set_value('Default_device_forward_pai', params_device[:forward_pai], corrected_user_id)
    Confline.set_value('Default_device_bypass_media', params_device[:bypass_media], corrected_user_id)
    Confline.set_value('Default_device_disable_sip_uri_encoding', params_device[:disable_sip_uri_encoding], corrected_user_id)
    Confline.set_value('Default_device_ignore_183nosdp', params_device[:ignore_183nosdp], corrected_user_id)
    Confline.set_value('Default_device_tp_ignore_183nosdp', params_device[:tp_ignore_183nosdp], corrected_user_id)
    Confline.set_value('Default_device_op_ignore_180_after_183', params_device[:op_ignore_180_after_183], corrected_user_id)
    Confline.set_value('Default_device_op_allow_own_tps', params_device[:op_allow_own_tps], corrected_user_id)
    Confline.set_value('Default_device_tp_ignore_180_after_183', params_device[:tp_ignore_180_after_183], corrected_user_id)
    Confline.set_value('Default_device_use_invite_dst', params_device[:use_invite_dst], corrected_user_id)
    Confline.set_value('Default_device_inherit_codec', params_device[:inherit_codec], corrected_user_id)
    Confline.set_value('Default_device_enforce_lega_codecs', params_device[:enforce_lega_codecs], corrected_user_id)
    Confline.set_value('Default_device_set_sip_contact', params_device[:set_sip_contact], corrected_user_id)
    Confline.set_value('Default_device_op_use_pai_number_for_routing', params_device[:op_use_pai_number_for_routing], corrected_user_id)
    Confline.set_value('Default_device_op_send_pai_number_as_caller_id_to_tp', params_device[:op_send_pai_number_as_caller_id_to_tp], corrected_user_id)

    Confline.set_value('Default_device_calleridpres', params_device[:calleridpres].to_s, corrected_user_id)

    tim_max = params_device[:max_timeout].to_i
    Confline.set_value('Default_device_max_timeout', (tim_max.to_i < 0) ? 0 : tim_max, corrected_user_id)
    Confline.set_value('Default_device_tell_rate', params_device[:tell_rate].to_s, corrected_user_id)

    progress_timeout = params_device[:progress_timeout].to_i
    Confline.set_value('Default_device_progress_timeout', (progress_timeout < 0) ? 0 : progress_timeout, corrected_user_id)

    Confline.set_value('Default_device_op', params_device[:op].to_i, corrected_user_id)
    Confline.set_value('Default_device_tp', params_device[:tp].to_i, corrected_user_id)
    Confline.set_value('Default_device_create_rg_for_op', params[:create_rg_for_op].to_i, corrected_user_id)
    if m4_functionality?
      Confline.set_value('Default_device_op_dc_group_id', params_device[:op_dc_group_id].to_i, corrected_user_id)
      Confline.set_value('Default_device_tp_dc_group_id', params_device[:tp_dc_group_id].to_i, corrected_user_id)
      errors = validate_pai_rpid_transformations(params_device)
      if errors.present?
        flash_array_errors_for(_('Default_Connection_Point_was_not_saved'),errors)
        redirect_to(action: :default_device) && (return false)
      end
      Confline.set_value('Default_device_tp_pai_regexp', params_device[:tp_pai_regexp].to_s, corrected_user_id)
      Confline.set_value('Default_device_tp_rpid_regexp', params_device[:tp_rpid_regexp].to_s, corrected_user_id)
      Confline.set_value('Default_device_op_pai_regexp', params_device[:op_pai_regexp].to_s, corrected_user_id)
      Confline.set_value('Default_device_op_rpid_regexp', params_device[:op_rpid_regexp].to_s, corrected_user_id)
    end
    flash[:status] = _('Settings_Saved')
    redirect_to(action: :default_device) && (return false)
  end

  def get_user_devices
    @user = request.raw_post.gsub('=', '')

    where_clause = ["users.owner_id = ? AND name not like 'mor_server_%'", correct_owner_id]
    where_clause_sec = (@user == 'all') ? '' : ['user_id = ?', @user]

    @devices = Device.select('devices.*').joins('LEFT JOIN users ON (users.id = devices.user_id)')
    .where(where_clause).where(where_clause_sec)

    render layout: false
  end

  def ajax_get_user_devices
    owner_id = correct_owner_id
    params_user_id, params_default, params_type = [params[:user_id], params[:default], params[:type]]
    include_non_active = params[:include_non_active].to_i == 1
    @user = params_user_id if params_user_id != -1
    @default = params_default.to_i if params_default
    @add_all = params[:all] ||= false
    @add_name = params[:name] ||= false
    @none = params[:none] ? params[:none] : false
    user_to_i = @user.to_i
    if (@user != 'all') && (user_to_i.to_s == @user) && @user != '-2'
      cond, var = [["name not like 'mor_server_%'"], []]
      cond << 'user_id = ?' and var << user_to_i
      cond << "name not like 'mor_server_%'" if params[:no_server]
      cond << 'user_id > -1' if params[:no_provider]

      if params_type.present? && %w[tp op].include?(params_type.to_s)
        cond << "#{params_type} = 1 #{"AND #{params_type}_active = 1" unless include_non_active}"
      end
      @devices = Device.visible.select("devices.*,devices.id as dev_id, IF(devices.description = '',CONCAT(IF(LENGTH(TRIM(CONCAT(users.first_name, ' ', users.last_name))) > 0,TRIM(CONCAT(users.first_name, ' ', users.last_name)), users.username),'/',devices.host),devices.description) as nice_device")
      .joins('LEFT JOIN users ON (users.id = devices.user_id)').where([cond.join(' AND ')].concat(var)).order('nice_device ASC')
    else
      @devices = (params[:all_when_no_user].to_i == 1) ? Device.termination_points_with_user : []
    end
    render layout: false
  end

  # A bit duplicate but this is the correct one (so far) implementation fo AJAX finder.
  def get_devices_for_search
    options = {}
    if params[:user_id] == 'all'
      @devices = admin? ? Device.origination_points : current_user.origination_points
    else
      @user = User.where(id: params[:user_id]).first
      @devices = (@user && (admin? || @user.owner_id = corrected_user_id)) ? @user.devices.origination_points : []
    end
    render layout: false
  end

  # This could use some rework aswell.
  def connection_points_remote
    type = params[:type] || 'op'
    type.strip!
    @name = params[:name] || 's_origination_point'
    usertype_admin = current_user.usertype == 'admin'
    params_user_id = params[:user_id]
    if params_user_id == 'all'
      @devices = usertype_admin ? Device.by_type(type) : current_user.devices.by_type(type)
    else
      user = User.where(id: params_user_id).first
      @devices = (user && (usertype_admin || user.owner_id = corrected_user_id)) ? user.devices.by_type(type) : []
    end
    render layout: false
  end

  def devicecodecs_sort
    ctype = params[:ctype]
    codec_id = params[:codec_id]
    params_id = params[:id]

    if params_id.to_i > 0
      @device = Device.where(id: params_id).first

      unless @device
        flash[:notice] = _('Device_was_not_found')
        redirect_back_or_default('/callc/main')
        return false
      end
      if codec_id
        if params[:val] == 'true'
          begin
            @device.devicecodecs.new(codec_id: codec_id).save
          rescue
            # logger.fatal 'could not save codec, may be unique constraint was violated?'
          end
        else
          pc = Devicecodec.where(device_id: params_id, codec_id: codec_id).first
          pc.destroy if pc
        end
      end

      params["#{ctype}_sortable_list".to_sym].each_with_index do |codec_id, index|
        item = Devicecodec.where(device_id: params_id, codec_id: codec_id).first
        if item
          item.priority = index
          item.save
        end
      end

      @device.changes_present_set_1
    else
      params["#{ctype}_sortable_list".to_sym].each_with_index do |id, index|
        codec = Codec.where(id: id).first
        if codec
          val = (params[:val] == 'true') ? 1 : 0
          codec_name = codec.name
          Confline.set_value("Default_device_codec_#{codec_name}", val, corrected_user_id) if params[:val] && codec_id.to_i == codec.id
          Confline.set_value2("Default_device_codec_#{codec_name}", index, corrected_user_id)
        end
      end
    end
    render layout: false
  end

  def termination_points_ajax
    @device_selected = params[:device_id].to_i
    @devices = []
    id = params[:id]

    if id
      id = (is_number?(id) && id != '%') ? id.to_s : -2
      @devices = Device.visible.where("user_id = '#{id}' AND name NOT LIKE 'mor_server_%' AND tp = 1").all
    end

    render layout: false
  end

  def origination_points_ajax
    @device_selected = params[:device_id].to_i
    @devices = []
    id = params[:id]

    if id
      id = (is_number?(id) && id != '%') ? id.to_s : -2
      @devices = Device.visible.where("user_id = '#{id}' AND name NOT LIKE 'mor_server_%' AND op = 1").all
    end

    render layout: false
  end

  def disconnect_code_changes
    hgc_type = Hangupcausecode.select('id, description').order(code: :asc).all
    hgc_type.unshift(Hangupcausecode.new(description: '<b>-1 - All failed Codes</b>'))
    hgc_type.first.id = -1
    @select_hgc_type = hgc_type
    disconnect_code_changes = HgcMapping.nice_disconnect_code_changes(@device.id).to_a
    if disconnect_code_changes.first && disconnect_code_changes.first.incoming_hgc.blank?
      disconnect_code_changes.first.incoming_hgc = '-1 - All failed Codes'
    end
    @disconnect_code_changes = disconnect_code_changes
  end

  def disconnect_code_changes_create
    if params[:new_disconnect_code][:hgc_incoming_id] == '-1'
      HgcMapping.where(device_id: @device.id).destroy_all
    end
    hgc_mapping = HgcMapping.new(params[:new_disconnect_code]) { |new| new.device_id = @device.id }
    if hgc_mapping.save
      flash[:status] = _('Disconnect_Code_Change_successfully_created')
      close_m2_form(:devices, 'disconnect_code_changes')
      redirect_to(action: :disconnect_code_changes, id: @device.id) && (return false)
    else
      flash_errors_for(_('Disconnect_Code_Change_not_created'), hgc_mapping)
    end
    redirect_to action: :disconnect_code_changes, id: @device.id, new_disconnect_code: params[:new_disconnect_code]
  end

  def disconnect_code_changes_destroy
    disconnect_code = HgcMapping.where(id: params[:id]).first
    if disconnect_code.destroy
      flash[:status] = _('Disconnect_Code_Change_deleted')
    else
      flash_errors_for(_('Disconnect_Code_Change_not_deleted'), disconnect_code)
    end
    redirect_to action: :disconnect_code_changes, id: params[:device_id]
  end

  def device_hide
    @device.hide

    if @device.hidden?
      flash[:status] = _('Connection_Point_was_successfully_hidden')
      redirect_to(action: :devices_hidden) unless params[:action_from].present?
    else
      flash[:status] = _('Connection_Point_was_successfully_unhidden')
      redirect_to(action: :devices_all) unless params[:action_from].present?
    end

    redirect_to(action: :cp_list, only_hidden: params[:only_hidden].to_i == 1 ? 0 : 1) if params[:action_from].present?
  end

  def devices_hidden
    devices_list(params)
  end

  def cp_list
    @options = session["#{params[:action]}_options".to_sym].presence || {}

    %i[s_description s_host s_user_id].each { |key| @options[key] = params[key] if params.member?(key) }

    # Do not clear s_user_id for now
    if params[:clear] == 'clear'
      s_user_id = @options[:s_user_id]
      @options = {}
      @options[:s_user_id] = s_user_id
    end


    join = ['LEFT OUTER JOIN users ON users.id = devices.user_id']
    cond = ["user_id != -1 AND devices.name not like 'mor_server_%'"]
    cond << "devices.hidden_device = #{(params[:only_hidden].to_i == 1) ? 1 : 0}"
    cond_par = []

    unless @options[:s_description].to_s.empty?
      cond << 'devices.description LIKE ?'
      cond_par << "%#{@options[:s_description]}%"
    end

    unless @options[:s_host].to_s.empty?
      cond << 'devices.ipaddr LIKE ?'
      cond_par << "#{@options[:s_host]}%"
    end

    unless @options[:s_user_id].to_s.empty?
      cond << 'devices.user_id = ?'
      cond_par << "#{@options[:s_user_id]}"
    end

    if current_user.usertype.to_s == 'manager' && current_user.show_only_assigned_users?
      cond << 'users.responsible_accountant_id = ? '
      cond_par << current_user_id
    end

    cond << 'users.hidden = 0'
    cond << 'accountcode != 0'
    cond << 'users.owner_id = ?'
    cond_par << corrected_user_id

    jqx_table_settings = JqxTableSetting.select_table(current_user_id, "#{params[:controller]},#{params[:action]},cp_list", 'id,nice_user,description,ipaddr,port,hide,edit,delete')
    @visible_columns = jqx_table_settings.column_visibility.split(',')
    (@visible_columns << '_id') unless @visible_columns.include?('_id')
    (@visible_columns << 'user_id') unless @visible_columns.include?('user_id')

    select_columns = []
    @visible_columns.each do |column|
      select_columns << case column
                          when '_id'
                            "devices.id AS '_id'"
                          when 'nice_user'
                            "IF(LENGTH(CONCAT(users.first_name, users.last_name)) > 0,CONCAT(users.first_name, ' ', users.last_name), users.username) AS 'nice_user'"
                          when 'call-limit'
                            '`call-limit`'
                          when 'session-timers'
                            '`session-timers`'
                          when 'session-expires'
                            '`session-expires`'
                          when 'session-minse'
                            '`session-minse`'
                          when 'session-refresher'
                            '`session-refresher`'
                          when 'hide', 'edit', 'delete'
                            next
                          else
                            "devices.#{column}"
                        end
    end

    @all_possible_columns = Device.column_names + ['nice_user', 'hide', 'edit', 'delete'] - ['user_id', '_id']

    if manager?
      @all_possible_columns.delete('hide')
    end

    unless (!manager? || (manager? && authorize_manager_permissions({controller: :devices, action: :device_edit, no_redirect_return: 1})))
      @all_possible_columns.delete('edit')
    end

    unless (!manager? || (manager? && authorize_manager_permissions({controller: :devices, action: :destroy, no_redirect_return: 1})))
      @all_possible_columns.delete('delete')
    end

    @all_possible_columns = Hash[
        @all_possible_columns.collect do |column|
          case column
            when 'id'
              [column, 'ID']
            when 'nice_user'
              [column, _('User')]
            else
              [column, column.capitalize]
          end
        end
    ]

    @devices = Device.unscoped.select(select_columns.join(', '))
    .joins(join.join(' '))
    .where([cond.join(' AND ')] + cond_par)
    .group('devices.id')

    session["#{params[:action]}_options".to_sym] = @options
  end

  def m4_get_tp_reg_status
    return unless request.xhr? && !params[:id].blank?
    result = 'wait'
    last_req_time = Confline.get_value('kamailio_last_req_time').to_time
    if last_req_time.blank? || last_req_time < Time.now - 30.second
      device = Device.where(id: params[:id].to_i).first
      serv = Server.where(proxy: 1).first
      kam_result = serv.execute_command_in_server("kamcmd uac.reg_info l_uuid #{device.try(:tp_l_uuid)} | grep flags | awk '{print $2}'")
      if kam_result
        if kam_result.include?('16') || kam_result.include?('20')
          result = _('Registered')
        else
          result = _('Unregistered')
        end
      else
        result = _('Not_Found')
      end
      Confline.set_value('kamailio_last_req_time', Time.now)
    end
    render json: {data: result}
  end

  def delete_dynamic_reg_info
    @device.assign_attributes(ipaddr: '', port: 5060, reg_status: '')
    unless @device.save
      flash[:notice] = _('Device_Registration_was_not_cleared')
      redirect_to(action: :device_edit, id: @device.id) && (return false)
    end
    flash[:status] = _('Device_Registration_was_successfully_cleared')
    redirect_to(action: :device_edit, id: @device.id) && (return false)
  end

  private

  def m4_tp_refresh(device_name)
    Server.where(proxy: 1).each do |server|
      server.execute_command_in_server("kamcmd uac.reg_refresh #{device_name}")
    end
  end

  def m4_tp_remove(device_name)
    Server.where(proxy: 1).each do |server|
      server.execute_command_in_server("kamcmd uac.reg_remove #{device_name}")
    end
  end

  def options_for_device_list(params)
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Devices'
    @options = session["#{params[:action]}_options".to_sym].presence || {}
    %i[s_description s_host].each { |key| @options[key] = params[key] if params.member?(key) }
    params[:order_desc] ? @options[:order_desc] = params[:order_desc].to_i : @options[:order_desc].to_i
    params[:page] ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page] || @options[:page] <= 0)
    @options = {} if params[:clear] == 'clear'
  end

  def conditions_for_device_list
    cond = ["user_id != -1 AND devices.name not like 'mor_server_%'"]
    cond << "devices.hidden_device = #{(params[:action] == 'devices_hidden') ? 1 : 0}"
    cond_par = []
    unless @options[:s_description].to_s.empty?
      cond << 'devices.description LIKE ?'
      cond_par << "%#{@options[:s_description]}%"
    end
    unless @options[:s_host].to_s.empty?
      cond << 'devices.ipaddr LIKE ?'
      cond_par << @options[:s_host].to_s + '%'
    end
    if current_user.usertype.to_s == 'manager' && current_user.show_only_assigned_users?
      cond << 'users.responsible_accountant_id = ? '
      cond_par << current_user_id
    end
    cond << 'users.hidden = 0'
    cond << 'accountcode != 0'
    cond << 'users.owner_id = ?'
    cond_par << corrected_user_id
    [cond, cond_par]
  end

  def devices_list(params)
    options_for_device_list(params)
    @options[:order_by], order_by, default = devices_all_order_by(params, @options)
    join = ['LEFT OUTER JOIN users ON users.id = devices.user_id']
    cond, cond_par = conditions_for_device_list
    @total_pages = (Device.joins(join.join(' '))
                          .where([cond.join(' AND ')] + cond_par)
                          .group('devices.id').to_a.size.to_d / session[:items_per_page].to_d)
                          .ceil
    set_options_page
    @options[:page] = 1 if @options[:page].to_i < 1
    @devices = Device.unscoped.select("devices.*, IF(LENGTH(CONCAT(users.first_name, users.last_name)) > 0,CONCAT(users.first_name, users.last_name), users.username) AS 'nice_user'")
                              .joins(join.join(' '))
                              .where([cond.join(' AND ')] + cond_par)
                              .group('devices.id')
                              .order(order_by)
                              .offset(session[:items_per_page] * (@options[:page] - 1))
                              .limit(session[:items_per_page])

    if default && (session[:devices_all_options].blank? || session[:devices_all_options][:order_by].blank?)
      @options.delete(:order_by)
    end
    session["#{params[:action]}_options".to_sym] = @options
  end

  def check_reseller_conflines(reseller)
    unless Confline.where(["name LIKE 'Default_device_%' AND owner_id = ?", reseller.id]).first
      reseller.create_reseller_conflines
    end
  end

  def devices_all_order_by(params, options)
    order_by = case params[:order_by].to_s
                 when 'user'
                   'nice_user'
                 when 'acc'
                   'devices.id'
                 when 'description'
                   'devices.description'
                 # when "pin"
                 #   order_by = "devices.pin"
                 # when "type"
                 #   order_by = "devices.device_type"
                 # when "extension"
                 #   order_by = "devices.extension"
                 # when "username"
                 #   order_by = "devices.name"
                 # when "secret"
                 #   order_by = "devices.secret"
                 # when "cid"
                 #   order_by = "devices.callerid"
                 else
                   default = true
                   options[:order_by] || 'nice_user'
               end

    without = order_by
    order_by += (options[:order_desc].to_i == 1) ? ' DESC' : ' ASC'
    order_by += ', devices.id ASC ' if order_by.exclude?('devices.id')
    return without, order_by, default
  end

  def check_pbx_addon
    unless pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end

  def find_device
    @device = Device.unscoped.where(id: params[:id]).includes(:user).first
    unless @device && User.check_responsability(@device.user_id)
      flash[:notice] = _('Device_was_not_found')
      redirect_back_or_default('/callc/main')
    end

    @device
  end

  def find_cli
    @cli = Callerid.includes(:device).where(id: params[:id]).first
    unless @cli
      flash[:notice] = _('Callerid_was_not_found')
      redirect_to(:root) && (return false)
    else
      check_cli_owner(@cli)
    end
  end

  def check_cli_owner(cli)
    device = cli.device
    user = device.user if device
    unless user and (user.owner_id == correct_owner_id or user.id == session[:user_id])
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def verify_params
    unless params[:device]
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def create_cli
    cli = Callerid.new(cli: params[:cli], device_id: params[:device_id], comment: params[:comment].to_s,
                       banned: params[:banned].to_i, added_at: Time.now)
    params_description = params[:description]
    cli.description = params_description if params_description

    if cli.save
      flash[:status] = _('CLI_created')
    else
      flash_errors_for(_('CLI_not_created'), cli)
    end
  end

  def check_with_integrity
    session[:integrity_check] = Device.integrity_recheck_devices if current_user && current_user.usertype.to_s == 'admin'
  end

  def erase_ipaddr_fullcontact
    if params[:device] and (params[:device][:name] != @device.name) and (params[:ip_authentication_dynamic].to_i == 2)
      @device.assign_attributes(ipaddr: '',
                                 fullcontact: nil,
                                 reg_status: ''
                                )
      @device.save
    end
  end

  def allow_dahdi?
    session_device = session[:device]
    not reseller? or (session_device and session_device[:allow_dahdi] == true)
  end

  def allow_virtual?
    session_device = session[:device]
    not reseller? or (session_device and session_device[:allow_virtual] == true)
  end

  def set_qualify_time
    device_qualify = @device.qualify
    @qualify_time = (device_qualify == 'no') ? 2000 : device_qualify
  end

  def set_options_page
    total_pages = @total_pages.to_i
    @options[:page] = total_pages if (total_pages < @options[:page].to_i) && (total_pages > 0)
  end

  def set_cid_name_and_number
    device_callerid = @device.callerid

    if device_callerid
      @cid_name = nice_cid(device_callerid)
      @cid_number = cid_number(device_callerid)
    else
      @cid_name = ''
    end
  end

  def get_number_pools
    @number_pools = NumberPool.order('name ASC').all.collect { |pool| [pool.name, pool.id] } if admin? || manager?
  end

  def set_servers(device_type)
    @servers = ((device_type == 'SIP') && ccl_active?) ? @sip_proxy_server : @asterisk_servers
  end

  def get_tariffs
    @tariffs = Tariff.tariffs_for_device(correct_owner_id)
  end

  def update_device_cid
    cid_name, cid_number = [params[:cid_name], remove_zero_width_space(params[:cid_number])]
    cid_number_from_did_present = cid_number_from_did.try(:length).to_i > 0
    @device.update_cid(cid_name, cid_num) if cid_name || cid_number
  end

  def set_page_and_devices_for_it(user_devices)
    session_items_per_page, params_page = [session[:items_per_page].to_i, params[:page].to_i]
    items_per_page = (session_items_per_page < 1) ? 1 : session_items_per_page
    total_items = user_devices.length
    total_pages = (total_items.to_d / items_per_page.to_d).ceil
    page_no = (params_page < 1) ? 1 : params_page
    page_no = total_pages if total_pages < page_no
    offset = (total_pages < 1) ? 0 : items_per_page * (page_no - 1)
    @devices = user_devices.limit(items_per_page).offset(offset)
    @page = page_no
    @total_pages = total_pages
  end

  def set_return_controller
    params_return_to_controller = params[:return_to_controller]
    @return_controller = params_return_to_controller if params_return_to_controller
  end

  def set_return_action
    params_return_to_action = params[:return_to_action]
    @return_action = params_return_to_action if params_return_to_action
  end

  def check_if_sip_proxy_active
    @sip_proxy_server_active = Server.where(server_type: 'proxy', active: 1).count
  end

  def authorize_assigned_users
    params[:id] ||= params[:user_id]
    return if User.check_responsability(params[:id].to_i)
    flash[:notice] = _('Dont_be_so_smart')
    redirect_to(action: :root) && (return false)
  end

  def validate_pai_rpid_transformations(params)
    regexp_array = [params[:tp_pai_regexp].to_s, params[:tp_rpid_regexp].to_s,
      params[:op_pai_regexp].to_s, params[:op_rpid_regexp].to_s
    ]
    errors = []
    titles = %w[PAI_Transformation RPID_Transformation]
    regexp_array.each_with_index do |regexp, index|
      splitted_regexp = regexp.to_s.split('/')
      next if splitted_regexp.size == 0

      regexp_valid = system("echo 'test' | sed -E 's#{regexp}'")
      unless regexp_valid
        errors << "#{_(titles[index % 2])} - #{_('Invalid_regexp')}"
        next
      end
      errors << "#{_(titles[index % 2])} - #{_('Invalid_regexp')}" if splitted_regexp.size >= 4 && %w[i g ig gi].exclude?(splitted_regexp.last)
    end
    errors
  end
end
