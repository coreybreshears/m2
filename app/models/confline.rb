# -*- encoding : utf-8 -*-
class Confline < ActiveRecord::Base

  attr_protected

  validates_presence_of :name

  # Returns confline value of given name and user_ID
  def Confline::get_value(name, id = 0, value_if_cl_not_found = '')
    Confline.where(name: name, owner_id: id).first.try(:value) || value_if_cl_not_found
  end

  def Confline::get_value_default_on(name, id = 0)
    cl = Confline.where(name: name, owner_id: id).first
    if cl.present?
      return cl.value
    else
      Confline.new_confline(name.to_s, 1, id)
      return 1
    end
  end

  def self.by_params(*params)
    cl = Confline.where(['name = ? and owner_id  = ?', params.slice(0..-2).join('_'), params.last]).first
    return cl.value if cl
    return ''
  end

  def Confline::get_value2(name, id = 0)
    cl = Confline.where(['name = ? and owner_id  = ?', name, id]).first
    return cl.value2 if cl
    return ''
  end

  def Confline::get_values(name, id = 0)
    return get_value(name, id), get_value2(name, id)
  end

  # Sets confline value.
  def Confline::set_value(name, value = 0, id = 0, make_action_log = true)
    cl = Confline.where(['name = ? and owner_id = ?', name, id]).first
    if cl
      if make_action_log && cl.value.to_s != value.to_s
        user = User.current ? User.current.id : -1
        Action.add_action_hash(user, {action: 'Confline changed', target_id: cl.id, target_type: 'confline', data: cl.value.to_s, data2: value.to_s, data4: name}) unless name.include? 'AWS_DB_'
      end
      cl.value = value
      cl.save
    else
      new_confline(name, value, id)
    end
  end

  def Confline::set_value2(name, value = 0, id = 0, make_action_log = true)
    cl = Confline.where(['name = ? and owner_id = ?', name, id]).first
    if cl
      if make_action_log && cl.value2.to_s != value.to_s
        if User.current_user
          Action.add_action_hash(User.current_user.id, {action: 'Confline changed', target_id: cl.id, target_type: 'confline', data: cl.value2.to_s, data2: value.to_s, data3: 'value2', data4: name})
        else
          Action.add_action_hash(-1, {action: 'Confline changed', target_id: cl.id, target_type: 'confline', data: cl.value2.to_s, data2: value.to_s, data3: 'value2', data4: name})
        end
      end
      cl.value2 = value
      cl.save
    else
      # sself.my_debug("Confline missing: " + name.to_s + " ---> Created")
      Confline.new_confline2(name, value, id)
    end
  end

  # creates new confline with given params
  def Confline::new_confline(name, value, id = 0)
    confline = Confline.new()
    confline.name = name.to_s
    confline.value = value.to_s
    confline.owner_id = id
    confline.save
  end

  def Confline::new_confline2(name, value, id = 0)
    confline = Confline.new()
    confline.name = name.to_s
    confline.value2 = value.to_s
    confline.owner_id = id
    confline.save
  end

  def Confline::my_debug(msg)
    File.open(Debug_File, 'a') do |file|
      file << "Confline.my_debug() is deprecated use MorLog.my_debug()\n"
      file << msg.to_s
      file << "\n"
    end
  end

  def Confline::get(name, id = 0)
    Confline.where(name: name, owner_id: id).first
  end

=begin rdoc
 Sets Conflines with name format "Default_Object_action" and value = data.
 This action is used to store default objects in conflines table.

 *Params*
 * +object+ - Class name variable. User, Device etc.
 * +owner_id+ - User.id that shows confline owner.
 * +data+ - hash of object properties. +object+ has method with same name as hash key, then hash value is used as default value.
=end

  def Confline.set_default_object(object, owner_id, data)
    instance = object.new
    data.each { |key, value|
      Confline.set_value("Default_#{object.to_s}_#{sanitize_sql(key)}", value, owner_id) if instance.respond_to?(key.to_sym)
    }
  end

