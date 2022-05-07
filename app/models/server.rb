# -*- encoding : utf-8 -*-
# Servers' managing.
class Server < ActiveRecord::Base
  attr_protected
  include UniversalHelpers

  has_one :gateway
  has_many :activecalls
  has_many :server_devices
  has_many :devices, through: :server_devices
  has_many :server_loadstats

  before_destroy :delete_devices_relation, :gui_db_core?
  before_destroy :check_if_server_is_resellers_server
  before_save :check_if_proxy_exists
  after_save :check_server_device, :set_proxy_server_confline, :set_es_ip_confline
  after_destroy :unset_proxy_server_confline, :unset_es_ip_confline
  before_update :check_role

  validates_presence_of :server_ip, message: _('Server_IP_cannot_be_empty')
  validates_format_of :server_ip, with: /(\A(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}\z)|(\A(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])\z)|^dynamic\z|^\z/, message: _('Server_IP_is_not_valid')
  validates_uniqueness_of :server_ip, message: _('Server_IP_is_not_valid')

  def check_if_no_devices_own_server
    if ServerDevice.where(server_id: self).count.to_i > 0
      errors.add(:id, _('Server_Has_Devices'))
      return false
    end
  end

  def delete_devices_relation
    ServerDevice.where(server_id: self).delete_all
  end

  def check_if_server_is_resellers_server
    if Confline.get_value('Resellers_server_id') == self.id
      errors.add(:id, _('Server_is_default_resellers_server'))
      return false
    end
  end

  def check_server_device
    unless self.server_device
      self.create_server_device if self.id.to_i > 0
    end
  end

  # reloads device conf script in Freeswitch
  def fs_device_reload(device_name)
    if self.active == 1 && self.server_type != 'other'

      if self.server_type.to_s == 'freeswitch' || self.fs.to_i == 1

        if [host_ip.to_s, '127.0.0.1', 'localhost'].include?(self.server_ip.to_s)

          thread = Thread.new {
              MorLog.my_debug 'm2_freeswitch_devices on localhost started'
              `/usr/local/m2/m2_freeswitch_devices`
              MorLog.my_debug 'm2_freeswitch_devices on localhost completed'
          }

        else

          thread = Thread.new {
            begin
              MorLog.my_debug "m2_freeswitch_devices on #{server_ip.to_s} started"
              # Before doing this, connection between servers should be established using:
              #   http://wiki.ocean-tel.uk/index.php/Configure_SSH_connection_between_servers
              Net::SSH.start(
                server_ip.to_s, 'root', port: ssh_port.to_i, timeout: 10,
                keys: %w(/var/www/.ssh/id_rsa), auth_methods: %w(publickey)
              ) { |ssh| ssh.exec! '/usr/local/m2/m2_freeswitch_devices' }
              MorLog.my_debug "m2_freeswitch_devices on #{server_ip.to_s} completed"
            rescue Net::SSH::Exception, SystemExit, ScriptError, StandardError => error
              MorLog.my_debug  "Device update on FS error: #{error.message}"
              raise "SSH settings of Device's Server are incorrect. Possible Device malfunction."
            end
          }

          thread.join
        end
      end

    end
  end

  # get server external IP
  def host_ip
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

    UDPSocket.open do |socket|
      socket.connect '64.233.187.99', 1 # IP belongs to Google
      socket.addr.last
    end
    ensure
      Socket.do_not_reverse_lookup = orig
  end

  def create_server_device
    dev = Device.new
    dev.name = 'mor_server_' + self.id.to_s
    dev.fromuser = dev.name
    dev.host = hostname
    dev.secret = '' #random_password(10)
    dev.context = 'mor_direct'
    dev.ipaddr = server_ip
    dev.device_type = 'SIP' #IAX2 sux
    dev.port = 5060 #make dynamic later
    dev.proxy_port = 5060 #proxy_port == port (if not changed manually)
    dev.extension = dev.name
    dev.username = dev.name
    dev.user_id = 0
    dev.allow = 'all'
    dev.nat = 'no'
    dev.canreinvite = 'no'
    dev.server_id = self.id
    dev.description = 'DO NOT EDIT'
    if dev.save
    else
      if _(dev.errors.values.first.try(:first).to_s) == _('Device_extension_must_be_unique')
        errors.add(:device, _('Server_device_extension_not_unique', "mor_server_#{self.id}")) && (return false)
      end
    end
  end

  def server_device
    Device.where(name: "mor_server_#{self.id}").first
  end

  def check_role
    if self.db.to_i == 1
      #ActiveRecord::Base.connection.execute("UPDATE `servers` SET `db` = 0 WHERE `db` = 1 AND `id` != #{id}")
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `db` = 1 WHERE `db` = 0 AND `id`  = #{id}")
    end
    if self.gui.to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `gui` = 0 WHERE `gui` = 1 AND `id` != #{id}")
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `gui` = 1 WHERE `gui` = 0 AND `id`  = #{id}")
    end
    if self.es.to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `es` = 0 WHERE `es` = 1 AND `id` != #{id}")
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `es` = 1 WHERE `es` = 0 AND `id`  = #{id}")
    end
    if self.proxy.to_i == 1
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `proxy` = 0 WHERE `proxy` = 1 AND `id` != #{id}")
      ActiveRecord::Base.connection.execute("UPDATE `servers` SET `proxy` = 1 WHERE `proxy` = 0 AND `id`  = #{id}")
    end
    if self.gui.to_i == 0 and Server.where(['`gui` = 1 AND `id` != ?', self.id]).count.zero?
      errors.add(:gui, _('Must_have_minimum_one_gui')) and return false
    end
    if self.db.to_i == 0 and Server.where(['`db` = 1 AND `id` != ?', self.id]).count.zero?
      errors.add(:db, _('Must_have_minimum_one_db')) and return false
    end
    if self.core.to_i == 0 and Server.where(['`core` = 1 AND `id` != ?', self.id]).count.zero?
      errors.add(:core, _('Must_have_minimum_one_core')) and return false
    end
  end

  def gui_db_core?
    if [self.gui, self.db, self.core].include? 1
      errors.add(:server, _('Server_is_used_as_GUI_DB_or_core')) and return false
    end
  end

  def which_loadstats?
    varied_labels = [
      ('cpu_mysql_load' if db == 1),
      ('cpu_ruby_load' if gui == 1),
      ('cpu_freeswitch_load' if (core == 1 && server_type == 'freeswitch') || fs == 1)
    ]
    return varied_labels.compact
  end

  def self.server_add(params)
    good_server_type = %w[freeswitch other proxy].include?(params[:server_type].to_s) ? params[:server_type].to_s : 'other'
    server = Server.new({
                            hostname: params[:server_hostname].to_s.strip,
                            server_ip: params[:server_ip].to_s.strip,
                            server_type: good_server_type,
                            version: params[:version].to_s.strip,
                            uptime: params[:uptime].to_s.strip,
                            comment: params[:server_comment].to_s.strip,
                            active: 1
                        })

    return server
  end

  def self.server_update(params, server)
    errors = 0
    server.assign_attributes({
                                  hostname: params[:server_hostname].to_s.strip,
                                  server_ip: params[:server_ip].to_s.strip,
                                  stats_url: params[:server_url].to_s.strip,
                                  comment: params[:server_comment].to_s.strip,
                                  ssh_username: params[:server_ssh_username].to_s.strip,
                                  ssh_port: params[:server_ssh_port].to_s.strip,
                                  server_type: params[:server_type_edit][:server_type].to_s.strip
                              })

    dev = server.server_device
    return dev, server, errors
  end

  def self.integrity_recheck
    limit = Confline.get_value('Server_free_space_limit')
    limit = limit.blank? ? 20 : limit.to_i

    where("hdd_free_space < #{limit} AND active = 1").count > 0 ? 1 : 0
  end

  # Check if a server is running locally
  def local?
    ip = server_ip.to_s
    is_localhost = ip == '127.0.0.1'
    is_in_ifconfig = `/sbin/ifconfig -a`.include? ip
    is_in_ip_addr = `/sbin/ip addr show`.include? ip
    is_localhost || is_in_ifconfig || is_in_ip_addr
  rescue => err
    (MorLog.my_debug '#{err.message}') && (return false)
  end

  def self.all_quick_stats
    data = []

    where(active: 1).each do |server|
      data << server.quick_stats
    end

    data
  end

  def quick_stats
    data = {
        id: id,
        tooltip_description: "<b>#{_('Type')}:</b> #{server_type}<br/><b>#{_('Description')}:</b> #{comment}<br/><b>IP:</b> #{server_ip}",
        uptime: system_uptime,
    }

    data[:core_uptime] = core_uptime if core.to_i == 1

    data
  end

  def system_uptime
    uptime = execute_command_in_server("awk '{print $1}' /proc/uptime")

    begin
      uptime.present? ? uptime_from_seconds(uptime.to_i) : '-'
    rescue
      '-'
    end
  end

  def core_uptime
    case server_type.to_s
      when 'freeswitch'
        core_freeswitch_uptime
      else
        ''
    end
  end


  def core_freeswitch_uptime
    uptime = execute_command_in_server("fs_cli -x 'status' | grep UP")
    # (Example output) 'UP 1 year, 0 days, 1 hour, 42 minutes, 53 seconds, 772 milliseconds, 956 microseconds'

    begin
      uptime = uptime.sub('UP', '').split(', ')[0..4].map { |value| value.to_i }

      # 1 Year = 365.25*24*60*60 Seconds
      seconds = uptime[0] * 31557600
      seconds += uptime[1] * 86400
      seconds += uptime[2] * 3600
      seconds += uptime[3] * 60
      seconds += uptime[4]

      uptime_from_seconds(seconds)
    rescue
      '-'
    end
  end

  def execute_command_in_server(command = '')
    if local?
      MorLog.my_debug("Executing local command: #{command}", true)
      result = `#{command}`
    else
      begin
        # Before doing this, connection between servers should be established using:
        #   http://wiki.ocean-tel.uk/index.php/Configure_SSH_connection_between_servers
        MorLog.my_debug("Executing command: #{command} in Server (id: #{id}, IP: #{server_ip})", true)
        Net::SSH.start(
          server_ip.to_s, ssh_username.to_s, port: ssh_port.to_i, timeout: 10,
          keys: %w(/var/www/.ssh/id_rsa), auth_methods: %w(publickey)
        ) { |ssh| result = ssh.exec! command }
      rescue Net::SSH::Exception, SystemExit, ScriptError, StandardError => error
        MorLog.my_debug "Command execution in Server (id: #{id}, IP: #{server_ip}) failed, error:\n #{error.message}"
        return false
      end
    end
    result
  end

  def hangup_call(uuid)
    response = local? ? `fs_cli -x 'uuid_kill #{uuid}' 2>&1` : execute_command_in_server("fs_cli -x 'uuid_kill #{uuid} 2>&1'")
    MorLog.my_debug("fs_cli hangup command result: #{response}")
    if response.to_s.match(/\[ERROR\]/)
      MorLog.my_debug("Freeswitch is not running", true)
      attempt = 0
      result = ''

      while attempt < 3
        result = if core == 1
                   local? ? `m2 hangup call #{uuid}` : execute_command_in_server("m2 hangup call #{uuid}")
                 else
                   Server.hangup_in_core_server(uuid)
                 end
        MorLog.my_debug("m2 hangup call command result(attempt: #{attempt + 1}): #{result}", true)
        if result.present?
          response = ''
          break
        end
        attempt += 1
      end
    end
    hangup_errors(response)
  end

  def hangup_sems(src, dst, uuid)
    command = "/usr/local/m4/sems_hangup_call.sh #{src} #{dst} 2>&1"
    response = local? ? `#{command}` : execute_command_in_server(command)
    hangup_errors(response)
    MorLog.my_debug("/usr/local/m4/sems_hangup_call.sh result: #{response}")
    hangup_call(uuid) if response.to_s.match(/No such file or directory/)
    response
  end

  def hangup_errors(response)
    if response == false
      flash_help_link = 'http://wiki.ocean-tel.uk/index.php/Configure_SSH_connection_between_servers'
      error_msg = "#{_('Cannot_connect_to_server')} #{server_ip}"
      error_msg += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>"
      errors.add(:hangup_error, error_msg)
    end

    if response.to_s.match(/\[ERROR\]/)
      errors.add(:hangup_error, _('Freeswitch_is_not_running'))
    end
  end

  def self.hangup_in_core_server(uuid)
    server = Server.where(core: 1).first
    server.local? ? `m2 hangup call #{uuid}` : server.execute_command_in_server("m2 hangup call #{uuid}")
  end

  def set_proxy_server_confline
    Confline.set_value('M2_proxy_host', server_ip.to_s) if server_type == 'proxy'
  end

  def unset_proxy_server_confline
    Confline.destroy_all(name: 'M2_proxy_host') if server_type == 'proxy'
  end

  def set_es_ip_confline
    Confline.set_value('ES_IP', server_ip) if es == 1
  end

  def unset_es_ip_confline
    Confline.set_value('ES_IP', '127.0.0.1') if es == 1
  end

  def check_if_proxy_exists
    proxy_server_count = Server.where(id ? "server_type = 'proxy' AND id != #{id}" : "server_type = 'proxy'").count
    if server_type == 'proxy' && proxy_server_count > 0 then
      errors.add(:id, _("Proxy_Server_already_exists"))
      return false
    end
  end

  def load_stats(date)
    report = {hdd_util: [], cpu_general_load: [], cpu_loadstats1: [], service_load: []}

    server_loadstats
    .select('server_loadstats.*, DATE_FORMAT(datetime, "%Y %m %d %H %i") AS date')
    .where('DATE(datetime) = ?', date)
    .group('YEAR(datetime), MONTH(datetime), DAY(datetime), HOUR(datetime), MINUTE(datetime)')
    .each do |stat|
      date = stat['date'].split.map(&:to_i)
      report[:hdd_util] << [date, stat['hdd_util'].to_f]
      report[:cpu_general_load] << [date, stat['cpu_general_load'].to_f]
      report[:cpu_loadstats1] << [date, stat['cpu_loadstats1'].to_f]
      report[:service_load] <<
          [
              date,
              stat['cpu_mysql_load'].to_f,
              stat['cpu_ruby_load'].to_f,
              stat['cpu_freeswitch_load'].to_f,
              stat['cpu_java_load'].to_f,
              ((self.b2bua.to_i == 1 || self.media.to_i == 1) ? stat['cpu_b2bua_load'] : 0).to_f,
              ((self.b2bua.to_i == 1 || self.media.to_i == 1) ? stat['cpu_media_load'] : 0).to_f,
              (self.proxy.to_i == 1 ? stat['cpu_kamailio_load'] : 0).to_f,
              (self.core.to_i == 1 ? stat['cpu_radius_load'] : 0).to_f
          ]
    end
    report
  end

  def self.proxy_server_active
    Server.where(server_type: 'proxy', active: 1).present?
  end

  def self.sip_proxy_server_present
    Server.where(server_type: 'sip_proxy').present?
  end

  def self.single_fs_server_active
    Server.where("active = 1 AND (server_type = 'freeswitch' OR fs = 1)").all.size == 1
  end

  def self.execute_command_on_remote_server(options = {})
    if options[:server_ip].to_s == 'local'
      MorLog.my_debug 'Elasticsearch synchronization started on local server'
      result = `#{options[:command]}`
    else
      begin
        # Before doing this, connection between servers should be established using:
        #   http://wiki.ocean-tel.uk/index.php/Configure_SSH_connection_between_servers
        MorLog.my_debug 'Elasticsearch synchronization started on remote server'
        MorLog.my_debug "server_ip: #{options[:server_ip]}"
        MorLog.my_debug "ssh_username: #{options[:ssh_username]}"
        MorLog.my_debug "ssh_port: #{options[:ssh_port]}"
        MorLog.my_debug "command: #{options[:command]}"
        Net::SSH.start(
          options[:server_ip].to_s, options[:ssh_username].to_s, port: options[:ssh_port].to_i, timeout: 10,
          keys: %w[/var/www/.ssh/id_rsa], auth_methods: %w[publickey]
        ) { |ssh| result = ssh.exec! options[:command] }
      rescue Net::SSH::Exception, SystemExit, ScriptError, StandardError => error
        MorLog.my_debug "Command execution on Remote Server (IP: #{options[:server_ip]}, Commad = #{options[:server_ip]}) failed, error:\n #{error.message}"
        return false
      end
    end
    result
  end

  def self.m2_reload
    servers = Server.where(core: 1, active: 1).all
    servers.each do |server|
      response = server.execute_command_in_server('timeout 5s m2 show status')
      if response.to_s.match(/Core version/)
        server.execute_command_in_server('m2 reload')
        break
      end
    end
  end

  def self.check_server_status
    current_min = Time.current.min

    Server.server_statuses if current_min % 10 == 0

    Server.server_statuses(true) if current_min % 10 == 1
  end

  def self.server_statuses(value = false)
    Server.freeswitches_status_check(value)
    Server.radius_servers_status_check(value)
    Server.elasticsearch_status_check(value)
    Server.db_replication_status(value)
  end

  def self.freeswitches_status_check(second = false)
    return_value = 0
    servers = Server.where(server_type: 'freeswitch', active: 1).all
    servers.each do |server|
      command = "timeout 5s fs_cli -x 'status'"
      begin
        response = server.execute_command_in_server(command)
        return_value = 2 unless response.to_s.match(/FreeSWITCH.+is ready/)
      rescue
        return_value = 2
      end
      return_value = 1 if !second && return_value == 2
      server.update_column(:fs_status, return_value) if server.fs_status != return_value
    end
  end

  def self.radius_servers_status_check(second = false)
    servers = Server.where(core: 1, active: 1).all
    servers.each {|server| server.radius_status_check(second)}
  end

  def radius_status_check(second = false)
    return_value = 0
    command = "timeout 5s m2 show status 2>&1"
    begin
      response = execute_command_in_server(command)
      MorLog.my_debug(response)
      return_value = 2 unless response.to_s.match(/Core version/)
    rescue
      return_value = 2
    end
    return_value = 1 if !second && return_value == 2
    update_column(:radius_status, return_value) if radius_status != return_value
  end

  def self.elasticsearch_status_check(second = false)
    return_value = 0
    begin
      return_value = 2 unless Elasticsearch.safe_search_m2_calls_with_debug.present?
    rescue => exception
      MorLog.my_debug("elasticsearch_status_check: #{exception}")
      return_value = 2
    end
    return_value = 1 if !second && return_value == 2
    es_status = Confline.get_value('ES_status').present? ? Confline.get_value('ES_status').to_i : 0
    Confline.set_value('ES_status', return_value) if return_value != es_status
  end

  def self.db_replication_status(second = false)
    return_value = 0
    db_replication = ActiveRecord::Base.connection.select_all('SHOW SLAVE STATUS').first
    if db_replication.present?
      if (db_replication['Slave_IO_Running'] == 'Yes') && (db_replication['Slave_SQL_Running'] == 'Yes')
        begin
          return_value = 2 unless ReplicationRemote.db_replication_status == 1
        rescue => exception
          MorLog.my_debug("Replication exception: #{exception}")
          return_value = 2
        end
      else
        return_value = 2
      end
    end
    return_value = 1 if !second && return_value == 2
    replication_status = Confline.get_value('db_replication_status').present? ? Confline.get_value('db_replication_status').to_i : 0
    Confline.set_value('db_replication_status', return_value) if return_value != replication_status
  end

  def server_fs?
    server_type == 'freeswitch' || fs == 1
  end
end
