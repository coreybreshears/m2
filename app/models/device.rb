# Device(Connection Points) model
class Device < ActiveRecord::Base
  attr_accessible *column_names

  # this is based on http://www.ruby-forum.com/topic/101557
  self.inheritance_column = :_type_disabled # we have devices.type column for asterisk 1.8 support,
                                            # so we need this to allow such column

  # setter for the "type" column
  def device_ror_type=(s)
    self[:type] = s
  end

  attr_accessor :device_ip_authentication_record
  attr_accessor :device_old_name_record
  attr_accessor :device_old_server_record
  attr_accessor :tmp_codec_cache

  belongs_to :user
  has_many :extlines, -> { order('exten ASC, priority ASC') }
  has_many :devicecodecs
  has_many :callerids
  belongs_to :server
  has_many :activecalls, foreign_key: 'src_device_id'
  has_many :server_devices, dependent: :destroy
  has_many :servers, through: :server_devices
  belongs_to :routing_group, foreign_key: 'op_routing_group_id'
  belongs_to :op_tariff, foreign_key: 'op_tariff_id', class_name: 'Tariff'
  belongs_to :tp_tariff, foreign_key: 'tp_tariff_id', class_name: 'Tariff'
  belongs_to :mnp_carrier_group
  has_many :dpeer_tpoints
  has_many :dial_peers, through: :dpeer_tpoints
  scope :visible, -> { where(hidden_device: 0) }
  before_validation :check_device_username, on: :create

  validates_presence_of :name, message: _('Device_must_have_name')
  validates_uniqueness_of :username, allow_blank: true, message: _('Device_Username_Must_Be_Unique')

  validates_format_of :max_timeout, with: /\A[0-9]+\z/,
                      message: _('Device_Call_Timeout_must_be_greater_than_or_equal_to_0')
  validates_numericality_of :port, message: _('Port_must_be_number'),
                            if: Proc.new { |value| not value.port.blank? }
  validates_numericality_of [:max_timeout], only_integer: true
  validate :validate_op_tp_settings, :validate_auth_domains

  # before_create :check_callshop_user
  before_save :uniqueness_check,
              :ensure_server_id, :random_password, :check_and_set_defaults,
              :ip_must_be_unique_on_save, :check_language,
              :check_dymanic_and_ip, :set_qualify_if_ip_auth,
              :update_mwi, :t38pt_normalize, :strip_params

  before_update :uniqueness_check
  after_create :create_codecs, :device_after_create
  after_save :device_after_save, :op_routing_group_id_changed?, :changes_present_set_1#, :prune_device #do not prune devices after save!
  # it abuses AMI and crashes live calls (#11709)!
  # prune_device is done in device_update->application_controller->configure_extensions->prune_device

  # 3239 dont know whats the reason to keep two identical fields, but just keep in mind that one is 1/0
  # other yes/no and their values has to be the same

  scope :origination_points, -> { where(op: 1) }
  scope :termination_points, -> { where(tp: 1) }
  scope :nice_user_sql, -> { select("*, devices.id as dev_id, IF(LENGTH(TRIM(CONCAT(users.first_name, ' ', users.last_name))) > 0,TRIM(CONCAT(users.first_name, ' ', users.last_name)), users.username) AS nice_username").
                                                               joins('LEFT JOIN users on users.id = devices.user_id') }
  scope :nice_device_sql, -> { select("*,devices.id as dev_id, if(devices.description = '',
                                         CONCAT(IF(LENGTH(TRIM(CONCAT(users.first_name, ' ', users.last_name))) > 0,TRIM(CONCAT(users.first_name, ' ', users.last_name)), users.username),'/',devices.host),
                                         devices.description) as nice_device").
                                  joins('LEFT JOIN users on users.id = devices.user_id') }
  scope :termination_points_with_user, -> { termination_points.nice_user_sql.order('nice_username, description ASC') }
  scope :origination_points_sort_nice_device, -> { origination_points.nice_device_sql.order('nice_device ASC')}
  scope :termination_points_sort_nice_device, -> { termination_points.nice_device_sql.order('nice_device ASC')}
  scope :active_origination_points, -> { origination_points.where(op_active: 1) }
  scope :active_termination_points, -> { termination_points.where(tp_active: 1) }

  scope :by_type, ->(type) do
    case type
    when 'op'
      origination_points
    when 'tp'
      termination_points
    end
  end


  # MK: subscribemwi is used by Asterisk 1.4, enable_mwi by Asterisk 1.8
  def update_mwi
    self.subscribemwi = ((self.enable_mwi == 1) ? 'yes' : 'no')
  end

  # Device may be blocked by core if there are more than one simultaneous call
  def block_callerid?
    (block_callerid.to_i > 1)
  end

  # Only valid arguments for block_callerid is 0 or integer greater than 1
  # if params  are invalid we set it to 0

  # Params
  # *simalutaneous_calls* limit of simultaneous calls when core should automaticaly
  #   block device
  def block_callerid=(simultaneous_calls)
    simultaneous_calls = simultaneous_calls.to_s.strip.to_i
    simultaneous_calls = simultaneous_calls < 2 ? 0 : simultaneous_calls
    write_attribute(:block_callerid, simultaneous_calls)
  end


  # Note that this method is written mostly thinking about using it in views so dont
  # expect any logic beyound that.

  # Returns
  # *simultaneous_calls* if block_callerid is set to smth less than 2 retun empty string
  #   else return that number
  def block_callerid
    simultaneous_calls = read_attribute(:block_callerid).to_i
    simultaneous_calls < 2 ? '' : simultaneous_calls
  end

  # true if srtp encryption is set for device, otherwise false
  def srtp_encryption?
    self.encryption.to_s == 'yes'
  end

  # if username is blank it means that ip authentication is enabled and there's
  # no need to check for valid passwords.
  # server device is an exception, so there's no need to check whether it's pass is valid or not.
  # TODO: each device type should have separate class. there might be PasswordlessDevice
  def check_password
    unless self.server_device? or self.username.blank?
      if self.name and self.secret.to_s == self.name.to_s
        errors.add(:secret, _('Name_And_Secret_Cannot_Be_Equal'))
        return false
      end
    end
  end

  def check_language
    if self.language.to_s.blank?
      self.language = 'en'
    end
  end

  def check_and_set_defaults
    if self.device_type
      if ['sip'].include?(self.device_type.downcase)
        self.nat ||= 'yes'
        self.canreinvite ||= 'no'
      end
    end
  end

  # checks if server with such id exists
  def ensure_server_id
    if self.server_id.blank? or !Server.where(:id => self.server_id).first
      default = Confline.get_value('Default_device_server_id')
      if default.present? and Server.where(:id => default).first.present?
        self.server_id = default
      else
        if server = Server.order('id ASC').first
          Confline.set_value('Default_device_server_id', server.id)
          self.server_id = server.id
        else
          errors.add(:server, _('Server_Not_Found'))
          return false
        end
      end
    end

  end

  def random_password
    if (self.device_type.to_s == 'Virtual') and self.secret.blank?
      self.secret = ApplicationController::random_password(10).to_s
    end
  end

  # converting callerid like "name" <number> to number
  def callerid_number
    cid = self.callerid
    cidn = ''

    if self.callerid and cid.index('<') and cid.index('>') and cid.index('<') >= 0 and cid.index('>') > 0
      cidn = cid[cid.index('<')+1, cid.index('>')-cid.index('<')-1]
    end

    cidn
  end

  def check_device_username
    if self.virtual?
      username = self.username;

      while Device.where(username: username).first
        username = self.generate_rand_name('', 12)
      end

      self.username = username
    end
  end

  def virtual?
    device_type == 'Virtual'
  end

  def generate_rand_name(string, size)
    chars = '123456789abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
    str = ''
    size.times { |int| str << chars[rand(chars.length)] }
    string + str
  end

  def Device.clis_order_by(options)
    case options[:order_by].to_s
    when 'cli'
      order_by = 'callerids.id'
    when 'device'
      order_by = 'devices.name'
    when 'description'
      order_by = 'callerids.description'
    when 'added_at'
      order_by = 'callerids.created_at'
    when 'updated_at'
      order_by = 'callerids.updated_at'
    when 'comment'
      order_by = 'callerids.comment'
    end

    if order_by
      case options[:order_desc]
      when 0
        order_by += ' ASC'
      when 1
        order_by += ' DESC'
      end
    end

    order_by
  end


  def device_after_save
    write_attribute(:accountcode, id)
    sql = "UPDATE devices SET accountcode = id WHERE id = #{id};"
    ActiveRecord::Base.connection.update(sql)
    update_ipaddr_ranges
  end


  def device_after_create
    #device_after_save
    if self.user
      user = self.user
      curr_id = User.current ? User.current.id : self.user.owner_id
      Action.add_action_hash(curr_id, {target_id: id, target_type: 'device', action: 'device_created'})
      dev = Device.where(id: user.id).all.size #Device.count(:all, :conditions=>"user_id = #{user.id}")
      if dev.to_i == 1
        user.primary_device_id = id
        user.save
      end
      self.update_cid(Confline.get_value('Default_device_cid_name', user.owner_id), Confline.get_value('Default_device_cid_number', user.owner_id)) unless self.callerid
    end
  end


  #================== CODECS =========================


  def create_codecs
    owner = self.user_id > 0 ? self.user.owner_id : 0
    Codec.all.each do |codec|
      if Confline.get_value("Default_device_codec_#{codec.name}", owner).to_i == 1
        pc = Devicecodec.new
        pc.codec_id = codec.id
        pc.device_id = self.id
        pc.priority = Confline.get_value2("Default_device_codec_#{codec.name}", owner).to_i
        pc.save
      end
    end
    self.update_codecs
  end

  def codec?(codec)
    sql = "SELECT codecs.name FROM devicecodecs, codecs WHERE devicecodecs.device_id = '" + self.id.to_s + "' AND devicecodecs.codec_id = codecs.id GROUP BY codecs.name HAVING COUNT(*) = 1"
    self.tmp_codec_cache = (self.tmp_codec_cache || ActiveRecord::Base.connection.select_values(sql))
    self.tmp_codec_cache.include? codec.to_s
  end

  def codecs
    res = Codec.select('*').joins("LEFT JOIN devicecodecs ON (devicecodecs.codec_id = codecs.id)").where("devicecodecs.device_id = #{self.id.to_s}").order("devicecodecs.priority").all
    codecs = []

    (0..res.size-1).each do |cods|
      codecs << Codec.where(id: res[cods]['codec_id']).first
    end

    codecs
  end

  def codecs_order(type)
    Codec.find_by_sql("SELECT codecs.*,  IF(devicecodecs.priority is null, 100, devicecodecs.priority)  as bb FROM codecs  LEFT Join devicecodecs on (devicecodecs.codec_id = codecs.id and devicecodecs.device_id = #{self.id.to_i})  where codec_type = '#{type}' ORDER BY bb asc, codecs.id")
  end


  def update_codecs_with_priority(codecs, ifsave = true)
    dev_c = {}
    Devicecodec.where(device_id: id).all.each { |c| dev_c[c.codec_id] = c.priority; c.destroy }
    Codec.all.each { |codec| Devicecodec.new(codec_id: codec.id, device_id: self.id,
                                               priority: dev_c[codec.id].to_i).save if codecs[codec.name] == '1' }
    self.update_codecs(ifsave)
  end

  def update_codecs(ifsave = true)
    cl = []
    self.codecs.each { |codec| cl << codec.try(:name) }
    cl << 'all' if cl.size.to_i == 0
    self.allow = cl.join(';')
    self.save if ifsave
  end

  #================== END OF CODECS =========================

  def update_cid(cid_name, cid_number, ifsave = true)

    cid_name = '' if not cid_name
    cid_number = '' if not cid_number

    self.callerid = nil unless self.callerid

    if cid_name.length > 0 and cid_number.length > 0
      self.callerid = "\"" + cid_name.to_s + "\"" + " <" + cid_number.to_s + ">"
    end

    if cid_name.length > 0 and cid_number.length == 0
      self.callerid = "\"" + cid_name.to_s + "\""
    end

    if cid_name.length == 0 and cid_number.length == 0
      self.callerid = ''
    end

    if cid_name.length == 0 and cid_number.length > 0
      self.callerid = "<" + cid_number.to_s + ">"
    end

    self.save if ifsave
  end

  #======================= CALLS =============================

  def all_calls
    Call.where(src_device_id: self.id)
  end

  def any_calls
    Call.where(src_device_id: self.id).limit(1)
  end

  def dst_calls_present?
    Call.where(dst_device_id: id).limit(1).present?
  end

  def calls(type, date_from, date_till)
    #possible types:
    # all +
    #    local
    #    external
    #       incoming
    #         missed +
    #         missed_not_processed +
    #       outgoing
    #         answered
    #         failed
    #           busy
    #           no_answer
    #           error
    if type == 'all'
      @calls = Call.where(['src_device_id =? ' + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'answered'
      @calls = Call.where(["billsec > 0 AND src_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'noanswer'
      @calls = Call.where(["src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'failed'
      @calls = Call.where(["src_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'busy'
      @calls = Call.where(["src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'missed'
      @calls = Call.where(["src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'missed_not_processed'
      @calls = Call.where(["processed = '0' AND src_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    #---incoming---

    if type == 'all_inc'
      @calls = Call.where(['dst_device_id =? ' + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'answered_inc'
      calls = Call.where(["billsec > 0 AND dst_device_id = ? AND disposition = 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'noanswer_inc'
      @calls = Call.where(["dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'failed_inc'
      @calls = Call.where(["dst_device_id = ? AND disposition = 'FAILED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'busy_inc'
      @calls = Call.where(["dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'missed_inc'
      @calls = Call.where(["dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'missed_not_processed_inc'
      @calls = Call.where(["processed = '0' AND dst_device_id =? AND disposition != 'ANSWERED' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    #--not used---

    if type == 'incoming'
      @calls = Call.where(["user_price >= 0 AND dst_device_id =? " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    if type == 'outgoing'
      @calls = Call.where(["user_price >= 0 AND src_device_id =? " + date_query(date_from, date_till), self.id]).order(calldate: :desc).all
    end

    @calls
  end

  def total_calls(type, date_from, date_till)
    if type == 'all'
      t_calls = Call.where(["(src_device_id = ? OR dst_device_id =?) AND user_id IS NOT NULL " + date_query(date_from, date_till), self.id, self.id]).order(calldate: :desc).count
    end

    if type == 'answered'
      t_calls = Call.where(["billsec > 0 AND src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'answered_out'
      t_calls = Call.where(["src_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'no_answer_out'
      t_calls = Call.where(["src_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'busy_out'
      t_calls = Call.where(["src_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'failed_out'
      t_calls = Call.where(["src_device_id = ?  AND user_id IS NOT NULL AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'answered_inc'
      t_calls = Call.where(["dst_device_id = ? AND #{Call.nice_answered_cond_sql} " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'no_answer_inc'
      t_calls = Call.where(["dst_device_id = ? AND disposition = 'NO ANSWER' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'busy_inc'
      t_calls = Call.where(["dst_device_id = ? AND disposition = 'BUSY' " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'failed_inc'
      t_calls = Call.where(["dst_device_id = ? AND #{Call.nice_failed_cond_sql} " + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'missed_not_processed'
      t_calls = Call.where(["processed = '0' AND dst_device_id =? AND #{Call.nice_answered_cond_sql(false)}" + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'incoming'
      t_calls = Call.where(['dst_device_id =? ' + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    if type == 'outgoing'
      t_calls = Call.where(['src_device_id =? AND user_id IS NOT NULL ' + date_query(date_from, date_till), self.id]).order(calldate: :desc).count
    end

    t_calls
  end

  def total_duration(type, date_from, date_till)
    call_nice_answered_cond_sql = Call.nice_answered_cond_sql
    if type == 'answered' || type == 'answered_out'
      t_duration = Call.where(["billsec > 0 AND src_device_id = ? AND #{call_nice_answered_cond_sql} " + date_query(date_from, date_till), id]).order(calldate: :desc).sum(:duration)
    end

    if type == 'answered_inc'
      t_duration = Call.where(["billsec > 0 AND dst_device_id = ? AND #{call_nice_answered_cond_sql} " + date_query(date_from, date_till), id]).order(calldate: :desc).sum(:duration)
    end

    t_duration = 0 if t_duration.blank?
    t_duration
  end


  def total_billsec(type, date_from, date_till)

    if type == 'answered'
      sql = "SELECT sum(billsec) AS sum_billsec2 FROM calls WHERE (billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == 'answered_out'
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (billsec > 0 AND src_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    if type == 'answered_inc'
      sql = "SELECT sum(billsec) AS sum_billsec FROM calls WHERE (billsec > 0 AND dst_device_id = '#{self.id}' AND #{Call.nice_answered_cond_sql} #{date_query(date_from, date_till)}) ORDER BY calldate DESC"
      res = ActiveRecord::Base.connection.select_one(sql)
      t_billsec = res['sum_billsec'].to_i
    end

    t_billsec = 0 if t_billsec.blank?
    t_billsec
  end


  # forms sql part for date selection

  def date_query(date_from, date_till)
    # date query
    if date_from == ''
      date_sql = ''
    else
      if date_from.length > 11
        date_sql = "AND calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'"
      else
        date_sql = "AND calldate BETWEEN '" + date_from.to_s + " 00:00:00' AND '" + date_till.to_s + " 23:59:59'"
      end
    end
    date_sql
  end

  def destroy_everything
    err = []
    if self.all_calls.size == 0

      self.callerids.each do |cid|
        cid.destroy
      end

      Extline.delete_all(["device_id = ?", self.id])

      err = self.reload_device_in_all_fs(nil)

      self.destroy
    end
    err
  end


  def reload_device_in_all_fs(dv_name = nil)
    dv_name = name if dv_name.blank?
    err= []
    # clean Realtime mess
    servers = Server.all
    servers.each do |server|
      begin
        server.fs_device_reload(dv_name)
      rescue StandardError, SystemExit => error # SystemExit is not subclass of standardError, rescue => e will only cause crash'es
        err << error.message
      end
    end

    err
  end

  def reload_device_in_fs(dv_name = nil, serverid = nil)
    dv_name = name if dv_name.blank?
    serverid = server_id if serverid.blank?
    err= []
    # clean Realtime mess http://trac.ocean-tel.uk/trac/ticket/5092
    server = Server.where(id: serverid).first
    begin
      server.fs_device_reload(dv_name) if server
    rescue StandardError, SystemExit => error # SystemExit is not subclass of standardError, rescue => e will only cause crash'es
      err << error.message
    end
    err
  end

  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, 'a') { |file_line|
      file_line << msg.to_s
      file_line << "\n"
    }
  end

  def used_by_alerts
    Alert.where("
      (check_type IN ('termination_point', 'origination_point')) && check_data = #{self.id}"
    ).first
  end

  def uniqueness_check
    fields	= %w{ username } # why only username?
    matches	= ["host = 'dynamic' AND devices.id != ?", self.id]
    query = Hash[fields.map {|field| [field.to_sym, self[field.to_sym].to_s] }]
  end

  def dynamic?
    (ipaddr.blank? or ipaddr.to_s == '0.0.0.0')
  end

  def auth_dynamic?
    dynamic.to_s == 'yes'
  end

  def auth_dynamic_reg_status
    registration_status = reg_status.to_s.upcase
    registration_status = 'UNREGISTERED' if registration_status.blank?
    registration_status
  end

  def nice_ipaddr
    if auth_dynamic? && ipaddr.blank?
      "DYNAMIC #{auth_dynamic_reg_status}"
    elsif ipaddr.blank?
      ''
    else
      "#{ipaddr}:#{port}"
    end
  end

  def ip_must_be_unique_on_save
    idi = self.id

    curr_id = User.current && !manager? ? User.current.id : self.user.owner_id


    message = if admin?
                _('When_IP_Authentication_checked_IP_must_be_unique') + '. ' +
                _('ip_is_used_by_user')
              else
                _('This_IP_is_not_available') +
                "<a id='exception_info_link' href='http://wiki.ocean-tel.uk/index.php/Authentication' target='_blank'>" +
                "<img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>"
              end

    cond = if ipaddr.blank?

             ['devices.id != ? AND host = ? AND ipaddr != "" and ipaddr != "0.0.0.0"', idi, host]
           else

             ['devices.id != ? AND (host = ? OR ipaddr = ?) AND ipaddr != "" and ipaddr != "0.0.0.0"', idi, host, ipaddr]
           end

    #      check self device  or another devices with ip auth on
    condd = self.device_ip_authentication_record.to_i == 1 ? '' : ' and devices.username = "" '

    cond_second = if ipaddr.blank?
               # check device host with another owner devices
               ['devices.id != ? AND host = ? and users.owner_id != ?  and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0"' + condd, idi, host, curr_id]
             else
               # check device IP and Host with another owner devices
               ['devices.id != ? AND (host = ? OR ipaddr = ?) and users.owner_id != ? and user_id != -1 and ipaddr != "" and ipaddr != "0.0.0.0"' + condd, idi, host, ipaddr, curr_id]
             end


    device_with_ip = Device.joins("JOIN users ON (user_id = users.id)").where(cond_second).first

    if device_with_ip and !self.dynamic? and !self.virtual?
      if admin?
        message << " #{nice_device_user(device_with_ip)} in Device: #{nice_device(device_with_ip)}."
      end
      errors.add(:ip_authentication, message)
      return false
    end
  end

  def set_qualify_if_ip_auth
    if Confline.get_value('Show_Qualify_setting_for_ip_auth_Device').to_i != 1
      self.qualify = 'no'
    end
  end

  def check_dymanic_and_ip
    if username.to_s.blank? and host.to_s == 'dynamic'
      errors.add(:host, _('When_IP_Authentication_checked_Host_cannot_be_dynamic'))
      return false
    end
  end

  def username_must_be_unique
    Confline.get_value('Disalow_Duplicate_Device_Usernames').to_i == 1 and self.device_ip_authentication_record.to_i == 0
  end

  def Device.validate_perims(options={})
    permits = '0.0.0.0/0.0.0.0'
    if options[:ip_first].size > 0 and options[:mask_first].size > 0
      unless Device.validate_ip(options[:ip_first].to_s) and Device.validate_ip(options[:mask_first].to_s)
        return nil
      end
      permits = options[:ip_first].strip + '/' + options[:mask_first].strip
      if options[:ip_second].size > 0 and options[:mask_second].size > 0
        unless Device.validate_ip(options[:ip_second]) and Device.validate_ip(options[:mask_second])
          return nil
        end
        permits += ';' + options[:ip_second].strip + '/' + options[:mask_second].strip
        if options[:ip_third].size > 0 and options[:mask_third].size > 0
          unless Device.validate_ip(options[:ip_third]) and Device.validate_ip(options[:mask_third])
            return nil
          end
          permits += ';' + options[:ip_third].strip + '/' + options[:mask_third].strip
        end
      end
    end
    permits
  end

  def Device.validate_permits_ip(ip_arr)
    err = true
    ip_arr.each { |ip|
      if ip and !ip.blank? and !Device.validate_ip(ip)
        err = false
      end
    }
    err
  end

  def Device::validate_ip(ip)
    ip.gsub(/(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)/, '').to_s.length == 0 ? true : false
  end

  def Device.find_all_for_select(current_user_id = nil, options={})
    if current_user_id
      select_clause = options[:count].present? ? 'COUNT(devices.id) AS count_all' : 'devices.*'
      Device.select(select_clause)
            .joins('LEFT JOIN users ON (users.id = devices.user_id)')
            .where(["(users.owner_id = ? OR users.id = ?) AND name not like 'mor_server_%' AND user_id > -1", current_user_id, current_user_id])
            .all
    else
      Device.select('*').where("name not like 'mor_server_%' AND user_id > -1").all
    end
  end

  def perims_split
    ip = []
    mask = []

    data = permit.split(';')

    3.times do |i|
      if data[i]
        rp = data[i].split('/')
        ip[i+1] = rp[0]
        mask[i+1] = rp[1]
      end
    end

    return ip[1], mask[1], ip[2], mask[2], ip[3], mask[3]
  end


  def Device.calleridpresentation
    [
        [_('Presentation_Allowed_Not_Screened'), 'allowed_not_screened'], [_('Presentation_Allowed_Passed_Screen'), 'allowed_passed_screen'],
        [_('Presentation_Allowed_Failed_Screen'), 'allowed_failed_screen'], [_('Presentation_Allowed_Network_Number'), 'allowed'],
        [_('Presentation_Prohibited_Not_Screened'), 'prohib_not_screened'], [_('Presentation_Prohibited_Passed_Screen'), 'prohib_passed_screen'],
        [_('Presentation_Prohibited_Failed_Screen'), 'prohib_failed_screen'], [_('Presentation_Prohibited_Network_Number'), 'prohib'],
        [_('Number_Unavailable'), 'unavailable']
    ]
  end

  def validate_before_destroy(current_user)
    notice = ''

    unless user
      notice = _('User_was_not_found')
    end

    if notice.blank? && (self.any_calls.size > 0 || self.dst_calls_present?)
      notice = _('Cant_delete_device_has_calls')
    end

    if self.used_by_alerts and notice.blank?
      notice = _('Device_assigned_to_alerts')
    end

    if self.dpeer_tpoints.first
      notice = _('device_used_for_termination_points')
    end

    notice
  end

  def destroy_all
    Extline.delete_all(["device_id = ?", id])

    # destroying device connection to servers
    ServerDevice.where("device_id = ?", id).all.each do |server_dev|
      server_dev.destroy
    end

    # destroying codecs
    Devicecodec.where(device_id: id).all.each do |device_cod|
      device_cod.destroy
    end

    user = user
    self.destroy_everything
  end

  def Device.validate_before_create(current_user, user, params, allow_dahdi, allow_virtual)
    notice = ''

    unless user
      notice = _('User_was_not_found')
    end

    params[:device][:description].try(:strip!)
    params[:device][:pin].try(:strip!)
    params_device_pin = params[:device][:pin]
    params_device_ipaddr = params[:device][:ipaddr]
    allowed_registration_auth = Confline.get_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration').to_i == 1

    # pin
    if notice.blank? && (Device.where([' pin = ?', params_device_pin]).first && params_device_pin.to_s != '')
      notice = _('Pin_is_already_used')
    end

    if  notice.blank? and !params_device_pin.to_s.blank? and params_device_pin.to_s.strip.scan(/[^0-9 ]/).compact.size > 0
      notice = _('Pin_must_be_numeric')
    end

    if notice.blank?
      device = Device.new
      if params_device_ipaddr.present?
        params[:ip_authentication] = 1
        params[:host] = params_device_ipaddr
        device, device_update_errors = Device.validate_ip_address_format(params, device, device_update_errors = 0)
      elsif !allowed_registration_auth && params_device_ipaddr.blank?
        device.errors.add(:ip_authentication_error, _('IP_address_must_be_provided'))
      end
      notice = device.errors.first[1] unless device.errors.blank?
    end

    params[:device][:device_type] = 'SIP'

    return notice, params
  end


  # only SIP and IAX devices can have name. but only first two can be authenticated by ip.
  # users can not see SIP/IAX2 device's username if ip
  # authentication is set. and we determine whether ip auth is set by checking if username is empty.

  # *Returns*
  #   *boolean* true or false depending whether we should show username or not
  def show_username?
    (not username.blank? && device_type == 'SIP')
  end

  def cid_number_nice
    numbers = []
    self.callerids.each { |cid_n| numbers << [cid_n.cli, cid_n.id] } if self.callerids and self.callerids.size.to_i > 0
    numbers
  end

  def device_caller_id_number
    device_caller_id_number = 1
    device_caller_id_number = 4 if control_callerid_by_cids.to_i != 0
    device_caller_id_number = 5 if callerid_advanced_control.to_i == 1
    device_caller_id_number = 7 if callerid_number_pool_id.to_i != 0
    device_caller_id_number
  end

  # check whether device belongs to server

  # *Returns*
  # boolean - true if device belongs to server, else false
  def server_device?
    self.name =~ /mor_server_\d+/ ? true : false
  end

  DefaultPort = {'SIP' => 5060}


  # Check whether port is valid for supplied technology, at this moment only illegal ports are those that are < 1
  # +valid+ true if port is valid, else false
  def self.valid_port?(port, technology)
    if port.to_i < 1
      false
    elsif technology == 'SIP'
      true
    else
      true
    end
  end

  def device_old_name
    @device_old_name_record
  end

  def device_old_server
    @device_old_server_record
  end

  def set_old_name
    self.device_old_name_record = name
    self.device_old_server_record = server_id
  end

=begin
  Set time limit per day option for the device. In database it is saved in seconds but this
  method is expecting minutes tu be passed to it. If negative or none numeric params would be
  passed it will be converted to 0. if float would be passed as param, decimal part would be
  striped.

  *Params*
  +minutes+ integer, time interval in minutes.
=end
  def time_limit_per_day=(minutes)
    minutes = (minutes.to_i < 0) ? 0 : minutes.to_i
    seconds = minutes * 60
    write_attribute(:time_limit_per_day, seconds)
  end

  # Get time limit per day expressed in minutes. In database it is saves in seconds, sho we just
  # convert to minutes by deviding by 60. Obviuosly this is OOD mistake, we should use so sort of
  # 'time interval' instance..

  # +minutes+ integer, time interval in minutes
  def time_limit_per_day
    (read_attribute(:time_limit_per_day) / 60).to_i
  end

  def is_dahdi?
    return self.device_type == 'dahdi'
  end

  def create_server_devices(servers)
    unless servers.blank?
      servers_amount = []
      servers.each do |serv|
        server = Server.where(id: serv[0].to_i).first
        if server
          server_dev = ServerDevice.where("server_id = #{serv[0].to_i} AND device_id = #{id}").first

          unless server_dev
            server_device = ServerDevice.new({server_id: serv[0].to_i, device_id: id})
            server_device.save
          end

          servers_amount << serv[0].to_i
        end
      end

      if servers_amount.present?
        ActiveRecord::Base.connection.execute("DELETE FROM server_devices WHERE device_id = '#{id}' AND server_id NOT IN (#{servers_amount.join(',')})")
      else
        ActiveRecord::Base.connection.execute("DELETE FROM server_devices WHERE device_id = '#{id}'")
      end
    end
  end

  # this method just cleans server from device
  # used in device_update action
  # only when device name or server_id changes
  def sip_prune_realtime_peer(device_name, device_server_id)

    return if self.device_type != "SIP"

    server = Server.find(device_server_id.to_s)
    if server and server.active == 1
      rami_server = Rami::Server.new({'host' => server.server_ip, 'username' => server.ami_username, 'secret' => server.ami_secret})
      rami_server.console = 1
      rami_server.event_cache = 100
      rami_server.run
      client = Rami::Client.new(rami_server)
      client.timeout = 3

      time = client.command('sip prune realtime peer ' + device_name.to_s)

      client.respond_to?(:stop) ? client.stop : false
    end
  end

  def self.validate_ip_address_format(params, device, device_update_errors)

    # If device uses ip authentication it cannot be dynamic and valid host must be specified

    if params[:ip_authentication].to_i == 1
      ip = params[:host].to_s.strip
      port = params[:port].to_s.strip

      # define ip address type
      ip_address_format = Device.define_ip_address_format(ip)
      # validating single IP address
      if (ip_address_format == 1) && (ip.blank? || !ip.match(/^(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))$/))
        device.errors.add(:ip_authentication_error, _('must_specify_proper_host_if_ip_single_format'))
        device_update_errors += 1
      end

      # validating IP address mask (prefix must be in range [4-32])
      if ip_address_format == 2
        ip_mask = ip.split('/')[1]
        if !(4..30).member?(ip_mask.to_i)
          device.errors.add(:ip_authentication_error, _('ip_prefix_size_should_be_between_24_and_32'))
          device_update_errors += 1
        end
      end

      # validating IP address range (xxx.xxx.xxx.xxx-yyy, xxx<yyy, xxx in range [0-254], yyy in range [0-255])
      if ip_address_format == 3
        ip_range = ip.split('.').last.split('-')
        range_start = ip_range.first.to_i
        range_end = ip_range.last.to_i

        if ( !(0..254).member?(range_start)) || ( !(1..255).member?(range_end)) || (range_start >= range_end)
          device.errors.add(:ip_authentication_error, _('must_specify_proper_host_if_ip_range_format'))
          device_update_errors += 1
        end
      end

      unless Application.allow_duplicate_ip_port?
        # Validating IP uniquesness, IP + Port should be unique in system
        if port.present?
          condition = 'host = ? AND port = ? AND id != ?'
          self_id = device.id
        end
      end

    end


    return device, device_update_errors
  end


  def self.define_ip_address_format(ip)
    ip_address_format = 1
    ip_address_format = 2 if ip.match(/^(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\/[0-9]{1,3}$/)
    ip_address_format = 3 if ip.match(/^(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\-[0-9]{1,3}$/)

    ip_address_format
  end

  def adjust_insecurities(ccl_active, params, switched_auth = false)
    if ccl_active
      self.insecure = (device_type == 'SIP') ? 'port' : 'no'
    else
      insecurities = []

      insecurities << params[:device][:insecure].to_s
      # insecurities << 'invite' if params[:insecure_invite]
      #insecurities << 'no' if insecurities.blank?

      self.insecure = insecurities.join(',')
    end
  end

  def ipauth_insecurities_on_create
    if name.include?('ipauth') && (device_type == 'SIP')
      self.insecure = 'port'
    end
  end

  def set_server(device, ccl_active, sip_proxy_server, reseller)
    if ccl_active && (device.device_type == 'SIP')
      device.server = sip_proxy_server
    elsif reseller
      first_srv = Server.first.id
      def_asterisk = Confline.get_value('Resellers_server_id').to_i
      def_asterisk = first_srv if def_asterisk.to_i == 0
      device.server_id = def_asterisk
    end
  end

  def set_ports(params_port)
    device_type = self.device_type

    unless (Device.valid_port? self.port, device_type)
      self.port = case device_type
                    when 'SIP'
                      5060
                    end
    end

    self.proxy_port = self.port
  end

  def create_server_relations(device, sip_proxy_server, ccl_active)
    # if device type = SIP and device host = dynamic and ccl_active = 1 it must be assigned to sip_proxy server
    device_id = device.id
    serv_dev = ServerDevice.where(server_id: device.server_id, device_id: device_id).first

    if (device.device_type == 'SIP') && sip_proxy_server && ccl_active
      unless serv_dev
        server_device = ServerDevice.new_relation(sip_proxy_server.id, device_id)
        server_device.save
      end
    end
  end

  def nice_device_description_with_user
    if self.user_id == -1
      nice_user = ' - '
    else
      nice_user = "#{User.find(self.user_id).nice_user} - "
    end
    if self.description.present?
      "#{nice_user}#{self.description.to_s}".truncate(60)
    else
      "#{nice_user}#{self.host.to_s}"
    end
  end

  def blocked_ip_status
  	BlockedIP.check_if_blocked(ipaddr)
  end

  def self.active_calls_distribution(current_user, options = {})
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than == 0
    type = options[:op] ? 'op' : 'tp'
    device_id = if options[:op]
                  username = SqlExport.nice_user_name_sql + ','
                  join = 'JOIN users ON (devices.user_id = users.id)'
                  'src_device_id'
                else
                  username = join = ''
                  'dst_device_id'
                end
    query = "
      SELECT
        devices.id,
        devices.name,
        devices.extension,
        devices.description,
        devices.ipaddr AS ip_address,
        devices.#{type}_capacity AS calls_limit,
        devices.device_type,
        devices.user_id,
        #{username}
        COUNT(devices.id) AS total,
        COUNT(activecalls.answer_time) AS answered,
        0 AS free_lines
      FROM devices
        JOIN activecalls ON (
          devices.id = activecalls.#{device_id}
        )
      #{join}
      WHERE devices.#{type} = 1"
      if current_user.show_only_assigned_users?
        assigned_users = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
        assigned_users = assigned_users.map(&:inspect).join(', ')
        query << " AND (activecalls.user_id IN (#{assigned_users.present? ? assigned_users : 'NULL'}))"
      end
      query << " AND DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()
        AND activecalls.active > 0
      GROUP BY devices.id"
    format_distribution(find_by_sql(query))
  end

  def nice_name
    description.blank? ? ip_address.to_s : description.to_s
  end

  def hidden?
    hidden_device.to_i == 1
  end

  def hide
    if hidden?
      self.hidden_device = 0
    else
      self.op_active = 0
      self.tp_active = 0
      self.hidden_device = 1
    end
    self.save
  end

  def self.op_pai_dropdown
    {
      never: _('Never'),
      always: _('Always'),
      if_from_is_anonymous: _('If_FROM_is_Anonymous'),
      if_from_is_not_anonymous: _('If_FROM_is_not_Anonymous')
    }
  end

  def update_ipaddr_ranges
    ip = ipaddr.to_s

    if ip.include?('-')
      # Update devices with ip range (for example 192.168.0.100-150)
      ip_range_start = ip.split('-').first
      ip_range_end = "#{ip.split('.')[0..2].join('.')}.#{ip.split('-').last}"

    elsif ip.include?('/')
      # Update devices with ip subnet (for example 192.168.0.1/24)
      ip_range_start = `whatmask #{ip} | grep 'First Usable' | grep -o '[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}'`.to_s.strip
      ip_range_end = `whatmask #{ip} | grep 'Last Usable' | grep -o '[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}\\.[0-9]\\{1,3\\}'`.to_s.strip
    else
      # Update devices with normal ip
      ip_range_start, ip_range_end = [ip, ip]
    end

    ActiveRecord::Base.connection.execute("
      UPDATE devices
      SET ipaddr_range_start = INET_ATON('#{ip_range_start}'), ipaddr_range_end = INET_ATON('#{ip_range_end}')
      WHERE id = '#{id}'
    ")
  end

  def changes_present_set_1
    update_column(:changes_present, 1)
  end

  def op_routing_group_id_changed?
    op_routing_data_changed_set_1 if self.previous_changes.include?(:op_routing_group_id)
  end

  def op_routing_data_changed_set_1
    update_column(:op_routing_data_changed, 1)
  end

  def timeout
    self['timeout']
  end

  def tp_l_uuid
    Digest::MD5.hexdigest(id.to_s)
  end

  def assign_advanced_auth_settings(params)
    assign_attributes(
      auth_check_cli: params[:auth_check_cli].to_i,
      auth_check_cld: params[:auth_check_cld].to_i,
      auth_check_from_domain: params[:auth_check_from_domain].to_i,
      auth_check_to_domain: params[:auth_check_to_domain].to_i
    )

    assign_auth_cli_settings(params) if params[:auth_check_cli].to_i == 1
    assign_auth_cld_settings(params) if params[:auth_check_cld].to_i == 1

    self.domain_from_auth = params[:domain_from_auth].to_s if params[:domain_from_auth].to_s.present?
    self.domain_to_auth = params[:domain_to_auth].to_s if params[:domain_to_auth].to_s.present?
  end

  def assign_auth_cli_settings(params)
    assign_attributes(
      cli_from_diversion: params[:cli_from_diversion].to_i,
      cli_from_rpid: params[:cli_from_rpid].to_i,
      cli_from_pai: params[:cli_from_pai].to_i,
      cli_from_ppi: params[:cli_from_ppi].to_i,
      cli_from_from: params[:cli_from_from].to_i,
      use_pai_if_cli_anonymous: params[:use_pai_if_cli_anonymous].to_i,
      cli_tr_rule_type: params[:cli_tr_rule_type].to_i,
      cli_allow_type: params[:cli_allow_type].to_i,
      cli_deny_type: params[:cli_deny_type].to_i
    )

    self.cli_regexp = params[:cli_regexp].to_s if params[:cli_tr_rule_type].to_i == 1
    self.op_source_transformation = params[:op_source_transformation].to_s if params[:cli_tr_rule_type].to_i == 2

    self.op_src_regexp = params[:op_src_regexp].to_s if params[:cli_allow_type].to_i == 1
    self.cli_number_pool_allow_id = params[:cli_number_pool_allow_id].to_s if params[:cli_allow_type].to_i == 2

    self.op_src_deny_regexp = params[:op_src_deny_regexp].to_s if params[:cli_deny_type].to_i == 1
    self.cli_number_pool_deny_id = params[:cli_number_pool_deny_id].to_s if params[:cli_deny_type].to_i == 2
  end

  def assign_auth_cld_settings(params)
    assign_attributes(
      cld_from_type: params[:cld_from_type].to_i,
      cld_tr_rule_type: params[:cld_tr_rule_type].to_i,
      cld_allow_type: params[:cld_allow_type].to_i,
      cld_deny_type: params[:cld_deny_type].to_i
    )

    self.cld_regexp = params[:cld_regexp].to_s if params[:cld_tr_rule_type].to_i == 1
    self.op_destination_transformation = params[:op_destination_transformation].to_s if params[:cld_tr_rule_type].to_i == 2

    self.cld_allow_regexp = params[:cld_allow_regexp].to_s if params[:cld_allow_type].to_i == 1
    self.cld_number_pool_allow_id = params[:cld_number_pool_allow_id].to_s if params[:cld_allow_type].to_i == 2

    self.cld_deny_regexp = params[:cld_deny_regexp].to_s if params[:cld_deny_type].to_i == 1
    self.cld_number_pool_deny_id = params[:cld_number_pool_deny_id].to_s if params[:cld_deny_type].to_i == 2
  end

  private

  def self.format_distribution(tp_calls)
    tp_calls.try(:each) do |tp_call|
      tp_call[:name] = nice_device(tp_call)
      tp_call[:free_lines] =
        if tp_call[:calls_limit].to_i > 0
          tp_call[:calls_limit] - tp_call[:total]
        else
          # Unlimited number
          tp_call[:calls_limit] = 4294967296
        end
    end
  end

  # ticket #5133
  def cid_number=(value)
    @cid_number = value
  end

  def Device.integrity_recheck_devices
    ccl_active = Confline.get_value('CCL_Active').to_i
    Device.where("(insecure = 'port,invite' OR insecure = 'port' OR insecure = 'invite') AND host = 'dynamic'").count > 0 and ccl_active == 0 ? 1 : 0
  end

  def t38pt_normalize
    if %w[fec redundancy none].include? self.t38pt_udptl
        self.t38pt_udptl = 'yes, ' << self.t38pt_udptl
    end
  end

  def chck_port
    port = 0 unless port
    save
  end

  def self.nice_device(device)
    return "#{device.description}" unless device.description.blank?
    "#{device.ip_address}"
  end

  def nice_device(device)
    nice_dev = device.device_type.to_s
    nice_dev <<  '/' + device.name.to_s if device.name and !nice_dev.include?(device.name.to_s)

    nice_dev
  end

  def nice_device_user(device)
    device_user = User.where(id: device.user_id).first
    dev_user = device_user.username.to_s
    dev_user = "#{device_user.first_name} #{device_user.last_name}" if device_user.first_name.to_s.length + device_user.last_name.to_s.length > 0
    dev_user
  end

  def validate_op_tp_settings
    if self.op.to_i == 1
      errors.add(:op_routing_group, _('op_no_available_routing_groups')) if self.op_routing_group_id.to_i == 0
      errors.add(:op_tariff, _('op_no_available_tariffs')) if self.op_tariff_id.to_i == 0
    end

    errors.add(:tp_tariff, _('tp_no_available_tariffs')) if self.tp_tariff_id.to_i == 0 if self.tp.to_i == 1 && self.tp_us_jurisdictional_routing.to_i == 0

    # PAI/RPID transformation regexp
    validate_pai_rpid_transformations
  end

  def admin?
    User.current && User.current.usertype == 'admin'
  end

  def manager?
    User.current && User.current.usertype == 'manager'
  end

  def strip_params
    self.tp_tech_prefix = tp_tech_prefix.to_s.strip
    self.tp_source_transformation = tp_source_transformation.to_s.strip
    self.op_source_transformation = op_source_transformation.to_s.strip
    self.op_destination_transformation = op_destination_transformation.to_s.strip
    self.op_src_regexp = op_src_regexp.to_s.strip
    self.op_src_deny_regexp = op_src_deny_regexp.to_s.strip
    self.tp_src_regexp = tp_src_regexp.to_s.strip
    self.tp_src_deny_regexp = tp_src_deny_regexp.to_s.strip
    self.tp_from_domain = tp_from_domain.to_s.strip
    self.op_pai_regexp = op_pai_regexp.to_s.strip
    self.op_rpid_regexp = op_rpid_regexp.to_s.strip
    self.tp_pai_regexp = tp_pai_regexp.to_s.strip
    self.tp_rpid_regexp = tp_rpid_regexp.to_s.strip
    self.cli_regexp = cli_regexp.to_s.strip
    self.cld_allow_regexp = cld_allow_regexp.to_s.strip
    self.cld_deny_regexp = cld_deny_regexp.to_s.strip
  end

  def validate_pai_rpid_transformations
    return unless Confline.get_value('M4_Functionality').to_i == 1
    regexp_array = []

    regexp_array.concat [op_pai_regexp, op_rpid_regexp] if op.to_i == 1
    regexp_array.concat [tp_pai_regexp, tp_rpid_regexp] if tp.to_i == 1

    titles = %w[PAI_Transformation RPID_Transformation]
    regexp_array.each_with_index do |regexp, index|
      splitted_regexp = regexp.to_s.split('/')
      next if splitted_regexp.size == 0

      regexp_valid = system("echo 'test' | sed -E 's#{regexp}'")
      unless regexp_valid
        errors.add(:device_regexp_error, "#{_(titles[index % 2])} - #{_('Invalid_regexp')}")
        next
      end
      errors.add(:device_regexp_error, "#{_(titles[index % 2])} - #{_('Invalid_regexp')}") if splitted_regexp.size >= 4 && %w[i g ig gi].exclude?(splitted_regexp.last)
    end
  end

  def validate_auth_domains
    validate_domain_from
    validate_domain_to
  end

  def validate_domain_from
    return if (domain_from_auth.to_s.count('*') == 1 && domain_from_auth.to_s.index('*') == 0) || domain_from_auth.to_s.exclude?('*')
    errors.add(:device_regexp_error, _('Ivalid_Check_From_Domain'))
  end

  def validate_domain_to
    return if (domain_to_auth.to_s.count('*') == 1 && domain_to_auth.to_s.index('*') == 0) || domain_to_auth.to_s.exclude?('*')
    errors.add(:device_regexp_error, _('Ivalid_Check_To_Domain'))
  end
end