=begin rdoc
 Recreates +object+ from Confline fields.

 *Params*
 * +object+ - Class name variable. User, Device etc.
 * +owner_id+ - User.id that shows confline owner.

 *Returns*
 +instance+ - instance of class +object+ with set default properties
=end

  def Confline.get_default_object(object, owner_id = 0)
    instance = object.new
    attributes = Confline.where(["name LIKE 'Default_#{object.to_s}_%' AND name != 'Default_device_server' AND owner_id = ?", owner_id]).all
    attributes.each { |confline|
      val = confline.value
      key = confline.name.gsub("Default_#{object.to_s}_", '')
      if key.include?("Default_#{object.to_s.downcase.to_s}_")
        key = confline.name.gsub("Default_#{object.to_s.downcase.to_s}_", '')
      end
      if object != Device or (object == Device and (!key.include?('voicemail') and !key.include?('type')))
        instance.__send__((key+'=').to_sym, val) if instance.respond_to?(key.to_sym)
      end
    }
    instance
  end

=begin rdoc
 Returns Tax object filled with default values from conflines.

 *Params*
 * +owner_id+ - User.id that shows confline owner.

 *Returns*
 +tax+ - Tax object filled with default values.
=end

  def Confline.get_default_tax(owner_id)
    tax ={
        tax1_enabled: 1,
        tax2_enabled: Confline.get_value2('Tax_2', owner_id).to_i,
        tax3_enabled: Confline.get_value2('Tax_3', owner_id).to_i,
        tax4_enabled: Confline.get_value2('Tax_4', owner_id).to_i,
        tax1_name: Confline.get_value('Tax_1', owner_id).to_s,
        tax2_name: Confline.get_value('Tax_2', owner_id).to_s,
        tax3_name: Confline.get_value('Tax_3', owner_id).to_s,
        tax4_name: Confline.get_value('Tax_4', owner_id).to_s,
        total_tax_name: Confline.get_value('Total_tax_name', owner_id).to_s,
        tax1_value: Confline.get_value('Tax_1_Value', owner_id).to_d,
        tax2_value: Confline.get_value('Tax_2_Value', owner_id).to_d,
        tax3_value: Confline.get_value('Tax_3_Value', owner_id).to_d,
        tax4_value: Confline.get_value('Tax_4_Value', owner_id).to_d
    }
    Tax.new(tax)
  end

  def self.get_default_user_pospaid_errors
    ActiveRecord::Base.connection.select_all('SELECT owner_id FROM conflines WHERE name IN (\'Default_User_allow_loss_calls\', \'Default_User_postpaid\') AND value = 1 GROUP BY owner_id HAVING COUNT(*) > 1 ;')
  end

  def self.load_recaptcha_settings
    if Confline.get_value('reCAPTCHA_enabled').to_i == 1
      Recaptcha.configure do |config|
        config.public_key = Confline.get_value('reCAPTCHA_public_key')
        config.private_key = Confline.get_value('reCAPTCHA_private_key')
      end
    end
  end

  def Confline.send_email_notice
    [
        [_('at_once_when_generated'), '1'], [_('every_3h'), '2'], [_('every_6h'), '3'],
        [_('every_12h'), '4'], [_('once_a_day'), '5'], [_('once_a_week'), '6'],
        [_('once_a_month'), '7']
    ]
  end

  def self.exchange_user_to_reseller_calls_table
    if Confline.get_value2('Calls_table_fixed', 0).to_i == 0
      sql = 'UPDATE calls SET partner_price = user_price;'
      ActiveRecord::Base.connection.update(sql)
      sql = 'UPDATE calls SET user_price = reseller_price;'
      ActiveRecord::Base.connection.update(sql)
      # sql = 'UPDATE calls SET reseller_price = partner_price;'
      # ActiveRecord::Base.connection.update(sql)
      sql = 'UPDATE calls SET partner_price = NULL'
      ActiveRecord::Base.connection.update(sql)

      Confline.set_value2('Calls_table_fixed', 1, 0)
      updated = true
    else
      updated = false
    end

    return updated
  end

  def self.get_exeption_values
    exception_class_previous = Confline.get_value('Last_Crash_Exception_Class', 0).to_s
    exception_send_email = Confline.get_value('Exception_Send_Email').to_i

    return exception_class_previous, exception_send_email
  end

  def self.active_calls_show_server?(owner_id = 0)
    get_value('Active_Calls_Show_Server', owner_id) == '1'
  end

  def self.additional_modules_save_assign(params)
    Confline.set_value('AD_sounds_path', params['AD_sounds_path'])
    Confline.set_value('CC_Active', params['CC_Active'])
    Confline.set_value('RS_Active', params['RS_Active'])
    Confline.set_value('RSPRO_Active', (params['RS_Active'].to_i == 1 ? params['RSPRO_Active'] : 0))
    Confline.set_value('REC_Active', params['REC_Active'])
    Confline.set_value('MA_Active', params['MA_Active'])
    Confline.set_value('PROVB_Active', params['PROVB_Active'])
    Confline.set_value('AST_18', params['AST_18'])
    Confline.set_value('WP_Active', params['WP_Active'])
    Confline.set_value('CC_Single_Login', (params['CC_Active'].to_i == 1 ? params['CC_Single_Login'] : 0))
    Confline.set_value('PBX_Active', params['PBX_Active'])

    ccl = params[:CCL_Active].to_i
    ccl_old = Confline.get_value('CCL_Active').to_i
    first_srv = Server.first.id
    def_asterisk = Confline.get_value('Default_asterisk_server').to_s
    reseller_server = Confline.get_value('Resellers_server_id').to_s
    resellers_devices = Device.joins('LEFT JOIN users ON (devices.user_id = users.id)').where("(users.owner_id !=0 or usertype = 'reseller') AND users.hidden = 0").all
    def_asterisk = first_srv if def_asterisk.to_i == 0

    return ccl, ccl_old, first_srv, def_asterisk, reseller_server, resellers_devices
  end

  def self.additional_modules_save_no_ccl(ccl, sd, resellers_devices, def_asterisk, reseller_server)
    p_srv_id = Server.where(server_type: 'sip_proxy').first.id.to_s rescue nil
    if !p_srv_id.blank?
      Server.delete_all(server_type: 'sip_proxy')
      Device.delete_all(name: 'mor_server_' + p_srv_id.to_s)
    end

    # CCL off - All devices with more than 1 server (or is a sip+dynamic combo) gets assigned to default asterisk server, duplicates removed.
    dups = []
    sd.each do |s|
      dup_count = ServerDevice.where(device_id: s.device_id.to_s).size.to_i
      dev = Device.where(id: s.device_id.to_s).first

      if dev.device_type.to_s == 'SIP' and dev.proxy_port.to_i == 0 and dev.name.include?('ipauth')
        dev.proxy_port = Device::DefaultPort['SIP']
        dev.save(validate: false)
      end

      if dups.include?(s.device_id)
        s.delete
      elsif dup_count > 1 or dev.device_type.to_s == 'SIP'
        if resellers_devices.include?(dev)
          s.server_id = reseller_server
        else
          s.server_id = def_asterisk.to_s
        end
        if s.save
          dups << s.device_id
        else
          serv_error =s.errors
        end
      end
      if (dev.server_id != s.server_id) or dev.device_type.to_s == 'SIP'
        if dev.device_type.to_s == 'SIP' and !dev.name.include?('ipauth')
          dev.insecure = 'no'
        end
        if dev.server != s.server
          dev.server = s.server
        end
        dev.save
      end
    end

    Confline.set_value('CCL_Active', ccl.to_i)
  end

  def self.active_calls
    where(name: 'Active_Calls_Count').first.try(:value).to_i
  end

  def self.additional_modules_save_with_ccl(sd, created_server, ccl)
    sd.each do |d|
              cur_dev = Device.where(id: d.device_id.to_s).first
              if cur_dev and cur_dev.device_type.to_s == 'SIP'
                d.server_id = created_server.id
                d.save
                cur_dev.insecure  = 'port,invite'
                cur_dev.server_id = created_server.id
                cur_dev.save
              end
            end

    Device.update_all(encryption: 'no', device_type: 'SIP')
    Confline.set_value('CCL_Active', ccl.to_i)

  return sd
  end

  def self.get_logo_details(user_id)
    logo_picture = get_value('Logo_Picture', user_id)
    version = get_value('Version', user_id)
    copyright_title = get_value('Copyright_Title', user_id)
    return logo_picture, version, copyright_title
  end

  def self.set_monitorings_settings(options)
    monitorings_settings = []

    monitorings_settings
  end

  def self.calls_dashboard_config
    {
      time_fromat: get('time_format').try(:value) || '%M:%S',
      bad_asr: get('CD_bad_ASR').try(:value) || 30,
      good_asr: get('CD_good_ASR').try(:value) || 50,
      bad_acd: get('CD_bad_ACD').try(:value) || 60,
      good_acd: get('CD_good_ACD').try(:value) || 119,
      bad_margin: get_value('CD_bad_Margin'),
      good_margin: get_value('CD_good_Margin'),
      refresh_interval: get('Calls_Dashboard_refresh_interval').try(:value) || 5
    }
  end

  def self.set_aurora_confs(cfg)
    set_value('AWS_DB_Host_read', cfg[:host].to_s.strip)
    set_value('AWS_DB_Host_write', cfg[:write_host].to_s.strip)
    set_value('AWS_DB_Port', cfg[:port].to_s.strip)
    set_value('AWS_DB_Username', cfg[:username].to_s.strip)
    set_value('AWS_DB_Password', cfg[:password].to_s.strip)
    set_value('AWS_DB_Name', cfg[:database].to_s.strip)
    cfg
  end

  def self.redis_connection_hash(ip = Confline.get_value('Redis_IP', 0, '127.0.0.1'), port = Confline.get_value('Redis_Port', 0, '6379'), timeout = 1)
    {host: ip, port: port, timeout: timeout}
  end

  def self.set_two_fa_settings(params)
    set_value('two_fa_email_template', params[:two_fa_email_template].to_i)
    set_value('two_fa_code_length', params[:two_fa_code_length].to_i)
    set_value('two_fa_attemps_allowed', params[:two_fa_attemps_allowed].to_i)
    set_value('two_fa_time_allowed', params[:two_fa_time_allowed].to_i)
    set_value('two_fa_send_notification_to_admin_on_login', params[:two_fa_send_notification_to_admin_on_login].to_i)
    set_value('two_fa_admin_notification_email_template', params[:two_fa_admin_notification_email_template].to_i)
    set_value('two_fa_send_notification_to_admin_on_admin_login', params[:two_fa_send_notification_to_admin_on_admin_login].to_i)
    set_value('two_fa_send_notification_to_admin_on_user_login', params[:two_fa_send_notification_to_admin_on_user_login].to_i)
    set_value('two_fa_send_notification_email_on_login', params[:two_fa_send_notification_email_on_login].to_i)
    set_value('two_fa_notification_email_address', params[:two_fa_notification_email_address].to_s)
    set_value('two_fa_notification_email_template', params[:two_fa_notification_email_template].to_i)
    set_value('two_fa_send_notification_on_admin_login', params[:two_fa_send_notification_on_admin_login].to_i)
    set_value('two_fa_send_notification_on_user_login', params[:two_fa_send_notification_on_user_login].to_i)
  end
end
