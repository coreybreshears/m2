# User model
class User < ActiveRecord::Base
  include SqlExport
  include UniversalHelpers
  include ElasticsearchQueries
  require 'digest/sha2'
  require 'uri'
  require 'net/http'

  attr_protected

  cattr_accessor :current
  cattr_accessor :current_user

  cattr_accessor :system_time_offset

  scope :first_owned_by, ->(id, owner_id) { where(id: id, owner_id: owner_id).first }

  has_many :devices, -> { includes([:user]).where("devices.accountcode != 0 and devices.name not like 'mor_server_%'") }
  has_many :sip_devices, -> { where("devices.accountcode != 0 and devices.name not like 'mor_server_%' AND device_type = 'SIP'") }, class_name: 'Device', foreign_key: 'user_id'
  has_many :actions
  has_many :user_documents
  belongs_to :tariff
  belongs_to :address
  has_many :m2_payments
  has_many :payments, -> { order('date_added DESC') }
  has_many :usergroups, dependent: :destroy
  belongs_to :tax, dependent: :destroy
  belongs_to :acc_group
  has_many :groups
  has_many :usergroups
  has_many :user_translations, -> { order('user_translations.position ASC') }, dependent: :destroy
  has_many :owned_tariffs, class_name: 'Tariff', foreign_key: :owner_id
  has_many :rate_notification_jobs, dependent: :destroy
  belongs_to :currency

  belongs_to :manager_group
  # warning balance sound
  has_many :cron_settings
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  belongs_to :responsible_accountant, class_name: 'User', foreign_key: 'responsible_accountant_id'
  has_many :two_factor_auths
  has_many :jqx_table_settings

  scope :is_user, -> {where(usertype: 'user')}
  scope :with_origination_points, -> {joins(:devices).where(devices: {op: 1})}
  scope :with_termination_points, -> {joins(:devices).where(devices: {tp: 1})}
  scope :alphabetized, -> {select("users.id, #{SqlExport.nice_user_sql}").order('nice_user ASC')}
  scope :group_by_user_id, -> {group('users.id')}

  validates_uniqueness_of :username, message: _('Username_has_already_been_taken')
  validates_presence_of :username, message: _('Username_cannot_be_blank')
  validates_numericality_of :invoice_grace_period, only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 365,
                            message: _('grace_period_must_be_integer_between_0_365'), allow_nil: true
  #validates :balance_min, :numericality => {:message => _('Minimal_balance_numerical'), :allow_blank => true}
  #validates :balance_max, :numericality => {:message => _('Maximal_balance_numerical'), :allow_blank => true}
  #validates_presence_of :first_name, :last_name

  before_save :user_before_save
  before_save :check_min_max_balance
  before_create :user_before_create
  before_create :new_user_balance, if: lambda {|user| not user.registration }

  after_create :after_create_localization, :after_create_user, :create_balance_payment, :user_data_changed
  after_save :after_create_localization, :check_address, :user_data_changed?
  after_destroy :destroy_automatic_cdr_exports, :user_data_changed

  attr_accessor :imported_user, :registration, :active_currency

  M2_EMAILS = [:main_email, :noc_email, :billing_email, :rates_email]


  def user_data_changed?
    user_data_changed if self.changed_attributes.present?
  end

  def user_data_changed
    changes_present_set_1
  end

  def changes_present_set_1
    update_column(:changes_present, 1) if persisted?
  end


  def after_create_localization
    #uses resellers id
    if usertype.to_s == 'reseller'
      create_reseller_conflines
      create_reseller_emails
    end
  end

  def after_create_user
    Action.add_action_hash(
      (User.current.try(:id) || self.get_correct_owner_id),
      {target_id: id, target_type: 'user', action: 'user_created'}
      )
  end

  def check_address
    unless address
      a = Address.create
      self.address_id = a.id
      self.save
    end
  end

  def create_balance_payment
    if self.balance.to_d != 0.to_d
      payment = M2Payment.create_for_user(
          self,
          {
              comment: 'Initial balance',
              currency_id: Currency.get_default.id,
              amount: read_attribute(:balance).to_d,
              amount_with_tax: read_attribute(:balance).to_d,
              user_balance_before: 0,
              user_balance_after: read_attribute(:balance).to_d
          }
      )
      payment.save
    end
  end

  def user_before_save
    # Only admin's user can have responsible_accountant_id set to some other value than -1
    # Invalid_value = (responsible_accountant_id != -1 and (not is_user? or owner_id != 0))
    if (self.try(:responsible_accountant_id).to_i != -1) && !User.where(usertype: 'manager', hidden: 0, id: self.try(:responsible_accountant_id)).first
      errors.add(:email, _('Manager_is_invalid'))
      return false
    end

    if Confline.get_value('M4_Functionality').to_i == 1 && Confline.get_value('2FA_Enabled').to_i == 1  && two_fa_enabled? && main_email.blank?
      errors.add(:email, _('To_enable_2FA_main_email_must_be_present'))
      return false
    end
    self.uniquehash = ApplicationController::random_password(10) if self.uniquehash.to_s.blank?
  end

  def user_before_create
    if password == Digest::SHA1.hexdigest('')
      errors.add(:password, _('Please_enter_password'))
      return false
    end

    if password == Digest::SHA1.hexdigest(username) and !self.imported_user
      errors.add(:password, _('Please_enter_password_not_equal_to_username'))
      return false
    end
  end

  def default_translation
    if is_admin? or is_reseller?
      trans = user_translations.includes([:translation]).where('user_translations.active = 1').
        order('user_translations.position ASC').first

      if trans
        trans.translation
      else
        owner.default_translation
      end
    else
      owner.default_translation
    end
  end

  def active_translations
    if is_admin? or is_reseller?
      trans = user_translations.includes([:translation]).where('user_translations.active = 1').
        order('user_translations.position ASC').all

      unless trans and trans.size != 0
        owner.active_translations
      else
        trans.collect(&:translation)
      end
    else
      owner.active_translations
    end
  end

  def all_translations
    if is_admin? || is_reseller?
      trans = user_translations.includes([:translation]).all
      unless trans && trans.size != 0
        owner.active_translations.collect(&:translation)
      else
        trans.collect(&:translation)
      end
    else
      owner.active_translations.collect(&:translation)
    end
  end

  def load_user_translations
    ut = user_translations
    unless ut && ut.size != 0
      clone_owner_translations
      return user_translations(true)
    end
    ut
  end

  def clone_owner_translations
    UserTranslation.where(user_id: owner_id).all.each do |ut|
      UserTranslation.create(user_id: id, translation_id: ut.translation_id, position: ut.position, active: ut.active)
    end
  end

  def hide_destination_end
    if attributes['hide_destination_end'] == -1
      Confline.get_value('Hide_Destination_End', owner_id).to_i
    else
      attributes['hide_destination_end']
    end
  end
=begin
  Check whether user is admin type, only one user can be system admin,
  valid admin user has to got id = 0 and his usertype has to be set to 'admin'

  *Returns*
  +boolean+ - true if user is admin, otherwise false
=end
  def is_admin?
    (usertype == 'admin') && (id == 0)
  end

  def is_manager?
    usertype == 'manager'
  end

  def is_accountant?
    usertype == 'accountant'
  end

  def is_reseller?
    usertype == 'reseller'
  end

  def is_user?
    usertype == 'user'
  end

  def reseller_users
    User.select("*, #{SqlExport.nice_user_sql}").where("owner_id = #{id}").order('nice_user ASC').all
  end

  # def owner
  #  @attributes["owner"] ||= User.find(:first, :conditions => ["id = ?", owner_id])
  # end

  # def owner= (owner)
  #  @attributes["owner"] = owner
  # end

  def all_calls
    Call.where(user_id: id)
  end

  def calls_or_calls_in_aggregates_present
    Call.where(user_id: id).present? || OldCall.where(user_id: id).present? ||
    Aggregate.where(op_user_id: id).present? || Call.where(provider_id: id).limit(1).present?
  end

  # retrieve calls for user
  #
  # available call types:
  #
  # all
  # answered
  # busy
  # no answer
  # failed
  # missed
  # missed_inc
  # missed_inc_all
  # missed_not_processed_inc
  #
  # directions: incoming/outgoing
  # *Params*
  #
  # *<tt>options[:limit]</tt> - number of values to be returned.
  # *<tt>options[:offset]</tt> - return starts from this possition.

  def calls(type, date_from, date_till, direction = 'outgoing', order_by = 'calldate', order = 'DESC', device = nil, options = {})
    calls = []
    # ------ handle call type --------
    call_type_sql = (type == 'all') ? '' : " AND disposition = '#{type}' "

    # special case
    if type[0..5] == 'missed'
      call_type_sql = " AND disposition != 'ANSWERED'"

      if type[7..19] == 'not_processed'
        call_type_sql += ' AND processed = 0 '
      end

    end

    # ---------- handle device ---------
    device_sql = ''

    if device
      device_sql = (direction == 'incoming') ? " AND dst_device_id = #{device.id} " : " AND src_device_id = #{device.id} "
    end

    # ---------- handle Hangupcausecode ---------
    hgc_sql = options[:hgc] ? " AND calls.hangupcause = #{options[:hgc].code} " : ''

    # -------- handle resellers ---------
    reseller_sql = ''

    find = ['calls.*']
    find << "DATE_FORMAT(calldate, \"%Y-%m-%d %H:%i:%S\") as `formated_calldate`" if options[:format_calldate]
    from = []

    if options[:destinations] == true
      find << "destinations.name AS 'destination_name'"
      find << "directions.name AS 'direction_name'"

      from << "LEFT JOIN destinations ON (destinations.prefix = calls.prefix)"
      from << "LEFT JOIN directions ON (directions.code = destinations.direction_code)"
    end
    if options[:count] == true
      find = ["COUNT(*) AS 'total_count'"]
    end
    # -------- retrieve calls -----------
    sql = "SELECT #{find.join(',')} FROM calls #{from.join(' ')} WHERE ((calls.user_id = #{id} #{reseller_sql}) #{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}'))) ORDER BY #{order_by} #{order} #{ 'LIMIT ' + options[:offset].to_s + ', ' + options[:limit].to_s if (options[:limit] and options[:offset]) };"
    Call.find_by_sql(sql)
  end

  # Similar to @user.calls. Instead it returns total number of calls and sum of basic calls params.
  def calls_total_stats(type, date_from, date_till, direction = 'outgoing', device = nil, usertype = "user", hgc =nil)
    calls = []

    # ------ handle call type --------
    call_type_sql = (type == 'all') ? '' : " AND disposition = '#{type}' "

    # special case
    if type[0..5] == 'missed'
      call_type_sql = " AND disposition != 'ANSWERED'"

      if type[7..19] == 'not_processed'
        call_type_sql += " AND processed = 0 "
      end
    end

    # ---------- handle device ---------
    device_sql = ''

    if device
      device_sql = (direction == 'incoming') ? " AND dst_device_id = #{device.id} " : " AND src_device_id = #{device.id} "
    end

    # ---------- handle Hangupcausecode ---------
    hgc_sql = hgc ? " AND hangupcause = #{hgc.code} " : ''

    # -------- handle resellers ---------
    reseller_sql = ''

    # -------- retrieve calls -----------
      # outgoing calls
      # SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.reseller_price')}, 0)) AS 'total_reseller_price'
      calls = Call.find_by_sql("SELECT
          COUNT(*) AS 'total_calls',
          SUM(IF(calls.disposition = 'ANSWERED', 1, 0)) AS 'total_answered_calls',
          SUM(IF(calls.disposition = 'ANSWERED',calls.duration, 0)) AS 'total_duration',
          SUM(IF(calls.billsec > 0,calls.billsec, CEIL(calls.real_billsec) )) AS 'total_billsec',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.user_price')}, 0)) AS 'total_user_price',
          SUM(IF(calls.disposition = 'ANSWERED',#{SqlExport.replace_price('calls.provider_price')}, 0)) AS 'total_provider_price'
          FROM calls WHERE ((calls.user_id = #{id} #{reseller_sql}) #{call_type_sql} #{device_sql} #{hgc_sql} AND ((calldate BETWEEN '#{date_from.to_s}' AND '#{date_till.to_s}')));")
    calls[0]
  end

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

  def total_calls(type, date_from, date_till)
    t_calls = 0
    devices.each { |dev| t_calls += dev.total_calls(type, date_from, date_till) }

    t_calls
  end

  def total_duration(type, date_from, date_till)
    t_duration = 0
    devices.each { |dev| t_duration += dev.total_duration(type, date_from, date_till) }

    t_duration
  end

  def total_billsec(type, date_from, date_till)
    t_billsec = 0
    devices.each { |dev| t_billsec += dev.total_billsec(type, date_from, date_till) }

    t_billsec
  end

  def last_login
    Action.where(user_id: id, action: 'login').order('date DESC').first
  end

  def destroy_everything
    conflines = Confline.where(["owner_id = '#{id}'"]).all

    conflines.each { |conf| conf.destroy }

    devices.each { |dev| dev.destroy_everything }

    address.destroy if address
    destroy
  end

  def email(options = {})
    address_email = m2_emails
    return '' if address_email.blank?

    address_email = address_email.first.first.to_s
    address_email = address_email.split(';')[0] if options[:first_possible]
    address_email = address_email.to_s.gsub(',', ';').split(';') if options[:array]

    address_email
  end

  # create conflines to user, if conflines exist they will be set to admin values
  def create_reseller_conflines
    if usertype == 'reseller' and Confline.get_value('Default_device_type', id).to_s.blank?
      create_reseller_default_device
      create_reseller_CSV_params
      create_reseler_emails
    end
  end

  def create_reseller_default_device
    Confline.delete_all("owner_id = #{id} AND name like 'Default_device%'")
    Confline.new_confline('Show_Rates_Without_Tax', 0, id)

    %w[Company Company_Email Version Copyright_Title Admin_Browser_Title Logo_Picture].each { |name|
        Confline.new_confline(name, Confline.get_value(name), id)
      }

    %w[Default_device_type Default_device_dtmfmode Default_device_works_not_logged Default_device_timeout
      Default_device_record Default_device_call_limit Default_device_nat Default_device_trustrpid
      Default_device_sendrpid Default_device_t38pt_udptl Default_device_promiscredir Default_device_progressinband
      Default_device_videosupport Default_device_tell_balance Default_device_tell_time
      Default_device_tell_rtime_when_left Default_device_repeat_rtime_every Default_device_permits
      Default_device_qualify Default_device_host Default_device_ipaddr Default_device_port Default_device_regseconds
      Default_device_canreinvite Default_device_istrunk Default_device_ani Default_device_callgroup
      Default_device_pickupgroup Default_device_fromuser Default_device_fromdomain Default_device_insecure
      Default_setting_device_caller_id_number Default_device_cid_name Default_device_cid_number].each { |name|
        Confline.new_confline(name, Confline.get_value(name, 0), id)
      }

    Codec.all.each do |codec|
      name = "Default_device_codec_#{codec.name}"
      Confline.new_confline(name, Confline.get_value(name, 0), id)
    end
  end

  def create_reseller_CSV_params
    %w[CSV_Separator CSV_Decimal].each { |name| Confline.new_confline(name, Confline.get_value(name, 0), id) }
  end

  def create_reseler_emails
    %w[Email_Batch_Size Email_Smtp_Server Email_Domain Email_Login Email_Password Email_port].each { |name|
      Confline.new_confline(name, Confline.get_value(name, 0), id)
    }

    %w[Email_Login Email_Password].each { |name| Confline.set_value2(name, 1, id) }
  end

  def User.exists_resellers_confline_settings(id)
    con = Confline.where("name = 'Email_Login' AND owner_id = #{id}").first
    reseller = User.where(id: id).first

    unless con
      reseller.create_reseler_emails
    else
      reseller.check_reseller_emails
    end
  end

  def create_reseller_emails
    emails = Email.select('emails.*')
                  .joins("LEFT JOIN (select * from emails where owner_id = #{id} and template =1) as b ON (b.name = emails.name)")
                  .where("emails.owner_id = 0 AND emails.template = 1 AND b.id IS NULL AND emails.name != 'warning_balance_email_local'").all

    emails.each do |email|
      Email.create(
        name: email.name,
        subject: email.subject,
        body: email.body,
        template: 1,
        date_created: Time.now.to_s,
        owner_id: id
      )
    end
  end

  def check_reseller_emails
    con = Confline.where(["name = 'Email_From' and owner_id=?", id]).first

    if con
      con.name = 'Email_from'
      con.save
    end

    emails = Email.select('emails.*')
                  .joins("LEFT JOIN (select * from emails where owner_id = #{id} and template =1) as b ON (b.name = emails.name)")
                  .where("emails.owner_id = 0 AND emails.template = 1 AND b.id IS NULL AND emails.name != 'warning_balance_email_local'").all

    emails.each do |email|
      MorLog.my_debug("FIXING RESELLER EMAILS: #{id} Email not found: #{email.id}")
      Email.create(
        name: email.name,
        subject: email.subject,
        body: email.body,
        template:1,
        date_created: Time.now.to_s,
        owner_id: id
      )
    end
  end

  def check_default_user_conflines
    if is_reseller?
      conflines = Confline.where("name LIKE 'Default_device%' AND owner_id = 0").all
      conflines.each do |confline|
        if not Confline.where("name = '#{confline.name}' AND owner_id = #{id}").first
          Confline.new_confline(confline.name, confline.value, id)
        end
      end
    end
  end

  def User::get_hash(user_id)
    user = User.find(user_id.to_i)
    return user.uniquehash if user and user.uniquehash and user.uniquehash.length > 0
    user.uniquehash = ApplicationController::random_password(10)
    user.save
    return user.uniquehash
  end

  # Returns user hash. If user has no hash yet generates new one and returns it.
  def get_hash
    return(uniquehash) if (uniquehash and uniquehash.length > 0)
    uniquehash = ApplicationController::random_password(10)
    self.save
    return uniquehash
  end

  #debug
  #put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, 'a') do |f|
      f << msg.to_s
      f << "\n"
    end
  end

  def get_owner()
    User.find(owner_id)
  end

  def primary_device
    Device.where(id: primary_device_id).first
  end

  def quick_stats(current_month, last_day, current_day, current_user_id = id)
    month_calls, month_billsec, month_selfcost = 0, 0, 0
    day_calls, day_billsec, day_selfcost = 0, 0, 0
    calls_for_24hours, billsec_for_24hours, selfcost_for_24hours = 0, 0, 0
    calls_for_14days, billsec_for_14days, selfcost_for_14days = 0, 0, 0
    calls_for_6months, billsec_for_6months, selfcost_for_6months = 0, 0, 0

    month_from = current_month + '-01 00:00:00'
    month_till = current_month + "-#{last_day} 23:59:59"

    day_from = current_day + ' 00:00:00'
    day_till = current_day + ' 23:59:59'

    detailed = Confline.get_value('Show_detailed_quick_stats').to_i == 1

    es_month = {from: system_time(month_from).split.join('T'), till: system_time(month_till).split.join('T')}
    es_day = {from: system_time(day_from).split.join('T'), till: system_time(day_till).split.join('T')}
    if detailed
      es_24_hours = {from: system_time(Time.now - 1.day).split.join('T'), till: system_time(Time.now).split.join('T')}
      es_14_days = {from: system_time(Time.now - 14.days).split.join('T'), till: system_time(Time.now).split.join('T')}
      es_6_months = {from: system_time(Time.now - 6.months).split.join('T'), till: system_time(Time.now).split.join('T')}
    end

    if is_admin? || is_manager?
      day_calls, day_billsec, day_selfcost, day_revenue, day_profit, day_margin = es_admin_quick_stats(es_day)
      month_calls, month_billsec, month_selfcost, month_revenue, month_profit, month_margin = es_admin_quick_stats(es_month)
      if detailed
        calls_for_24hours, billsec_for_24hours, selfcost_for_24hours, revenue_for_24hours, profit_for_24hours,
        margin_for_24hours = es_admin_quick_stats(es_24_hours)
        calls_for_14days, billsec_for_14days, selfcost_for_14days, revenue_for_14days, profit_for_14days,
        margin_for_14days = es_admin_quick_stats(es_14_days)
        calls_for_6months, billsec_for_6months, selfcost_for_6months, revenue_for_6months, profit_for_6months,
        margin_for_6months = es_admin_quick_stats(es_6_months)
      end
    else
      show_user_billsec = (Confline.get_value('Invoice_user_billsec_show', owner.id).to_i == 1) && (is_user?)
      day_calls, day_billsec, day_revenue = es_user_quick_stats(es_day, current_user_id, show_user_billsec)
      month_calls, month_billsec, month_revenue = es_user_quick_stats(es_month, current_user_id, show_user_billsec)
      if detailed
        calls_for_24hours, billsec_for_24hours, revenue_for_24hours = es_user_quick_stats(es_24_hours, current_user_id, show_user_billsec)
        calls_for_14days, billsec_for_14days, revenue_for_14days = es_user_quick_stats(es_14_days, current_user_id, show_user_billsec)
        calls_for_6months, billsec_for_6months, revenue_for_6months = es_user_quick_stats(es_6_months, current_user_id, show_user_billsec)
      end
    end
    if detailed
      values = [
        day_calls, day_billsec, day_selfcost, day_revenue, day_profit, day_margin,
        month_calls, month_billsec, month_selfcost, month_revenue, month_profit, month_margin,
        calls_for_24hours, billsec_for_24hours, selfcost_for_24hours, revenue_for_24hours, profit_for_24hours,
        margin_for_24hours, calls_for_14days, billsec_for_14days, selfcost_for_14days, revenue_for_14days,
        profit_for_14days, margin_for_14days, calls_for_6months, billsec_for_6months, selfcost_for_6months,
        revenue_for_6months, profit_for_6months, margin_for_6months
      ]
    else
      values = [
        day_calls, day_billsec, day_selfcost, day_revenue, day_profit, day_margin,
        month_calls, month_billsec, month_selfcost, month_revenue, month_profit, month_margin
      ]
    end
    return values
  end

  # finds total outgoing calls made by this user and price for these calls in period
  # period is in string format date-time
  def own_outgoing_calls_stats_in_period(period_start, period_end, calldate_index = 0)
    total_calls = 0
    calls_price = 0
    zero_calls_sql = invoice_zero_calls_sql
    up = SqlExport.user_price_sql

    val = ActiveRecord::Base.connection.select_all("SELECT count(calls.id) as calls, SUM(#{up}) as price FROM calls WHERE disposition = 'ANSWERED' and calls.user_id = #{id} AND calldate BETWEEN '#{period_start}' AND '#{period_end}' #{zero_calls_sql};")

    if val
      total_calls += val[0]['calls'].to_i
      calls_price += val[0]['price'].to_d
    end

    [total_calls.to_i, calls_price.to_d]
  end

  # gets parameters for CSV file
  def csv_params
    owner_id = owner_id
    owner_id = id if usertype == 'reseller'
    sep = Confline.get_value('CSV_Separator', owner_id).to_s
    dec = Confline.get_value('CSV_Decimal', owner_id).to_s

    sep = Confline.get_value('CSV_Separator', 0).to_s if sep.to_s.length == 0
    dec = Confline.get_value('CSV_Decimal', 0).to_s if dec.to_s.length == 0

    sep = ',' if sep.blank?
    dec = '.' if dec.blank?

    return sep, dec
  end

  def create_default_device(options = {})
    owner_id = self.owner_id
    device = devices.new({context: 'mor_local', device_type: options[:device_type].to_s, pin: options[:pin].to_s, secret: options[:secret].to_s})
    device.callerid = options[:callerid].to_s if options[:callerid]
    device.description = options[:description] if options[:description]
    device.device_ip_authentication_record = options[:device_ip_authentication_record] if options[:device_ip_authentication_record]
    device.username = '' # options[:username] ? options[:username] : fextension

    device.name = device.generate_rand_name('ipauth', 8)
    # device.name = options[:username] ? options[:username] : fextension

    device.dtmfmode = Confline.get_value('Default_device_dtmfmode', owner_id).to_s
    device.works_not_logged = Confline.get_value('Default_device_works_not_logged', owner_id).to_i

    after_create_localization
    device.timeout = Confline.get_value('Default_device_timeout', owner_id)

    device.call_limit = Confline.get_value('Default_device_call_limit', owner_id)

    device.nat = Confline.get_value('Default_device_nat', owner_id).to_s

    device.trustrpid = Confline.get_value('Default_device_trustrpid', owner_id).to_s
    device.sendrpid = Confline.get_value('Default_device_sendrpid', owner_id).to_s
    device.t38pt_udptl = Confline.get_value('Default_device_t38pt_udptl', owner_id).to_s
    device.promiscredir = Confline.get_value('Default_device_promiscredir', owner_id).to_s
    device.promiscredir = 'no' if device.promiscredir.to_s != 'yes' and device.promiscredir.to_s != 'no'
    device.progressinband = Confline.get_value('Default_device_progressinband', owner_id).to_s
    device.videosupport = Confline.get_value('Default_device_videosupport', owner_id).to_s
    device.tell_rate = Confline.get_value('Default_device_tell_rate', owner_id).to_i
    device.tell_balance = Confline.get_value('Default_device_tell_balance', owner_id).to_i
    device.tell_time = Confline.get_value('Default_device_tell_time', owner_id).to_i
    device.tell_rtime_when_left = Confline.get_value('Default_device_tell_rtime_when_left', owner_id).to_i
    device.repeat_rtime_every = Confline.get_value('Default_device_repeat_rtime_every', owner_id).to_i
    device.grace_time = Confline.get_value('Default_device_grace_time', owner_id).to_i

    device.permit = Confline.get_value('Default_device_permits', owner_id).to_s
    device.qualify = Confline.get_value('Default_device_qualify', owner_id)

    default_device_disable_q850 = Confline.get_value('Default_device_disable_q850', owner_id)
    device.disable_q850 = default_device_disable_q850.present? ? default_device_disable_q850 : 0

    default_device_forward_rpid = Confline.get_value('Default_device_forward_rpid', owner_id)
    device.forward_rpid = default_device_forward_rpid.present? ? default_device_forward_rpid : 1

    default_device_forward_pai = Confline.get_value('Default_device_forward_pai', owner_id)
    device.forward_pai = default_device_forward_pai.present? ? default_device_forward_pai : 1

    default_device_bypass_media = Confline.get_value('Default_device_bypass_media', owner_id)
    device.bypass_media = default_device_bypass_media.present? ? default_device_bypass_media : 0

    default_device_disable_sip_uri_encoding = Confline.get_value('Default_device_disable_sip_uri_encoding', owner_id)
    device.disable_sip_uri_encoding = default_device_disable_sip_uri_encoding.present? ? default_device_disable_sip_uri_encoding : 1

    default_device_ignore_183nosdp = Confline.get_value('Default_device_ignore_183nosdp', owner_id)
    device.ignore_183nosdp = default_device_ignore_183nosdp.present? ? default_device_ignore_183nosdp : 0

    default_device_tp_ignore_183nosdp = Confline.get_value('Default_device_tp_ignore_183nosdp', owner_id)
    device.tp_ignore_183nosdp = default_device_tp_ignore_183nosdp.present? ? default_device_tp_ignore_183nosdp : 0

    default_device_op_ignore_180_after_183 = Confline.get_value('Default_device_op_ignore_180_after_183', owner_id)
    device.op_ignore_180_after_183 = default_device_op_ignore_180_after_183.present? ? default_device_op_ignore_180_after_183 : 0

    default_device_op_allow_own_tps = Confline.get_value('Default_device_op_allow_own_tps', owner_id)
    device.op_allow_own_tps = default_device_op_allow_own_tps.present? ? default_device_op_allow_own_tps : 0

    default_device_tp_ignore_180_after_183 = Confline.get_value('Default_device_tp_ignore_180_after_183', owner_id)
    device.tp_ignore_180_after_183 = default_device_tp_ignore_180_after_183.present? ? default_device_tp_ignore_180_after_183 : 0

    default_device_use_invite_dst = Confline.get_value('Default_device_use_invite_dst', owner_id)
    device.use_invite_dst = default_device_use_invite_dst.present? ? default_device_use_invite_dst : 0

    default_device_inherit_codec = Confline.get_value('Default_device_inherit_codec', owner_id)
    device.inherit_codec = default_device_inherit_codec.present? ? default_device_inherit_codec : 0

    default_device_enforce_lega_codecs = Confline.get_value('Default_device_enforce_lega_codecs', owner_id)
    device.enforce_lega_codecs = default_device_enforce_lega_codecs.present? ? default_device_enforce_lega_codecs : 0

    default_device_set_sip_contact = Confline.get_value('Default_device_set_sip_contact', owner_id)
    device.set_sip_contact = default_device_set_sip_contact.present? ? default_device_set_sip_contact : 0

    op_use_pai_number_for_routing = Confline.get_value('Default_device_op_use_pai_number_for_routing', owner_id)
    device.op_use_pai_number_for_routing = op_use_pai_number_for_routing if op_use_pai_number_for_routing.present?

    op_send_pai_number_as_caller_id_to_tp = Confline.get_value('Default_device_op_send_pai_number_as_caller_id_to_tp', owner_id)
    device.op_send_pai_number_as_caller_id_to_tp = op_send_pai_number_as_caller_id_to_tp if op_send_pai_number_as_caller_id_to_tp.present?

    device.host = options[:ipaddr].to_s.strip
    device.ipaddr = options[:ipaddr].to_s.strip

    device.port = device.ipaddr.present? ? Confline.get_value('Default_device_port', owner_id).to_i : nil

    device.regseconds = Confline.get_value('Default_device_regseconds', owner_id).to_i
    device.canreinvite = Confline.get_value('Default_device_canreinvite', owner_id).to_s
    device.transfer = Confline.get_value('Default_device_canreinvite', owner_id).to_s
    device.istrunk = Confline.get_value('Default_device_istrunk', owner_id).to_i
    device.ani = Confline.get_value('Default_device_ani', owner_id).to_i
    device.callgroup = Confline.get_value('Default_device_callgroup', owner_id).to_s.blank? ? nil : Confline.get_value('Default_device_callgroup', owner_id).to_i

    device.pickupgroup = Confline.get_value('Default_device_pickupgroup', owner_id).to_s.blank? ? nil : Confline.get_value('Default_device_pickupgroup', owner_id).to_i
    device.fromuser = Confline.get_value('Default_device_fromuser', owner_id).to_s
    device.custom_sip_header = Confline.get_value('Default_device_custom_sip_header', owner_id).to_s

    device.transport = Confline.get_value('Default_device_transport', owner_id).to_s
    device.transport = 'udp' if !['tcp', 'udp', 'tcp,udp', 'udp,tcp', 'tls'].include?(device.transport)
    device.fromdomain = Confline.get_value('Default_device_fromdomain', owner_id).to_s
    device_insecurity = Confline.get_value('Default_device_insecure', owner_id).to_s
    device.insecure = device_insecurity.blank? ? 'no' : device_insecurity
    device.enable_mwi = Confline.get_value('Default_device_enable_mwi', owner_id).to_i
    device.encryption = Confline.get_value('Default_device_encryption', owner_id)
    device.block_callerid = Confline.get_value('Default_device_block_callerid', owner_id).to_i
    device.max_timeout = Confline.get_value('Default_device_max_timeout', owner_id).to_i
    device.progress_timeout = Confline.get_value('Default_device_progress_timeout', owner_id).to_i
    device.language = Confline.get_value('Default_device_language', owner_id).to_s
    if not device.works_not_logged
      device.works_not_logged = 1
    end

    if options[:op].to_i == 1
      device.op = 1
      device.op_active = 1
      device.op_routing_group_id = RoutingGroup.order('name ASC').all.first.try(:id)
      device.op_tariff_id = Tariff.where(purpose: 'user_wholesale').order('name ASC').all.first.try(:id)

      if options[:create_rg_for_op].to_i == 1
        new_routing_group = RoutingGroup.create(name: "RG - #{device.user.username} - [tmp]")
        device.op_routing_group_id = new_routing_group.id
      end
      if Confline.get_value('M4_Functionality').to_i == 1
        device.op_pai_regexp = Confline.get_value('Default_device_op_pai_regexp', owner_id)
        device.op_rpid_regexp = Confline.get_value('Default_device_op_rpid_regexp', owner_id)
      end
    end

    if options[:tp].to_i == 1
      device.tp = 1
      device.tp_active = 1
      device.tp_tariff_id = Tariff.where(purpose: 'provider').order('name ASC').all.first.try(:id)
      if Confline.get_value('M4_Functionality').to_i == 1
        device.tp_pai_regexp = Confline.get_value('Default_device_tp_pai_regexp', owner_id)
        device.tp_rpid_regexp = Confline.get_value('Default_device_tp_rpid_regexp', owner_id)
      end
    end

    if ['SIP'].include? options[:device_type].to_s
      device.cps_call_limit = Confline.get_value('Default_device_cps_call_limit', owner_id).to_i
      device.cps_period = Confline.get_value('Default_device_cps_period', owner_id).to_i
    end

    device.control_callerid_by_cids = Confline.get_value('Default_setting_device_caller_id_number', owner_id).to_i == 4 ? 1 : 0
    device.callerid_advanced_control = Confline.get_value('Default_setting_device_caller_id_number', owner_id).to_i == 5 ? 1 : 0
    if device.save
      #device.accountcode = device.id
      #device.save(false)

      server_devices = Confline.where(name: 'Default_device_server', owner_id: get_correct_owner_id).pluck(:value).map(&:to_i)
      server_devices = server_devices.product([1])
      device.create_server_devices(server_devices)

      device.update_cid(Confline.get_value('Default_device_cid_name', owner_id), Confline.get_value('Default_device_cid_number', owner_id), false) unless device.callerid
      primary_device_id = device.id
      # configure_extensions(device.id)
      if options[:op].to_i == 1 && options[:create_rg_for_op].to_i == 1
        new_routing_group.update_attribute(:name, "RG - #{device.user.username} - #{device.id}")
      end
    else
      if options[:op].to_i == 1 && options[:create_rg_for_op].to_i == 1
        new_routing_group.try(:delete)
      end
    end
    return device

  end

  def assign_default_tax(taxs = {}, opt = {})
    options = {
        save: true
    }.merge(opt)
    if !taxs or taxs == {}
      if owner_id == 0
        new_tax = Confline.get_default_tax(0)
      else
        new_tax = User.where(id: owner_id).first.get_tax.dup
      end
    else
      new_tax = Tax.new(taxs)
    end
    new_tax.save if options[:save] == true
    self.tax_id = new_tax.id
    self.tax = new_tax
    self.save if options[:save] == true
  end

  def assign_default_tax2
    owner = owner_id
    tax = {
        tax1_enabled: 1,
        tax2_enabled: Confline.get_value2('Tax_2', owner).to_i,
        tax3_enabled: Confline.get_value2('Tax_3', owner).to_i,
        tax4_enabled: Confline.get_value2('Tax_4', owner).to_i,
        tax1_name: Confline.get_value('Tax_1', owner),
        tax2_name: Confline.get_value('Tax_2', owner),
        tax3_name: Confline.get_value('Tax_3', owner),
        tax4_name: Confline.get_value('Tax_4', owner),
        total_tax_name: Confline.get_value('Total_tax_name', owner),
        tax1_value: Confline.get_value('Tax_1_Value', owner).to_d,
        tax2_value: Confline.get_value('Tax_2_Value', owner).to_d,
        tax3_value: Confline.get_value('Tax_3_Value', owner).to_d,
        tax4_value: Confline.get_value('Tax_4_Value', owner).to_d,
        compound_tax: Confline.get_value('Tax_compound', owner).to_i
    }

    tax[:total_tax_name] = 'TAX' if tax[:total_tax_name].blank?
    tax[:tax1_name] = tax[:total_tax_name].to_s if tax[:tax1_name].blank?
    assign_default_tax(tax, {save: true})
  end

  def random_digit_password(size = 8)
    chars = ((0..9).to_a)
    (1..size).collect { |char| chars[rand(chars.size)] }.join
  end

  def get_tax
    self.assign_default_tax if tax.blank?
    self.tax
  end

  def get_tax_value
    user_tax = self.get_tax
    tax = 1
    if user_tax.compound_tax == 1
      for index in 1..4
        tax = tax * (1 + eval("user_tax.tax#{index}_value") / 100) if eval("user_tax.tax#{index}_enabled") == 1
      end
    else
      tax_multiplier = 0
      for index in 1..4
        tax_multiplier += eval("user_tax.tax#{index}_value") if eval("user_tax.tax#{index}_enabled") == 1
      end
      tax = tax + (tax_multiplier / 100)
    end
    tax
  end

  def user_type
    postpaid == 1 ? 'postpaid' : 'prepaid'
  end

  def user_calls_to_csv(options = {})
    sep, dec = csv_params

    disposition = []
    disposition << " calls.user_id = #{id}"
    disposition << " calls.src_device_id = #{options[:device].id} " if options[:device]

    disposition << " disposition = '#{options[:call_type]}' " if options[:call_type] != 'all'
    disposition << " calls.hangupcause = #{options[:hgc].code} " if options[:hgc]
    disposition << " calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}'"

    default_currency = options[:default_currency]
    show_currency = options[:show_currency]
    if default_currency != show_currency
      curr3er = Currency.select("exchange_rate as 'ex'").where("name = '#{show_currency}'").first
    end

    #fm1 = " ROUND("
    #fm2 =" ,#{options[:nice_number_digits]}) "

    r1 = dec == '.' ? '' : "replace("
    r2 = dec == '.' ? '' : ", '.', '#{dec}')"
    n1 = "#{r1}"
    n2 = "#{r2}"
    c1 = default_currency != show_currency ? " * #{curr3er.ex.to_d} " : ""

    select = []
    select2 = []
    headers = []
    format = Confline.get_value('Date_format', owner_id).gsub('M', 'i')
    headers << "'#{_('Date')}'" + ' AS calldate'
    headers << "'#{_('Called_from')}'" + ' AS src'
    headers << "'#{_('Called_to')}'" + ' AS dst'
    headers << "'#{_('Direction')}'" + ' AS direction'
    headers << "'#{_('Duration')}'" + ' AS duration'
    headers << "'#{_('hangup_cause')}'" + ' AS disposition'
    select2 << SqlExport.nice_date('calldate', {reference: 'calldate', format: format, tz: options[:tx]})
    select2 << 'src, dst, direction'
    select2 << 'duration, disposition'

    select << 'calls.calldate'
    select << "IF(#{options[:show_full_src].to_i} = 1 AND CHAR_LENGTH(clid)>0 AND clid REGEXP'\"' , CONCAT(src, '  ' ,REPLACE(SUBSTRING_INDEX(clid, '\"', 2), '\"', '('), ')'), src) as 'src'"

    options[:usertype] == 'user' ? select << SqlExport.hide_dst_for_user_sql(self, 'csv', 'calls.dst', {as: 'dst'}) : select << 'calls.dst'

    select << "CONCAT(IF(directions.name IS NULL, '',directions.name), ' ', IF(destinations.name IS NULL, '',destinations.name)) as 'direction'"
    select << "IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) ) as 'duration'"
    select << "calls.disposition"
    headers << "'#{_('User_price')}'" + ' AS user_price3'
    select2 << SqlExport.replace_price("#{n1}user_price3#{n2}", {reference: 'user_price3'})
    select << "#{n1} calls.user_price #{c1} #{n2} as 'user_price3'" if options[:usertype] != 'admin'
    if options[:usertype] == 'admin'
      headers << "'#{_('Provider_price')}'" + ' AS provider_price3'
      headers << "'#{_('Profit')}'" + ' AS profit'
      select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {reference: 'provider_price3'})
      select2 << SqlExport.replace_price("#{n1}(user_price3-provider_price3)#{n2}", {reference: 'profit'})
      # "IF(calls.reseller_id > 0, calls.reseller_price#{c1} , calls.user_price#{c1}) as 'user_price3'"
      select << "calls.user_price#{c1} as 'user_price3'"
      select << "IF(calls.provider_price IS NOT NULL, calls.provider_price#{c1}, 0) as 'provider_price3'"
    end
    # if options[:usertype] == 'reseller'
    #   headers << "'#{_('Provider_price')}'" + ' AS provider_price3'
    #   select2 << SqlExport.replace_price("#{n1}provider_price3#{n2}", {reference: 'provider_price3'})
    #   select << "IF(calls.reseller_id = 0, calls.user_price#{c1}, calls.reseller_price#{c1}) as 'provider_price3'"
    #   headers << "'#{_('Profit')}'" + ' AS profit'
    #   select2 << SqlExport.replace_price("#{n1}(user_price3-provider_price3)#{n2}", {reference: 'profit'})
    # end
    if options[:usertype] != 'user'
      headers << "'#{_('Margin')}'" + ' AS m1'
      headers << "'#{_('Markup')}'" + ' AS m2'
      select2 << "IF( (((user_price3-provider_price3) / user_price3 ) *100) IS NULL, 0,  #{n1}(((user_price3-provider_price3) / user_price3 ) *100) #{n2}) as 'm1'"
      select2 << "IF(( ((user_price3 / provider_price3) *100)-100 ) IS NULL, 0 ,   #{n1}( ((user_price3 / provider_price3) *100)-100 )#{n2}) as 'm2'"
    end
    if options[:usertype] == 'admin'
      select << "calls.originator_ip as 'oip'"
      select << "calls.terminator_ip as 'tip'"
      select << "IF(calls.real_duration = 0, duration, real_duration) as 'real_duration2'"
      select << "IF(calls.real_billsec = 0, billsec, real_billsec) as 'real_billsec2'"

      headers << "'#{_('Originator_IP')}'" + ' AS oip'
      headers << "'#{_('Terminator_IP')}'" + ' AS tip'
      headers << "'#{_('Real_Duration')}'" + ' AS real_duration2'
      headers << "'#{_('Real_Billsec')}'" + ' AS real_billsec2'

      select2 << 'oip'
      select2 << 'tip'
      select2 << "#{n1}real_duration2#{n2} as real_duration2"
      select2 << "#{n1}real_billsec2#{n2} as real_billsec2"
    end

    jn = []
    jn << 'LEFT JOIN destinations ON (calls.prefix = destinations.prefix)'
    jn << 'LEFT JOIN directions ON (directions.code = destinations.direction_code)'
    jn << 'JOIN devices ON (devices.id = calls.dst_device_id)' if options[:direction] == 'incoming'

    filename = "CDR-#{id.to_s.gsub(' ', '_')}-#{options[:date_from].gsub(' ', '_').gsub(':', '_')}-#{options[:date_till].gsub(' ', '_').gsub(':', '_')}-#{Time.now().to_f.to_s.gsub('.', '')}-#{options[:direction]}-#{show_currency}"

    sql = 'SELECT * '
    if options[:test] != 1
      sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
    end
    disp = disposition.join(" AND ")
    #disp = "(#{disp}) OR (calls.reseller_id = #{id} AND calldate BETWEEN '#{options[:date_from]}' AND '#{options[:date_till]}')" if options[:reseller].to_i == 1

    # adding headers
    header_sql = 'SELECT ' + headers.join(', ') + ' UNION '

    sql += " FROM (" +
        "#{header_sql.to_s} SELECT #{select2.join(" , ")}  FROM
            ((SELECT #{select.join(" , ")}
      FROM calls  #{jn.join(" ")}
      WHERE #{disp}
      ORDER BY calls.calldate DESC)) as temp_a) as temp_c;"

    test_content = ''

    #  MorLog.my_debug(sql)
    if options[:test].to_i == 1
      mysql_res = ActiveRecord::Base.connection.select_all(sql)
      test_content = mysql_res.to_a.to_json
    else
      mysql_res = ActiveRecord::Base.connection.execute(sql)
    end
    return filename, test_content
  end

  def user_last_calls_order(options = {})
    cond = []
    cond << "(calldate BETWEEN '#{options[:from]}' AND '#{options[:till]}')"
    cond << "(dst_device_id = #{options[:device].id} OR src_device_id = #{options[:device].id})" if options[:device].to_i > 0
    cond << " disposition = '#{options[:call_type]}' " if options[:call_type] != 'all'
    cond << " calls.hangupcause = #{options[:hgc].code} " if options[:hgc]

    #cond << "(calls.reseller_id = '#{id}' OR devices.user_id = '#{id}')" if usertype == 'reseller'
    cond << "devices.user_id = '#{id}'" if usertype == 'user'

    jn = []
    jn << 'LEFT JOIN users ON (calls.user_id = users.id)'
#    jn << 'LEFT JOIN users AS resellers ON (calls.reseller_id = resellers.id)'
    jn << 'JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' if usertype != 'admin' and usertype != "accountant"
    jn2 = 'JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)' if usertype != 'admin' and usertype != "accountant"
    select = usertype == 'reseller' ? ' DISTINCT calls.*' : 'calls.*'

    if options[:csv] == 1
      s =[]
      format = Confline.get_value('Date_format', owner_id).gsub('M', 'i')
      s << SqlExport.nice_date('calldate', {reference: 'calldate', format: format, tz: time_offset})
      s << "calls.src"
      options[:usertype] == 'user' ? s << SqlExport.hide_dst_for_user_sql(self, 'csv', 'calls.dst', {as: 'dst'}) : s << 'calls.dst'
      s << "IF(calls.billsec = 0, IF(calls.real_billsec = 0, 0, calls.real_billsec) ,calls.billsec)"
      if usertype != 'user' or (Confline.get_value('Show_HGC_for_Resellers').to_i == 1 and usertype == 'reseller')
        s << "CONCAT(calls.disposition, '(', calls.hangupcause, ')')"
      else
        s << 'calls.disposition'
      end
      if usertype == 'admin'
        s << 'calls.server_id'

        s << "IF(calls.user_rate IS NULL, 0, #{SqlExport.replace_price('calls.user_rate')}), IF(calls.user_price IS NULL, 0, #{SqlExport.replace_price('calls.user_price')})"
      end
      if show_billing_info == 1
        if usertype == 'user'
          s << "IF(calls.user_price != 0 , IF(calls.user_price IS NULL, 0, #{SqlExport.replace_price('calls.user_price')})"
        end
      end
      filename = "Last_calls-#{id.to_s.gsub(" ", "_")}-#{options[:from].gsub(" ", "_").gsub(":", "_")}-#{options[:till].gsub(" ", "_").gsub(":", "_")}-#{Time.now().to_i}"
      sep, dec = csv_params
      sql = "SELECT * "
      if options[:test] != 1
        sql += " INTO OUTFILE '/tmp/#{filename}.csv'
            FIELDS TERMINATED BY '#{sep}' OPTIONALLY ENCLOSED BY '#{''}'
            ESCAPED BY '#{"\\\\"}'
        LINES TERMINATED BY '#{"\\n"}' "
      end
      sql += " FROM (SELECT #{s.join(', ')} FROM calls  #{jn.join(' ')}  WHERE #{cond.join(' AND ')} ORDER BY #{options[:order]} ) as C"

      if options[:test].to_i == 1
        mysql_res = ActiveRecord::Base.connection.select_all(sql)
        filename += mysql_res.to_yaml.to_s
      else
        mysql_res = ActiveRecord::Base.connection.execute(sql)
      end
      return filename
    else
      calls = Call.select(select).where(cond.join(' AND ')).joins(jn.join(' ')).order(options[:order]).limit("#{((options[:page].to_i - 1) * options[:items_per_page]).to_i}, #{options[:items_per_page]}").all
      calls_t = Call.where(cond.join(' AND ')).joins(jn2).count
      return calls, calls_t.to_i
    end
  end


  def User.check_users_balance
    users = User.where("warning_email_active = '1' AND (" +
                    "warning_balance_increases = 0 AND (" +
                      "(warning_email_sent = '1' AND balance > warning_email_balance) OR " +
                      "(warning_email_sent_admin = '1' AND balance > warning_email_balance_admin) OR " +
                      "(warning_email_sent_manager = '1' AND balance > warning_email_balance_manager))" +
                    " OR warning_balance_increases = 1 AND (" +
                      "(warning_email_sent = '1' AND balance < warning_email_balance) OR " +
                      "(warning_email_sent_admin = '1' AND balance < warning_email_balance_admin) OR " +
                      "(warning_email_sent_manager = '1' AND balance < warning_email_balance_manager)))").all

    users.each do |user|
      Application.reset_user_warning_email_sent_status(user)
    end
  end

  def User.find_all_for_select(owner_id = nil, options ={})
    opts = {select: "id, username, first_name, last_name, usertype, #{SqlExport.nice_user_sql}", order: 'nice_user'}
    opts[:select] += ', ' + options[:select] unless options[:select].blank?
    hide_manager = options[:hide_manager].present? ? "AND usertype != 'manager'" : ''
    if owner_id and
        if options[:exclude_owner] == true
          opts[:conditions] = ["users.owner_id = ? AND hidden = 0 #{hide_manager}", owner_id]
        else
          opts[:conditions] = ["users.id = ? or users.owner_id = ? AND hidden = 0 #{hide_manager}",
                               owner_id, owner_id]
        end
    end

    return User.select(opts[:select]).where(opts[:conditions]).order(opts[:order]).all
  end

  def find_all_for_select(options = {})
    User.find_all_for_select(id, options)
  end

  def activecalls
    Activecall.joins('LEFT JOIN devices ON activecalls.src_device_id = devices.id OR activecalls.dst_device_id = devices.id LEFT JOIN users ON devices.user_id = users.id').where(['devices.user_id = ?', id]).all
  end

  def activecalls_since(time, options = {})
     Activecall.joins("LEFT JOIN devices ON activecalls.src_device_id = devices.id OR activecalls.dst_device_id = devices.id LEFT JOIN users ON devices.user_id = users.id")
               .where(["devices.user_id = ? AND start_time > ? #{"AND answer_time IS NOT NULL" if options[:ongoing]}", id, time.strftime('%Y-%m-%d %H:%M:%S')]).all
  end

  def safe_attributtes(params, user_id)
    if ['reseller', 'user'].include?(usertype)
      allow_params = [:time_zone, :currency_id, :password, :warning_email_balance, :warning_email_hour, :first_name, :last_name, :clientid, :taxation_country, :vat_number, :acc_group_id]
      allow_params += [:web_address, :accounting_number, :generate_invoice, :generate_invoice_manually, :username, :tariff_id, :postpaid, :call_limit, :blocked, :agreement_number, :language, :warning_balance_sound_file_id, :warning_balance_call] if usertype == 'reseller' and self.id.to_i != user_id.to_i
      allow_params +=[:hide_destination_end]
      return params.reject { |key, value| !allow_params.include?(key.to_sym) }
    else
      return params
    end
  end

#(current_user.usertype == 'admin')? @users = current_user.load_users(:all, :conditions => ["users.owner_id = ?", current_user.id])  : @users = current_user.load_users(:all, {})
  def load_users(*arr)
    if arr[1] and arr[1].include?(:select)
      arr[1][:select] += " #{SqlExport.nice_user_sql}"
    else
      arr[1]= {} if not arr[1]
      arr[1][:select] = "*, #{SqlExport.nice_user_sql}"
    end

    arr[1][:order] = 'nice_user'

    if is_reseller?
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] += " AND (user_id = #{id} AND hidden = 0)"
      else
        arr[1]= {} if not arr[1]
        arr[1][:conditions] = "owner_id = #{id} AND hidden = 0"
      end
      User.find(*arr)
    else
      arr[1][:conditions] = ['users.owner_id = ?', current_user.id]
      User.find(*arr)
    end
  end

  def load_users_devices(*arr)
    if is_reseller?
      arr[1][:joins] ||= ''
      arr[1][:joins] += 'LEFT JOIN users ON (devices.user_id = users.id)'
      arr[1][:select] = 'devices.*'
      if arr[1] and arr[1].include?(:conditions)
        arr[1][:conditions] << " AND (users.owner_id = #{id} AND users.hidden = 0)"
      else
        arr[1][:conditions] = "users.owner_id = #{id} AND users.hidden = 0"
      end
      Device.find(*arr)
    else
      Device.find(*arr)
    end
  end

  def User.users_order_by(params, options)
    case options[:order_by].to_s.strip
      when 'acc'
        order_by = 'users.id'
      when 'nice_user'
        order_by = 'nice_user'
      when 'user'
        order_by = 'nice_user'
      when 'username'
        order_by = 'users.username'
      when "usertype"
        order_by = 'users.usertype'
      when 'balance'
        order_by = 'users.balance'
      when 'account_type'
        order_by = 'users.postpaid'
      when 'tps_active'
        order_by = 'tps_active'
      when 'ops_active'
        order_by = 'ops_active'
      else
        order_by = ''
    end
    if order_by != ''
      order_by += (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
    end
    return order_by
  end

  def convert_curr(rate)
    rate * User.current.currency.exchange_rate.to_d
  end

  def raw_balance
    read_attribute(:balance).to_d
  end

  def raw_balance=(value)
    write_attribute(:balance, value.to_d)
  end

  def raw_balance_min
    read_attribute(:balance_min).to_d
  end

  def raw_balance_max
    read_attribute(:balance_max).to_d
  end

  # converted attributes for user in current user currency
  def balance
    b = read_attribute(:balance)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance_min
    b = read_attribute(:balance_min)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance_max
    b = read_attribute(:balance_max)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def max_call_rate
    b = read_attribute(:max_call_rate)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def balance= value
    if User.current and User.current.currency
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:balance, b)
  end

  def credit
    c = read_attribute(:credit)
    if User.current and User.current.currency
      c.to_d != -1.to_d ? c.to_d * User.current.currency.exchange_rate.to_d : -1.to_d
    else
      c
    end
  end

  # TODO: prepaid user cannot have credit set especialy if credit is something invalid
  # like 20, -1 etc. maybe 0 could be set but i doubt that, cause PREPAID USER DOES
  # NOT HAVE CREDIT how is it posible to set something one does not have??? well at
  # least we should rise exception, if not hide this method. but not today cause this
  # might break to many things
  def credit= value
    #if prepaid?
    #raise "Cannot set credit for prepaid user"
    if User.current and User.current.currency
      c = value == -1 ? -1 : (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      c = value
    end
    write_attribute(:credit, c)
  end

  def warning_email_balance
    b = read_attribute(:warning_email_balance)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def warning_email_balance= value
    if User.current and User.current.currency
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:warning_email_balance, b)
  end

  def warning_email_balance_admin
    b = read_attribute(:warning_email_balance_admin)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def warning_email_balance_admin= value
    if User.current and User.current.currency
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:warning_email_balance_admin, b)
  end

    def warning_email_balance_manager
    b = read_attribute(:warning_email_balance_manager)
    if User.current and User.current.currency
      b.to_d * User.current.currency.exchange_rate.to_d
    else
      b.to_d
    end
  end

  def warning_email_balance_manager= value
    if User.current and User.current.currency
      b = (value.to_d / User.current.currency.exchange_rate.to_d).to_d
    else
      b = value
    end
    write_attribute(:warning_email_balance_manager, b)
  end

  def fix_when_is_rendering
    if User.current and self
      self.balance = self.balance.to_d * User.current.currency.exchange_rate.to_d
      self.credit = self.credit.to_d * User.current.currency.exchange_rate.to_d if credit != -1
      self.warning_email_balance = self.warning_email_balance.to_d * User.current.currency.exchange_rate.to_d
    end
  end

  def load_tariffs
    owner = get_correct_owner_id
    Tariff.where("owner_id = '#{owner}' ").order('purpose ASC, name ASC').all
  end

  def User.create_from_registration(params, owner, reg_ip, pin, pasw, nan, api=0)
    user = Confline.get_default_object(User, owner.id)
    # to skip balance conversion like in user creation from GUI.
    user.registration = true

    user.username = params[:username]
    user.password = Digest::SHA1.hexdigest(params[:password])
    user.usertype = 'user'
    user.first_name = params[:first_name]
    user.last_name = params[:last_name]
    user.clientid = params[:client_id] if params[:client_id].to_s != ''
    user.agreement_date = Time.now.to_s(:db)
    user.agreement_number = nan
    user.vat_number = params[:vat_number] if params[:vat_number].to_s != ''
    user.owner_id = owner.id
    user.acc_group_id = 0
    user.allow_loss_calls = Confline.get_value('Default_User_allow_loss_calls', owner.id)
    user.hide_non_answered_calls = Confline.get_value('Default_User_hide_non_answered_calls', owner.id).to_i
    #looking at code below and thinking 'FUBAR'? well mor currencies/money
    #is FUBAR, that's just a hack to get around. ticket #5041
    user.balance = owner.to_system_currency(owner.to_system_currency(user.balance))

    user.credit = 0

    address = Confline.get_default_object(Address, owner.id)
    address.direction_id = params[:country_id] if params[:country_id].to_s != ''
    address.state = params[:state] if params[:state].to_s != ''
    address.county = params[:county] if params[:county].to_s != ''
    address.city = params[:city] if params[:city].to_s != ''
    address.postcode = params[:postcode] if params[:postcode].to_s != ''
    address.address = params[:address] if params[:address].to_s != ''
    address.phone = params[:phone] if params[:phone].to_s != ''
    address.mob_phone = params[:mob_phone] if params[:mob_phone].to_s != ''
    address.fax = params[:fax] if params[:fax].to_s != ''
    address.save
    #If registering through API, taxation country by default is same
    #as country. ticket #5071
    user.taxation_country = address.direction_id

    tax = Confline.get_default_object(Tax, owner.id)
    tax.save
    user.tax = tax
    user.address_id = address.id

    user.save
    # my_debug @user.to_yaml

    if Confline.get_value('Allow_registration_username_passwords_in_devices').to_i == 1
      device = user.create_default_device({device_type: params[:device_type], secret: params[:password], username: user.username, pin: pin})
    else
      device = user.create_default_device({device_type: params[:device_type], secret: pasw, pin: pin})
    end
    device.callerid = params[:caller_id].to_s.strip if params[:caller_id]
    device.save
    user.save

    cb = 0
    if params[:mob_phone].to_s.gsub(/[^0-9]/, '').length > 0
      cli = Callerid.new({cli: params[:mob_phone].to_s.gsub(/[^0-9]/, ''), device_id: device.id, description: 'Mobile Phone', added_at: Time.now})
      cli.save
    end
    if params[:phone].to_s.gsub(/[^0-9]/, '').length > 0
      cli = Callerid.new({cli: params[:phone].to_s.gsub(/[^0-9]/, ''), device_id: device.id, description: 'Phone', added_at: Time.now})
      cli.save
    end
    if params[:fax].to_s.gsub(/[^0-9]/, '').length > 0
      cli = Callerid.new({cli: params[:fax].to_s.gsub(/[^0-9]/, ''), device_id: device.id, description: 'Fax', added_at: Time.now})
      cli.save
    end

    begin
      if api.to_i == 1
        thread = Thread.new {
          send_email_to_user = EmailsController.send_user_email_after_registration(user, device, params[:password], reg_ip)
          EmailsController.send_admin_email_after_registration(user, device, params[:password], reg_ip, owner.id)
          ActiveRecord::Base.connection.close
        }
      else
        send_email_to_user = EmailsController.send_user_email_after_registration(user, device, params[:password], reg_ip)
        EmailsController.send_admin_email_after_registration(user, device, params[:password], reg_ip, owner.id)
      end
    rescue => e
      notice = _('Email_not_sent_because_bad_system_configurations')
    end

    return user, send_email_to_user, device, notice
  end

  def User.validate_from_registration(params, owner_id = 0)
    notice = nil
    #error checking
    username = params[:username]

    # tmp user for model methods
    user = User.new
    user.owner_id = owner_id.to_i

    if username.to_s.blank?
      notice = _('Please_enter_username')
    end

    if User.where(['username = ?', username]).first and notice.blank?
      notice = _('Such_username_is_already_taken')
    end

    if params[:password] != params[:password2] and notice.blank?
      notice = _('Passwords_do_not_match')
    end

    if params[:password] and params[:password].to_s.strip.length < user.minimum_password
      notice = _('Password_must_be_longer', (user.minimum_password - 1))
    end

    if params[:username] and params[:username].to_s.strip.length < user.minimum_username
      notice = _('Username_must_be_longer', (user.minimum_username - 1))
    end

    if params[:password].blank? and notice.blank?
      notice = _('Please_enter_password')
    end

    if params[:password] == username and notice.blank?
      notice = _('Please_enter_password_not_equal_to_username')
    end

    if params[:first_name].blank? and notice.blank?
      notice = _('Please_enter_first_name')
    end

    if params[:last_name].blank? and notice.blank?
      notice = _('Please_enter_last_name')
    end

    if (params[:country_id].blank? || !Direction.where({id: params_country_id}).first) && notice.blank?
      notice = _('Please_select_country')
    end

    if params[:mob_phone].to_s.gsub(/[^0-9]/, '').length > 0 && notice.blank?
      if Callerid.where({cli: params[:mob_phone].to_s.gsub(/[^0-9]/, "")}).count.to_i > 0
        notice = _('User_with_mobile_phone_already_exists')
      end
    end

    if params[:phone].to_s.gsub(/[^0-9]/, '').length > 0 && notice.blank?
      if Callerid.where({cli: params[:phone].to_s.gsub(/[^0-9]/, '')}).count.to_i > 0
        notice = _('User_with_phone_already_exists')
      end
    end

    params_fax = params[:fax]
    if params_fax.to_s.gsub(/[^0-9]/, '').length > 0 && notice.blank?
      if Callerid.where({cli: params_fax.to_s.gsub(/[^0-9]/, '')}).size > 0
        notice = _('User_with_fax_already_exists')
      end
    end

    if (!params[:device_type] or !['SIP'].include?(params[:device_type])) and notice.blank?
      notice = _('Enter_device_type')
    end

    u = User.where(uniquehash: params[:id]).first
    if (!params[:id] or !u) and notice.blank?
      notice = _('Dont_be_so_smart')
    else
      if Confline.where("owner_id = #{u.id} AND name LIKE 'Default_User_%'").size.to_i == 0
        notice = _('Default_user_is_not_present')
      else
        u_id = u
      end
    end

    if notice.blank? and Confline.get_value('Registration_Enable_VAT_checking', u.id).to_i == 1
      if params[:vat_number] and params[:country_id]
        dr = Direction.where(id: params[:country_id]).first
        if params[:vat_number].blank?
          if Confline.get_value('Registration_allow_vat_blank', u.id).to_i == 0
            notice = _('Please_fill_field_TAX_Registration_Number')
          end
        else
          if  dr and ['BG', 'CS', 'DA', 'DE', 'EL', 'EN', 'ES', 'ET', 'FI', 'FR', 'HU', 'IT', 'LT', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SL', 'SV'].include?(dr.code.to_s[0..1])
            notice = _('TAX_Registration_Number_is_not_valid') if  !User.check_vat_for_user(params[:vat_number], dr.code.to_s[0..1])
          end
        end
      end
    end

    # tmp user destroy
    user.destroy

    return notice
  end

  def update_from_edit(params, current_user, tax_from_params, api = 0)
    user_old = self.dup

    # Backwards functionality
    if params[:address][:email].to_s.strip.present?
      params[:user][:main_email] = params[:address][:email].to_s.strip if params[:user][:main_email].blank?
      params[:address].delete(:email)
    end
    params[:user].delete(:two_fa_enabled)
    params[:user].delete(:usertype) # AS: usertype can't be changed since MOR x4
    params[:user][:routing_threshold] = params[:user][:routing_threshold].to_i
    update_attributes(current_user.safe_attributtes(params[:user], id))

    Action.add_action_hash(current_user.id, {action: 'user_edited', target_id: id, target_type: 'user'})
    if api == 1
      if params[:unlimited] and params[:unlimited].to_i == 1
        self.credit = -1
      else
        self.credit = params[:credit].to_d if params[:credit]
        self.credit = 0 if credit < 0 if params[:credit]
      end
    else
      if params[:unlimited].to_i == 1 and self.postpaid == 1
        self.credit = -1
      else
        self.credit = params[:credit].to_d
        self.credit = 0 if credit < 0
      end
    end

    self.credit = 0

    if self and user_old
      if tariff_id.to_i != user_old.tariff_id.to_i
        tariff = nil
        tariff = Tariff.where(id: tariff_id.to_i).first if self and tariff_id.to_i > 0
        !tariff ? tariff_name = '' : tariff_name = tariff.name

        tariff_old = nil
        tariff_old = Tariff.where(id: user_old.tariff_id.to_i).first if user_old and user_old.tariff_id.to_i > 0
        !tariff_old ? tariff_old_name = '' : tariff_old_name = tariff_old.name

        Action.add_action_hash(current_user.id, {action: 'user_tariff_changed', target_id: id, target_type: 'user', data: tariff_old_name, data2: tariff_name})
      end

      if user_old.user_type != user_type
        Action.add_action_hash(current_user.id, {action: 'user_type_change_to', target_id: id, target_type: 'user', data: user_type})
      end

      if user_old.postpaid != postpaid
        Action.add_action_hash(current_user.id, {action: 'postpaid_change_to', target_id: id, target_type: 'user', data: postpaid})
      end

      if user_old.credit != credit
        Action.add_action_hash(current_user.id, {action: 'user_credit_change', target_id: id, target_type: 'user', data: user_old.credit, data2: credit})
      end
    end

    self.password = Digest::SHA1.hexdigest(params[:password][:password]) if params[:password] and !params[:password][:password].blank?

    if (api == 1 and params[:agr_date][:year] and params[:agr_date][:month] and params[:agr_date][:day]) or api != 1
      self.agreement_date = params[:agr_date][:year].to_s + '-' + params[:agr_date][:month].to_s + '-' + params[:agr_date][:day].to_s if params[:agr_date]
    end

    if (api == 1 and params[:block_at_date][:year] and params[:block_at_date][:month] and params[:block_at_date][:day]) or api != 1
      self.block_at = params[:block_at_date][:year].to_s + '-' + params[:block_at_date][:month].to_s + '-' + params[:block_at_date][:day].to_s if params[:block_at_date]
    end

    if (api == 1 and params[:block_at_conditional]) or api != 1
      self.block_at_conditional = params[:block_at_conditional].to_i
    end

    if (api == 1 and params[:allow_loss_calls]) or api != 1
      self.allow_loss_calls = params[:allow_loss_calls].to_i
    end

    if (api == 1 and params[:hide_non_answered_calls]) or api != 1
      self.hide_non_answered_calls = params[:hide_non_answered_calls].to_i
    end

    if (api == 1 and params[:warning_email_active]) or api != 1
      self.warning_email_active = params[:warning_email_active].to_i
    end

    if params[:send_warning_balance_sms]
      self.send_warning_balance_sms = params[:send_warning_balance_sms].to_i
    end

    if (api == 1 and params[:warning_email_balance]) or api != 1
      self.warning_email_sent = 0 if warning_email_balance.to_d != params[:warning_email_balance].to_d
    end

    if (api == 1 and params[:show_zero_calls]) or api != 1
      self.invoice_zero_calls = params[:show_zero_calls].to_i
    end

    unless self.tax
      self.assign_default_tax
    end

    self.tax.update_attributes(tax_from_params)
    self.tax.save

    if (api == 1 and params[:block_conditional_use]) or api != 1
      self.block_conditional_use = params[:block_conditional_use].to_i
    end

    if address
      address.update_attributes(params[:address])
    else
      a = Address.create(params[:address])
      self.address_id = a.id
    end

    self.responsible_accountant_id = ((params[:user][:responsible_accountant_id].to_i < 1) ? self.responsible_accountant_id : params[:user][:responsible_accountant_id].to_i)
    if params[:warning_email_active]
      if params[:user] and params[:date]
        self.warning_email_hour = params[:user][:warning_email_hour].to_i != -1 ? params[:date][:user_warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
      end
    end

    self.comment = params[:user][:comment]
    self.save
    return self
  end

  def validate_from_update(current_user, params, api = 0)
    notice = ''
    co = current_user.id

    if current_user.is_reseller? and !params[:user][:usertype].blank? and params[:user][:usertype].to_s != 'user'
      notice = _('Dont_be_so_smart')
    end

    if !params[:user][:tariff_id].blank? and !Tariff.where(id: params[:user][:tariff_id], owner_id: co).first
      notice = _('Tariff_not_found')
    end

    params_pswd = params[:pswd]
    valid_pswd = params_pswd.present?

    unless User.strong_password?(params_pswd) || params_pswd.blank?
      notice = _('Password_must_be_strong')
      valid_pswd = false
    end

    if params_pswd.present? && params_pswd.to_s.strip.length < self.minimum_password
      notice = _('Password_must_be_longer', (self.minimum_password-1))
      valid_pswd = false
    end

    # Stores a timestamp of the most recent password change. Used for cleaning all user sessions
    monitor_password if valid_pswd

    if params[:u9] and params[:u9].strip.length < self.minimum_username
      notice = _('Username_must_be_longer', (self.minimum_username-1))
    end

    params[:user] = params[:user].each_value(&:strip!)
    params[:address] = params[:address].each_value(&:strip!) if params[:address]

    params[:user].delete(:balance)

    if (api == 1 and params[:user][:generate_invoice]) or api != 1
      params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i == 1 ? 1 : 0
    end

    generate_invoice_manually = params[:user][:generate_invoice_manually]
    if (api == 1 && generate_invoice_manually) || api != 1
      generate_invoice_manually = generate_invoice_manually.to_i == 1 ? 1 : 0
    end

    generate_prepaid_invoice = params[:user][:generate_prepaid_invoice]
    if (api == 1 && generate_prepaid_invoice) || api != 1
      generate_prepaid_invoice = generate_prepaid_invoice.to_i == 1 ? 1 : 0
    end

    if params[:user][:call_limit]
      params[:user][:call_limit] = params[:user][:call_limit].strip.to_i < 0 ? 0 : params[:user][:call_limit].strip
    end

    if (api == 1 and params[:accountant_type]) or api != 1
      params[:user][:acc_group_id] = %w[accountant reseller].include?(params[:user][:usertype]) ? params[:accountant_type].to_i : (0 if api != 1)
    end

    # privacy
    if params[:privacy]
      if api == 1
        params[:user][:hide_destination_end] = !params[:privacy][:gui] and !params[:privacy][:csv] and !params[:privacy][:pdf] ? (-1 if params[:privacy][:global].to_i == 1) : params[:privacy].values.sum { |v| v.to_i }
      else
        params[:user][:hide_destination_end] = params[:privacy][:global].to_i == 1 ? -1 : params[:privacy].values.sum { |v| v.to_i }
      end
    end

    params[:usertype] = usertype if params[:usertype] and !%w[user accountant reseller].include?(params[:usertype])

    ['tax2_enabled', 'tax3_enabled', 'tax4_enabled', 'own_providers',
     'compound_tax', 'show_zero_calls', 'unlimited', 'block_conditional_use', 'warning_email_active'].each { |p|
      params[p.to_sym] = params[p.to_sym].to_i > 0 ? 1 : (0 if params[p.to_sym])
      }

    params[:user][:warning_balance_call] = params[:user][:warning_balance_call].to_i > 0 ? 1 : 0 if params[:user][:warning_balance_call]
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i > 0 ? 1 : 0 if params[:user][:generate_invoice]
    params[:user][:generate_invoice_manually] = generate_invoice_manually.to_i > 0 ? 1 : 0 if generate_invoice_manually
    params[:user][:generate_prepaid_invoice] = generate_prepaid_invoice.to_i > 0 ? 1 : 0 if generate_prepaid_invoice
    params[:user][:billing_period] = ['weekly', 'bi-weekly', 'monthly', 'bimonthly', 'quarterly', 'halfyearly', 'dynamic'].include?(params[:billing_period]) ? params[:billing_period].to_s : 'monthly'
    if params[:billing_period] == 'dynamic'
      params[:user][:billing_dynamic_days] = params[:billing_dynamic_days]
      params[:user][:billing_dynamic_from] = params[:billing_dynamic_from]
      params[:user][:billing_dynamic_generation_time] = params[:billing_dynamic_generation_time]

      time_pattern = '%Y-%m-%d %H:%M'
      if params[:user][:billing_dynamic_from].to_time.strftime(time_pattern) != billing_dynamic_from.strftime(time_pattern) || billing_dynamic_days.to_i != params[:billing_dynamic_days].to_i ||
        billing_dynamic_generation_time.to_i != params[:billing_dynamic_generation_time].to_i
        params[:user][:billing_run_at] = InvoiceJob.set_run_at(
          billing_period: 'dynamic',
          billing_dynamic_days: params[:billing_dynamic_days],
          billing_dynamic_from: params[:user][:billing_dynamic_from],
          dynamic_hour: params[:billing_dynamic_generation_time]
        )
      end
    elsif ['bimonthly', 'quarterly', 'halfyearly'].include?(params[:billing_period])
      params[:user][:billing_run_at] = InvoiceJob.set_run_at(billing_period: params[:billing_period])
    end
    params[:user][:invoice_grace_period] = params[:invoice_grace_period] if params[:invoice_grace_period]
    params[:user][:postpaid] = 1  if params[:user][:postpaid]
    params[:user][:hidden] = params[:user][:hidden].to_i > 0 ? 1 : 0 if params[:user][:hidden]
    params[:user][:blocked] = params[:user][:blocked].to_i > 0 ? 1 : 0 if params[:user][:blocked]
    params[:user][:hide_non_answered_calls] = params[:user][:hide_non_answered_calls].to_i > 0 ? 1 : 0 if params[:user][:hide_non_answered_calls]
    params[:privacy][:global] = params[:privacy][:global].to_i > 0 ? 1 : 0 if params[:privacy]

    return notice, params
  end

  def check_translation
    trans = Translation.joins("LEFT JOIN (select translation_id from user_translations where user_id = #{id}) as ua ON (translations.id = translation_id )").where('ua.translation_id is null').all
    if trans and trans.size.to_i > 0
      trans.each { |t|
        u = UserTranslation.new(translation_id: t.id, user_id: id, position: t.position, active: 0)
        u.save
      }
    end
  end

  def user_time(time)
    time + time_offset.second
  end

  #class << self # Class methods
  #  alias :all_columns :columns
  #  def columns
  #    all_columns.reject {|c| c.name == 'time_zone'}
  #  end
  #end

  # def time_zone
  #   self[:time_zone]
  # end

  # def time_zone=(s)
  #   self[:time_zone] = s
  # end

 # *Returns*
 #  integer - difference in hours between user time and system time
  def time_offset
    Time.zone.now.utc_offset().second - Time.now.utc_offset().second
  end

  def system_time(time, only_date = 0)
    t = time.class == 'Time' ? time : time.to_time
    if only_date == 0
      (t - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_s(:db)
    else
      (t - Time.zone.now.utc_offset().second + Time.now.utc_offset().second).to_date.to_s(:db)
    end
  end

  def User.get_zones
    # Keys are Rails TimeZone names, values are TZInfo identifiers
    m = [
        ["(GMT-11:00) International Date Line West, Midway Island, Samoa", "International Date Line West", -11.0],
        #["(GMT-11:00) Midway Island"	,	"Midway Island", -11],
        #["(GMT-11:00) Samoa"	,	"Samoa", -11],
        ["(GMT-10:00) Hawaii", "Hawaii", -10.0],
        ["(GMT-09:00) Alaska", "Alaska", -9.0],
        ["(GMT-08:00) Pacific Time (US & Canada), Tijuana", "Pacific Time (US & Canada)", -8.0],
        #["(GMT-08:00) Tijuana"	,	"Tijuana", -8],
        ["(GMT-07:00) Arizona, Chihuahua, Mazatlan, Mountain Time (US & Canada)", "Arizona", -7.0],
        #["(GMT-07:00) Chihuahua"	,	"Chihuahua", -7],
        #["(GMT-07:00) Mazatlan"	,	"Mazatlan", -7],
        #["(GMT-07:00) Mountain Time (US & Canada)"	,	"Mountain Time (US & Canada)", -7],
        ["(GMT-06:00) Central Time (US & Canada), Guadalajara, Mexico City, Saskatchewan", "Central America", -6.0],
        #["(GMT-06:00) Central Time (US & Canada)"	,	"Central Time (US & Canada)", -6],
        #["(GMT-06:00) Guadalajara"	,	"Guadalajara", -6],
        #["(GMT-06:00) Mexico City"	,	"Mexico City", -6],
        #["(GMT-06:00) Monterrey"	,	"Monterrey", -6],
        #["(GMT-06:00) Saskatchewan"	,	"Saskatchewan", -6],
        ["(GMT-05:00) Bogota, Eastern Time (US & Canada), Indiana (East), Lima, Quito", "Bogota", -5.0],
        #["(GMT-05:00) Eastern Time (US & Canada)"	,	"Eastern Time (US & Canada)", -5],
        #["(GMT-05:00) Indiana (East)"	,	"Indiana (East)", -5],
        #["(GMT-05:00) Lima"	,	"Lima", -5],
        #["(GMT-05:00) Quito"	,	"Quito", -5],
        ["(GMT-04:30) Caracas", "Caracas", -4.5],
        ["(GMT-04:00) Atlantic Time (Canada), Georgetown, La Paz, Santiago", "Atlantic Time (Canada)", -4.0],
        #			["(GMT-04:00) Georgetown"	,	"Georgetown", -4],
        #			["(GMT-04:00) La Paz"	,	"La Paz", -4],
        #			["(GMT-04:00) Santiago"	,	"Santiago", -4],
        ["(GMT-03:30) Newfoundland", "Newfoundland", -3.5],
        ["(GMT-03:00) Brasilia, Buenos Aires, Greenland", "Brasilia", -3.0],
        #			["(GMT-03:00) Buenos Aires"	,	"Buenos Aires", -3],
        #			["(GMT-03:00) Greenland"	,	"Greenland", -3],
        ["(GMT-02:00) Mid-Atlantic", "Mid-Atlantic", -2.0],
        ["(GMT-01:00) Azores, Cape Verde Is", "Azores", -1.0],
        #			["(GMT-01:00) Cape Verde Is."	,	"Cape Verde Is.", -1],
        ["(GMT+00:00) Casablanca, Dublin, Edinburgh, Lisbon, London, Monrovia", "Casablanca", 0.0],
        #			["(GMT+00:00) Dublin"	,	"Dublin", 0],
        #			["(GMT+00:00) Edinburgh"	,	"Edinburgh", 0],
        #			["(GMT+00:00) Lisbon"	,	"Lisbon", 0],
        #			["(GMT+00:00) London"	,	"London", 0],
        #			["(GMT+00:00) Monrovia"	,	"Monrovia", 0],
        #["(GMT+00:00) UTC"	,	"UTC", 0],
        ["(GMT+01:00) Amsterdam, Belgrade, Berlin, Madrid, Paris, Prage,  Rome ", "Amsterdam", 1.0],
        #			["(GMT+01:00) Belgrade"	,	"Belgrade", 1],
        #			["(GMT+01:00) Berlin"	,	"Berlin", 1],
        #			["(GMT+01:00) Bern"	,	"Bern", 1],
        #			["(GMT+01:00) Bratislava"	,	"Bratislava", 1],
        #			["(GMT+01:00) Brussels"	,	"Brussels",1],
        #			["(GMT+01:00) Budapest"	,	"Budapest",1],
        #			["(GMT+01:00) Copenhagen"	,	"Copenhagen",1],
        #			["(GMT+01:00) Ljubljana"	,	"Ljubljana",1],
        #			["(GMT+01:00) Madrid"	,	"Madrid",1],
        #			["(GMT+01:00) Paris"	,	"Paris",1],
        #			["(GMT+01:00) Prague"	,	"Prague",1],
        #			["(GMT+01:00) Rome"	,	"Rome",1],
        #			["(GMT+01:00) Sarajevo"	,	"Sarajevo",1],
        #			["(GMT+01:00) Skopje"	,	"Skopje",1],
        #			["(GMT+01:00) Stockholm"	,	"Stockholm",1],
        #			["(GMT+01:00) Vienna"	,	"Vienna",1],
        #			["(GMT+01:00) Warsaw"	,	"Warsaw",1],
        #			["(GMT+01:00) West Central Africa"	,	"West Central Africa",1],
        #			["(GMT+01:00) Zagreb"	,	"Zagreb",1],
        ["(GMT+02:00) Athens, Cairo, Helsinki, Istanbul, Kyiv, Minsk, Riga, Tallinn, Vilnius", "Athens", 2.0],
        #			["(GMT+02:00) Bucharest"	,	"Bucharest",2],
        #			["(GMT+02:00) Cairo"	,	"Cairo",2],
        #			["(GMT+02:00) Harare"	,	"Harare",2],
        #			["(GMT+02:00) Helsinki"	,	"Helsinki",2],
        #			["(GMT+02:00) Istanbul"	,	"Istanbul",2],
        #			["(GMT+02:00) Jerusalem"	,	"Jerusalem",2],
        #			["(GMT+02:00) Kyiv"	,	"Kyiv",2],
        #			["(GMT+02:00) Minsk"	,	"Minsk",2],
        #			["(GMT+02:00) Pretoria"	,	"Pretoria",2],
        #			["(GMT+02:00) Riga"	,	"Riga",2],
        #			["(GMT+02:00) Sofia"	,	"Sofia",2],
        #			["(GMT+02:00) Tallinn"	,	"Tallinn",2],
        #			["(GMT+02:00) Vilnius"	,	"Vilnius",2],
        ["(GMT+03:00) Baghdad, Kuwait, Nairobi, Riyadh", "Baghdad", 3.0],
        #			["(GMT+03:00) Kuwait"	,	"Kuwait",3],
        #			["(GMT+03:00) Nairobi"	,	"Nairobi",3],
        #			["(GMT+03:00) Riyadh"	,	"Riyadh",3],
        ["(GMT+03:30) Tehran", "Tehran", 3.5],
        ["(GMT+04:00) Abu Dhabi, Baku, Moscow, Muscat, Tbilisi, Volgograd, Yerevan", "Abu Dhabi", 4.0],
        #			["(GMT+04:00) Baku"	,	"Baku",4],
        #			["(GMT+04:00) Moscow"	,	"Moscow",4],
        #			["(GMT+04:00) Muscat"	,	"Muscat",4],
        #			["(GMT+04:00) St. Petersburg"	,	"St. Petersburg",4],
        #			["(GMT+04:00) Tbilisi"	,	"Tbilisi",4],
        #			["(GMT+04:00) Volgograd"	,	"Volgograd",4],
        #			["(GMT+04:00) Yerevan"	,	"Yerevan",4],
        #["(GMT+04:30) Kabul"	,	"Kabul",4.5],
        ["(GMT+05:00) Islamabad, Karachi, Tashkent", "Islamabad", 5.0],
        #			["(GMT+05:00) Karachi"	,	"Karachi",5],
        #			["(GMT+05:00) Tashkent"	,	"Tashkent",5],
        ["(GMT+05:30) Chennai, Kolkata, Mumbai, New Delhi, Sri Jayawardenepura", "Chennai", 5.5],
        #["(GMT+05:30) Kolkata"	,	"Kolkata",5.5],
        #["(GMT+05:30) Mumbai"	,	"Mumbai",5.5],
        #["(GMT+05:30) New Delhi"	,	"New Delhi",5.5],
        #["(GMT+05:30) Sri Jayawardenepura"	,	"Sri Jayawardenepura",5.5],
        ["(GMT+05:45) Kathmandu", "Kathmandu", 5.75],
        ["(GMT+06:00) Almaty, Astana, Dhaka, Ekaterinburg", "Almaty", 6.0],
        #			["(GMT+06:00) Astana"	,	"Astana",6],
        #			["(GMT+06:00) Dhaka"	,	"Dhaka",6],
        #			["(GMT+06:00) Ekaterinburg"	,	"Ekaterinburg",6],
        ["(GMT+06:30) Rangoon", "Rangoon", 6.5],
        ["(GMT+07:00) Bangkok, Hanoi, Jakarta, Novosibirsk", "Bangkok", 7.0],
        #			["(GMT+07:00) Hanoi"	,	"Hanoi",7],
        #			["(GMT+07:00) Jakarta"	,	"Jakarta",7],
        #			["(GMT+07:00) Novosibirsk"	,	"Novosibirsk",7],
        ["(GMT+08:00) Beijing, Hong Kong, Krasnoyarsk, Kuala Lumpur, Perth, Singapore, Taipei", "Beijing", 8.0],
        #			["(GMT+08:00) Chongqing"	,	"Chongqing",8],
        #			["(GMT+08:00) Hong Kong"	,	"Hong Kong",8],
        #			["(GMT+08:00) Krasnoyarsk"	,	"Krasnoyarsk",8],
        #			["(GMT+08:00) Kuala Lumpur"	,	"Kuala Lumpur",8],
        #			["(GMT+08:00) Perth"	,	"Perth",8],
        #			["(GMT+08:00) Singapore"	,	"Singapore",8],
        #			["(GMT+08:00) Taipei"	,	"Taipei",8],
        #			["(GMT+08:00) Ulaan Bataar"	,	"Ulaan Bataar",8],
        #			["(GMT+08:00) Urumqi"	,	"Urumqi",8],
        ["(GMT+09:00) Irkutsk, Osaka, Sapporo, Seoul, Tokyo", "Irkutsk", 9.0],
        #			["(GMT+09:00) Osaka"	,	"Osaka",9],
        #			["(GMT+09:00) Sapporo"	,	"Sapporo",9],
        #			["(GMT+09:00) Seoul"	,	"Seoul",9],
        #			["(GMT+09:00) Tokyo"	,	"Tokyo",9],
        ["(GMT+09:30) Adelaide, Darwin", "Adelaide", 9.5],
        #["(GMT+09:30) Darwin"	,	"Darwin",9.5],
        ["(GMT+10:00) Brisbane, Canberra, Hobart, Melbourne, Port Moresby, Sydney, Yakutsk", "Brisbane", 10.0],
        #			["(GMT+10:00) Canberra"	,	"Canberra",10],
        #			["(GMT+10:00) Guam"	,	"Guam",10],
        #			["(GMT+10:00) Hobart"	,	"Hobart",10],
        #			["(GMT+10:00) Melbourne"	,	"Melbourne",10],
        #			["(GMT+10:00) Port Moresby"	,	"Port Moresby",10],
        #			["(GMT+10:00) Sydney"	,	"Sydney",10],
        #			["(GMT+10:00) Yakutsk"	,	"Yakutsk",10],
        ["(GMT+11:00) New Caledonia, Vladivostok", "New Caledonia", 11.0],
        #			["(GMT+11:00) Vladivostok"	,	"Vladivostok",11],
        ["(GMT+12:00) Auckland, Fiji, Kamchatka, Magadan, Marshall Is., Solomon Is., Wellington", "Auckland", 12.0],
        #			["(GMT+12:00) Fiji"	,	"Fiji",12],
        #			["(GMT+12:00) Kamchatka"	,	"Kamchatka",12],
        #			["(GMT+12:00) Magadan"	,	"Magadan",12],
        #			["(GMT+12:00) Marshall Is."	,	"Marshall Is.",12],
        #			["(GMT+12:00) Solomon Is."	,	"Solomon Is.",12],
        #			["(GMT+12:00) Wellington"	,	"Wellington",12],
        ["(GMT+13:00) Nuku'alofa", "Nuku'alofa", 13.0]]
    #}.each { |name, zone| name.freeze; zone.freeze }
    #m #.freeze.sort
  end

  def minimum_password
    min = Confline.get_value('Default_User_password_length', self.get_correct_owner_id).to_i
    if User.use_strong_password?
      min = 8 if min < 8
    else
      min = 6 if min < 6
    end
    min
  end

  def minimum_username
    min = Confline.get_value('Default_User_username_length', self.get_correct_owner_id).to_i
    min = 1 if min < 1
    min
  end

  def alow_device_types_dahdi_virt
    return (usertype != 'reseller' or (Confline.get_value('Resellers_Allow_Use_dahdi_Device', 0).to_i != 0)), (usertype != 'reseller' or (Confline.get_value('Resellers_Allow_Use_Virtual_Device', 0).to_i != 0))
  end

  def get_correct_owner_id
    if is_admin? || is_manager?
      return 0
    elsif is_reseller?
      return id
    else
      return owner_id
    end
  end

  def get_correct_owner_id_for_api
    if is_admin? || is_manager?
      return 0
    else
      return owner_id
    end
  end

  def get_corrected_owner_id
    %w[admin manager].include?(usertype) ? 0 : id
  end

  def get_price_calculation_sqls
    up = SqlExport.admin_user_price_sql
    # rp = SqlExport.admin_reseller_price_sql
    rp = nil
    pp = SqlExport.admin_provider_price_sql
    return up, rp, pp
  end

  def invoice_zero_calls_sql(up = 'calls.user_price')
    invoice_zero_calls.to_i == 0 ? " AND #{up} > 0 " : ''
  end


  # Check whether postpaid user has unlimited credit.
  # TODO: there is smth fishy in db, postpaid users user.credit is equals
  # to -1. so guess what result would this method return if you would ask
  # postpaid user whehter he has unlimited credit. TRUE!! but this is standard
  # in mor, fixing this might break smth.
  # TODO: should i raise exception if user is not prepaid? conceptualy
  # prepaid user cannot event know about such thing as unlimited credit,
  # he does not event have credit. this might break a lot of things.
  def credit_unlimited?
    #if prepaid?
    #  raise "Prepaid users do not have credit"
    credit == -1
  end

=begin
  Check whether user is of postpaid type

  *Returns*
  *boolean* - true or false depending on wheter user is postpaid
=end
  def postpaid?
    postpaid.to_i == 1
  end

=begin
  Check whether user is of prepaid type

  *Returns*
  *boolean* - true or false depending on wheter user is prepaid
=end
  def prepaid?
    not postpaid?
  end

=begin
  Information whether user is postpaid or prepaid in database is saved in database
  in as int - 0 for prepaid, 1 for postpaid. prepaid user cannot have any credit, so it
  is set to 0.
  Notice that 1)credit is set to 0 when user is set to prepaid and 2) when credit is set
  we check whether user is prepaid(and should rise exception) or not.
  TODO: should express to others that though i doublt whether it has any sense, cause user
  does not have credit(NULL, VOID etc), but not has credit equal to 0.
=end
  def set_prepaid
    credit = 0
    postpaid = 0
  end

  # Information whether user is postpaid or prepaid in database is saved in database
  # in as int - 0 for prepaid, 1 for postpaid.
  def set_postpaid
    postpaid = 1
  end

=begin
  Check whether minimal charge for this user is enabled

  *Returns*
  *boolean* - true or false depending on wheter minimal charge is enabled or disabled
=end
  def minimal_charge_enabled?
    minimal_charge != 0
  end

  # converted attributes for user in given currency exrate
  def converted_minimal_charge(exr)
    b = read_attribute(:minimal_charge)
    b.to_d * exr.to_d
  end

=begin
  havin issues trying to turn off rails timezone conversion, but writing
  attribute manual helps to sovle this issue.
=end
  def minimal_charge_start_at=(value)
    value = (value.respond_to?(:strftime) ? value.strftime('%F %H:%M:%S') : value)
    write_attribute(:minimal_charge_start_at, value)
  end

=begin
  Convert amount from user currency to system currency.
  Note to future developers - do not check whether user has associated currency,
  if he has not, this would be a major bug, all hell should brake loose.

  *Params*
  +value+ amount in users currency

  *Returns*
  +value_in_system_currency+ float, amount converted to system currency
=end
  def to_system_currency(value)
    value.to_d / currency.exchange_rate.to_d
  end

  def integrity_recheck_user
    default_user_warning = false

    df = Confline.get_default_user_pospaid_errors
    default_user_warning = true if df and df.count.to_i > 0 #Confline.get_value('Default_User_allow_loss_calls', id).to_i == 1 and Confline.get_value('Default_User_postpaid', id).to_i == 1

    users_postpaid_and_loss_calls = User.where(postpaid: 1, allow_loss_calls: 1).all

    if users_postpaid_and_loss_calls.size > 0 or default_user_warning
      return 1
    else
      Confline.set_value('Integrity_Check', 0)
      return 0
    end

  end

  def User.check_vat_for_user(vat = '', country = '')
    out = false
    begin
      b = URI.parse('http://ec.europa.eu/taxation_customs/vies/viesquer.do')
      http = Net::HTTP.new(b.host, b.port)
      request = Net::HTTP::Post.new(b.request_uri)
      request.set_form_data({'ms' => country, 'vat' => vat, 'iso' => country, 'requesterMs' => '', 'requesterIso' => '---', 'requesterVat' => ''})
      response = http.request(request)
      out = response.body.include?('Yes, valid VAT number')
    rescue

    end

    return out
  end

  def blocked?
    blocked == 1
  end


=begin
  Add some amount to user's balance.
  Note that after changeing balance we immediately save data to database, since we dont use
  transactions that's least what we should do. If adding amount to balance or creating
  payment fails - we do our best to revert everything... but still without using
  transactions there are lot's of ways to fail.
  Note that amount is expected to be in system's default currency, if not payment amount
  might be giberish.

  *Params*
  +amount+ amount to be added to balance and payment created with amount and tax in
   this users currency.

  *Returns*
  +boolean+ true changeing balance and creating payment succeeded, otherwise false.
     Note that no transactions are used, so if smth goes wrong data might be corrupted.
=end
  def add_to_balance(amount, payment_type = 'Manual')
    self.balance += amount
    if self.save
      exchange_rate = Currency.count_exchange_rate(Currency.get_default.name, currency.name)
      amount *= exchange_rate
      tax_amount = self.get_tax.count_tax_amount(amount)
      payment = Payment.create_for_user(self, {:paymenttype => payment_type, :amount => amount, :tax => tax_amount, :shipped_at => Time.now, :date_added => Time.now, :completed => 1, :currency => currency.name})
      if payment.save
        return true
      else
        self.balance -= amount
        self.save
        return false
      end
    else
      return false
    end
  end

  def balance_with_vat
    self.get_tax.apply_tax(self.balance)
  end

  def block_and_send_email
    users = [self, owner]
    em = Email.where(["name = 'block_when_no_balance' AND owner_id = ?", owner_id]).first
    variables = Email.email_variables(self)

    begin
      num = EmailsController::send_email(em, Confline.get_value('mail_from', owner_id), users, variables)
    rescue
      MorLog.my_debug('Failed to send email to the user')
    end

    # num = Email.send_email(em, users, Confline.get_value("Email_from", owner_id), 'send_email', {:assigns=>variables, :owner=>variables[:owner]})
    if num.to_s != _('Email_sent')
      Action.add_action_second(id, 'error', 'Cant_send_email', num.to_s.gsub('<br>', ''))
    end

    Action.new(user_id: id, date: Time.now, action: 'user_blocked', data: 'insufficient funds').save
    self.blocked = 1
  end

  # Checks user devices for sip type device
  def have_sip_device?
    sip_devices.where(host: 'dynamic').try(:size).to_i > 0
  end

  def accountant_users
    User.where(responsible_accountant_id: id).all
  end

  def update_balance(amount)
    self.raw_balance += amount.to_d
    save
  end

  def get_email_to_address
    if billing_email.present?
      billing_email.to_s
    elsif main_email.present?
      main_email.to_s
    elsif rates_email.present?
      rates_email.to_s
    elsif noc_email.present?
      noc_email.to_s
    else
      ''
    end
  end

  def get_email_to_address2
    if billing_email.present?
      billing_email.to_s
    elsif main_email.present?
      main_email.to_s
    elsif noc_email.present?
      noc_email.to_s
    elsif rates_email.present?
      rates_email.to_s
    else
      ''
    end
  end

  def mark_logged_in
    self.logged = 1
    save
  end

  def mark_logged_out
    self.logged = 0
    save
  end


  def kick_user
    self.logged = 0
    password = UtilityHelper.random_password(12)
    self.password = Digest::SHA1.hexdigest(password)
    self.blocked = 1
    save
  end

  def self.recover_password(email)
    message = ''
    successful = false
    users = User.where(main_email: email).all
    if users.present?
      if users.size == 1
        user = users.first
        if user and user.id != 0
          owner_id = user.owner_id
          password = UtilityHelper.random_password(12)
          email = Email.where(name: 'password_reminder', owner_id: owner_id).first
          variables = Email.email_variables(user, nil, {owner: owner_id, login_password: password})
          begin
            result = EmailsController::send_email(email, Confline.get_value('Email_from', owner_id), [user], variables)
          rescue
            result = ''
            message = (_('Cannot_change_password') + '<br />' + _('Email_not_sent_because_bad_system_configurations')).html_safe
          end
          if result.to_s.include?(_('Email_sent'))
            user.password = Digest::SHA1.hexdigest(password)
            if user.save
              message = _('Password_changed_check_email_for_new_password') + '  ' + user.email
              successful = true
            else
              message = _('Cannot_change_password')
            end
          end
        else
          message = _('Cannot_change_password')
        end
      else
        message = _('Email_is_used_by_multiple_users_Cannot_reset_password')
      end
    else
      message = _('Email_was_not_found')
    end
    return message, successful
  end

  def m2_emails
    @m2_emails ||=  begin
                      emails = [self.main_email, self.noc_email, self.billing_email, self.rates_email]
                      email_enum = [0, 1, 2, 3]
                      emails.zip(email_enum).reject {|value| value.first.blank? || value.last.blank? }
                    end
  end

  def m2_email
    self.try(:[], M2_EMAILS[@m2_email_enum.to_i])
  end

  def m2_email=(enum)
    @m2_email_enum = enum
  end

  def User.member_toggle_login(params)
    action = ''
      user = User.where(:id => params[:member]).first
      if user.logged == 1 and params[:laction] == 'logout'
        user.logged = 0
        action = 'logout'
      end

      if user.logged == 0 and params[:laction] == 'login'
        user.logged = 1
        action = 'login'
      end
      user.save
      return user, action
  end

  def self.find_global_thresholds
    bl_global_threshold = Confline.get_value('default_routing_threshold', 0)
    bl_global_threshold_2 = Confline.get_value('default_routing_threshold_2', 0)
    bl_global_threshold_3 = Confline.get_value('default_routing_threshold_3', 0)
    bl_global_threshold = _('Disabled') if bl_global_threshold.to_i <= 0
    bl_global_threshold_2 = _('Disabled') if bl_global_threshold_2.to_i <= 0
    bl_global_threshold_3 = _('Disabled') if bl_global_threshold_3.to_i <= 0

    return bl_global_threshold, bl_global_threshold_2, bl_global_threshold_3
  end

  # Returns found user for api
  def self.api_rate_get_user(params_u, username)
    params_user = self.where(username: params_u).first
    selected_user = self.where(username: username).first

    # /billing/api/rate_get?prefix=54
    if selected_user.blank? || params_user.blank?
      return nil
    end

    # /billing/api/rate_get?u=user&username=anybody&prefix=54 or
    # /billing/api/rate_get?u=reseller&username=reseller&prefix=54
    if params_user.is_user? || (params_user.is_reseller? && params_u == username)
      return params_user
    end

    # /billing/api/rate_get?u=anybody&username=admin/accountant&prefix=54
    if selected_user.is_admin?
      return nil
    end

    # /billing/api/rate_get?u=admin&username=anybody&prefix=54
    if params_user.is_admin?
      return self.where(username: username, owner_id: 0).first
    end

    return self.where(username: username, owner_id: params_user.id).first
  end

  def change_warning_balance_currency
    exchange_rate = User.current.currency.exchange_rate.to_d
    self.warning_email_balance *= exchange_rate
    self.warning_email_balance_admin *= exchange_rate
    self.warning_email_balance_manager *= exchange_rate
  end

  def ignore_global_alerts?
    ignore_global_alerts.to_i == 1 if defined?(ignore_global_alerts)
  end

  def self.responsible_acc
    User.where(hidden: '0', usertype: 'manager').order('username')
  end

  def self.responsible_acc_for_list
    responsible_accountants = User.select('accountants.*').
                              joins('JOIN users accountants ON (accountants.id = users.responsible_accountant_id)').
                              where("accountants.hidden = 0 and accountants.usertype = 'manager'").
                              group('accountants.id').order('accountants.username')

    return responsible_accountants
  end

  def self.first_resellers_ids
    first_reseller_id, first_reseller_pro_id = User.where(usertype: 'reseller', own_providers: 0).first.try(:id),
                                              User.where(usertype: 'reseller', own_providers: 1).first.try(:id)
  end

  def self.seek_by_filter(current_user, user_str, style, params = {})
    options = params[:options] || {}
    output = []
    cond = options.present? && (options[:show_admin].present? || (current_user.id == 0 && options[:show_admin_only_for_admin].present?)) ? ['users.id >= 0'] : ['users.id > 0']
    var = []
    tmp_current_user_id = current_user.id
    if options.present? && options[:user_owner].present?
      current_user_id = options[:user_owner].to_i
    else
      current_user_id = current_user.is_manager? ? 0 : tmp_current_user_id
    end

    if options.present? && options[:show_managers_only].present?
      cond << "users.usertype = 'manager'"
    else
      cond << "users.usertype != 'manager'" unless options.present? && options[:show_managers].present?
    end
    if current_user.usertype == 'manager' && current_user.show_only_assigned_users?
      if options.present? && options[:show_managers].present?
        cond << "(users.responsible_accountant_id = '#{tmp_current_user_id}' OR users.id = #{current_user.id})"
      else
        cond << "users.responsible_accountant_id = '#{tmp_current_user_id}'"
      end
    end

    cond << "users.usertype = 'user'" if (options.present? && options[:show_users_only].present?)
    cond << 'hidden = 0'

    if options.present? && options[:include_owner].to_s == 'true'
      cond << "(users.id = #{current_user_id} OR users.owner_id = #{current_user_id})"
    else
      cond << 'users.owner_id = ?' and var << current_user_id if (!current_user.is_admin? && !current_user.is_accountant? && !current_user.is_manager?) ||
                                                                 (options.present? && !options[:show_reseller_users]) ||
                                                                 (options.present? && options[:show_owned_users_only])
    end

    if user_str.to_s != ''
      name_cond = []
      name_cond << 'users.username LIKE ?' and var << user_str + '%'
      name_cond << "CONCAT(users.first_name, ' ', users.last_name) LIKE ?" and var << user_str + '%'
      name_cond << 'users.last_name LIKE ?' and var << user_str + '%'
      cond << "(#{name_cond.join(' OR ')})"
    end

    seek = []

    if options.present? && options[:show_optionals]
      options[:show_optionals].each do |option|
        seek << ["<tr><td id=""#{option.downcase}"" #{style}>" << _("#{option}") << '</td></tr>']
      end
    end

    if params[:responsible_accountant_id].present? && params[:responsible_accountant_id] != '-1'
      cond << "responsible_accountant_id = #{params[:responsible_accountant_id]}"
    end

    if options.present? && options[:users_to_get].present?
      case options[:users_to_get].to_s
      when 'originators'
        seeker = User.is_user.with_origination_points
      when 'terminators'
        seeker = User.is_user.with_termination_points
      end
    else
      seeker = User.all
    end

    if options.present? && options[:inner_join_m2_payments].to_s == 'true'
      seeker = seeker.joins("JOIN m2_payments ON m2_payments.user_id = users.id")
    end

    total_users = seeker.where([cond.join(' AND ')].concat(var)).count

    seek << seeker.where([cond.join(' AND ')].concat(var)).alphabetized.group_by_user_id.limit(20).
            map { |user| ["<tr><td id='" << user.id.to_s << "' #{style}>" << user[:nice_user] << '</td></tr>'] }

    output << seek

    if total_users > 20
      output << "<tr><td id='-2' #{style}>" << _('Found') << " " << (total_users - 20).to_s << ' ' << _('more') << '</td></tr>'
    elsif total_users == 0
      output << ["<tr><td id='-2' #{style}>" << _('No_value_found') << '</td></tr>']
    end

    return output, total_users
  end

  def self.users_for_users_list(options)
    current_user_usertype = current_user.usertype
    correct_owner_id = ['admin', 'manager'].include?(current_user_usertype) ? 0 : current_user.owner_id

    select = ["users.*", "tariffs.purpose", "#{SqlExport.nice_user_sql}"]
    select << 'addresses.city, addresses.county'
    select << 'tariffs.name AS tariff_name'
    select << '(SELECT COUNT(*) FROM devices WHERE op = 1 AND users.id = devices.user_id AND hidden_device = 0) AS ops_active'
    select << '(SELECT COUNT(*) FROM devices WHERE tp = 1 AND users.id = devices.user_id AND hidden_device = 0) AS tps_active'

    cond = ["users.hidden = 0 AND users.id != 0 AND users.owner_id = #{correct_owner_id} AND users.usertype != 'manager'"]
    cond << "users.usertype = '#{options[:user_type]}'" if options[:user_type].present? && options[:user_type].to_i != -1
    cond << "users.id = '#{options[:s_id]}'" if options[:s_id].present? && options[:s_id].to_i != -1
    cond << "users.agreement_number LIKE '#{options[:s_agr_number].to_s}%'" if options[:s_agr_number].present?
    cond << "users.accounting_number LIKE '#{options[:s_acc_number].to_s}%'" if options[:s_acc_number].present?
    cond << "(main_email = '#{ActiveRecord::Base::sanitize("#{options[:s_email]}")[1..-2]}' OR noc_email = '#{ActiveRecord::Base::sanitize("#{options[:s_email]}")[1..-2]}' OR billing_email = '#{ActiveRecord::Base::sanitize("#{options[:s_email]}")[1..-2]}' OR rates_email = '#{ActiveRecord::Base::sanitize("#{options[:s_email]}")[1..-2]}')" if options[:s_email].present?
    cond << "users.responsible_accountant_id = '#{options[:responsible_accountant_id]}'" if options[:responsible_accountant_id].present? && options[:responsible_accountant_id] != "-1"
    cond << "users.first_name LIKE '%#{options[:s_first_name].to_s}%'" if options[:s_first_name].present?
    cond << "users.username LIKE '%#{options[:s_username].to_s}%'" if options[:s_username].present?
    cond << "users.last_name LIKE '%#{options[:s_last_name].to_s}%'" if options[:s_last_name].present?
    cond << "users.clientid LIKE '%#{options[:s_clientid].to_s}%'" if options[:s_clientid].present?
    if current_user_usertype == 'manager' && current_user.show_only_assigned_users?
      cond << "users.responsible_accountant_id = #{current_user.id}"
    end
    joins = []
    joins << 'LEFT JOIN addresses ON (users.address_id = addresses.id)'
    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'

    group_by = nil

    if options[:sub_s].to_i > -1
      group_by = 'users.id'
    end

    User.select(select.join(', ')).joins(joins.join(' ')).where(cond.join(' AND ')).group(group_by)
  end

  def nice_user
    if self.first_name.to_s.length + self.last_name.to_s.length > 0
      "#{self.first_name} #{self.last_name}"
    else
      self.username.to_s
    end
  end

  def self.strong_password?(password)
    # /^(?=.*\d)(?=.*\p{Lu})(?=.*\p{Ll}).+$/ Explained:
    #   \d - numbers from range [0-9]
    #   \p - unicode characters {Lu} - uppercase, {Ll} - lowercase
    if self.use_strong_password?
      return true if /\p{Hebrew}|\p{Arabic}/ =~ password
      /^(?=.*\d)(?=.*\p{Lu})(?=.*\p{Ll}).+$/ =~ password ? true : false
    else
      true
    end
  end

  def  validate_company_emails
    unless Email.address_validation(main_email)
      errors.add(:main_email, _('enter_correct_main_email'))
    end

    # Email Unique Validation
    # if main_email.present?
    #   not_self = "id != '#{self.id}'" unless id.nil?
    #   main_email_all = User.where("#{not_self}").pluck(:main_email)
    #   emails = main_email.split(';').reject(&:blank?)
    #
    #   addressses = []
    #
    #   main_email_all.each do |email|
    #     addressses << email.to_s.downcase.split(';').reject(&:blank?)
    #   end if main_email_all.present?
    #
    #   splitted_emails = addressses.flatten.collect(&:strip)
    #
    #   emails.each do |mail|
    #     mail.gsub!(/\s+/, '')
    #     if splitted_emails.include?(mail.downcase)
    #       errors.add(:email, _('Email_space') + mail + _('Is_already_used'))
    #     end
    #   end
    # end

    unless Email.address_validation(noc_email)
      errors.add(:noc_email, _('enter_correct_noc_email'))
    end

    unless Email.address_validation(billing_email)
      errors.add(:billing_email, _('enter_correct_billing_email'))
    end

    unless Email.address_validation(rates_email)
      errors.add(:rates_email, _('enter_correct_rates_email'))
    end
  end

  def self.use_strong_password?
    Confline.get_value('Use_strong_passwords_for_users', 0).to_i == 1 || Confline.get_value('Use_strong_passwords_for_users', 0).blank?
  end

  def tariff_belongs_to_user?(tariff)
    # Lets check if tariff belongs to one of the users devices
    self.devices.pluck(:op_tariff_id, :tp_tariff_id).flatten!.include?(tariff.id)
  end

  def monitor_password
    self.password_changed_at = Time.zone.now.to_i if Confline.get_value('logout_on_password_change').to_i == 1
  end

  def active_calls_count(hide_older_than, only_answered = false)
    return Activecall.count_calls(hide_older_than, only_answered, self) if is_admin? || is_manager?

    cond =  " AND DATE_ADD(activecalls.start_time, INTERVAL #{hide_older_than.to_i} HOUR) > NOW()"
    cond << ' AND activecalls.answer_time IS NOT NULL' if only_answered

    Activecall
      .joins('LEFT JOIN devices ON devices.id = activecalls.dst_device_id')
      .joins('LEFT JOIN users ON users.id = devices.user_id')
      .where("(activecalls.user_id = ? OR users.id = ?) #{cond} AND activecalls.active = 1", id, id)
      .count
  end

  def self.check_responsability(id)
    return true unless current_user.show_only_assigned_users?
    User.find_by(id: id.to_i, responsible_accountant_id: current_user)
  end

  def custom_invoice_xlsx_template_enabled?
    Confline.get_value('custom_invoice_xlsx_template_for_this_user', id).to_i == 1
  end

  def custom_invoice_xlsx_template_file_location
    "public/invoice_templates/custom_user_template_#{id}.xlsx"
  end

  def custom_invoice_xlsx_template_file_exist?
    File.exists?(custom_invoice_xlsx_template_file_location)
  end

  def custom_invoice_xlsx_template_preparation
    if custom_invoice_xlsx_template_enabled? && custom_invoice_xlsx_template_file_exist?
      ["#{Actual_Dir}/#{custom_invoice_xlsx_template_file_location}", id]
    else
      ["#{Actual_Dir}/public/invoice_templates/default.xlsx", 0]
    end
  end

  def authorize_manager_fn_permissions(options = {})
    ManagerGroupRight.manager_permissions(self).find { |right| right[:functionality] == options[:fn].to_sym }.present?
  end

  def authorize_manager_fn_permissions_with_access_level(options = {})
    ManagerGroupRight.manager_permissions(self).find { |right| right[:functionality] == options[:fn].to_sym  && right[:access_level] == options[:ac] }.present?
  end

  def show_only_assigned_users?
    is_manager? && authorize_manager_fn_permissions({fn: :show_only_assigned_users})
  end

  def assign_user_personal_details(user_settings, date, p_address)
    # General
    assign_username(user_settings[:username])
    user_password = user_settings[:password]
    assign_user_password(user_password) if user_password.present?
    self.currency_id = user_settings[:currency_id].try(:to_i)
    self.time_zone = user_settings[:time_zone].to_s

    # Warning balance
    assign_attributes({ warning_email_active: user_settings[:warning_email_active].try(:to_i),
                        warning_email_balance: user_settings[:warning_email_balance],
                        warning_email_hour: (user_settings[:warning_email_hour].to_i != -1) ? date[:hour].to_i : -1,
                      })

    # Fraud protection
    assign_fraud_protection_attributes(user_settings) if allow_customer_to_edit.to_i == 1

    # Company emails
    self.main_email = user_settings[:main_email].to_s.strip if user_settings[:main_email].present?
    self.noc_email = user_settings[:noc_email].to_s.strip if user_settings[:noc_email].present?
    self.billing_email = user_settings[:billing_email].to_s.strip if user_settings[:billing_email].present?
    self.rates_email = user_settings[:rates_email].to_s.strip if user_settings[:rates_email].present?

    validate_company_emails

    # Details
    assign_attributes({ first_name: user_settings[:first_name].try(:to_s).try(:strip),
                        last_name: user_settings[:last_name].try(:to_s).try(:strip),
                        clientid: user_settings[:clientid].try(:to_s).try(:strip),
                        taxation_country: user_settings[:taxation_country].try(:to_i),
                        vat_number: user_settings[:vat_number].try(:strip)
                      })
    # Registration Address
    if address
      address.update_attributes(p_address.each_value(&:strip!)) if p_address
    else
      new_address = Address.create(p_address.each_value(&:strip!)) if p_address
      self.address_id = new_address.id
    end
  end

  def assign_fraud_protection_attributes(params, allow_to_edit = false)
    assign_attributes({ enforce_daily_limit: params[:enforce_daily_limit].to_i,
                        daily_spend_limit: params[:daily_spend_limit].to_d,
                        daily_spend_warning: params[:daily_spend_warning].to_d,
                        kill_calls_in_progress: params[:kill_calls_in_progress].to_i,
                        show_daily_limit: params[:show_daily_limit].to_i
                     })
    self.allow_customer_to_edit = params[:allow_customer_to_edit].to_i if allow_to_edit
  end

  def self.fraud_protection_reset
    MorLog.my_debug("Fraud Protection reset - start", true)
    # First time reset
    ActiveRecord::Base.connection.execute(
      "UPDATE users SET daily_spend_limit_last_reset_at = NOW(), changes_present = 1
       WHERE daily_spend_limit_last_reset_at IS NULL AND enforce_daily_limit = 1;"
    )

    # Select users to reset daily limits
    users = User.select(:id, :time_zone, :daily_spend_limit_reached,
                        :daily_spend_warning_reached, :daily_spend_warning_email_sent,
                        :daily_spend_limit_last_reset_at, :kill_calls_in_progress_flag
                       )
                .where(enforce_daily_limit: 1).all

    # Filter if 00(in user tz) or 24h passed since the last reset
    user_ids = users.reject {|user| Time.now.in_time_zone(user.time_zone).hour > 0 && user.daily_spend_limit_last_reset_at > 24.hours.ago}
    user_ids = user_ids.map(&:id)
    MorLog.my_debug("Found users: #{user_ids.size}", true)

    if user_ids.present?
      # Reset values
      MorLog.my_debug("Reseting values for users", true)
      ActiveRecord::Base.connection.execute(
        "UPDATE users
         SET daily_spend_limit_reached = 0, daily_spend_warning_reached = 0,
             daily_spend_warning_email_sent = 0, daily_spend_limit_last_reset_at = NOW(),
             kill_calls_in_progress_flag = 0, changes_present = 1
         WHERE id IN(#{user_ids.join(',')});
        "
      )
    end
    MorLog.my_debug("Fraud Protection reset - end", true)
  end

  def self.users_kill_calls_in_progress
    MorLog.my_debug("Fraud Protection kill calls in progress - start", true)
    users = User.select(:id, :kill_calls_in_progress_flag)
                .where(kill_calls_in_progress: 1, daily_spend_limit_reached: 1, kill_calls_in_progress_flag: 0, enforce_daily_limit: 1).all
    MorLog.my_debug("Found users: #{users.size}", true)
    if users.present?
      MorLog.my_debug("Killing calls for users", true)
      users.each do |user|
        active_calls = Activecall.where("active = 1 AND (user_id = #{user.id} OR provider_id = #{user.id})").all
        unless active_calls.present?
          MorLog.my_debug("No active calls found for user_id #{user.id}. Skipping...", true)
          user.update_column(:kill_calls_in_progress_flag, 1)
          user.changes_present_set_1
          next
        end
        MorLog.my_debug("Killing calls for user_id #{user.id}", true)
        Activecall.hangup_calls(active_calls)
        user.update_column(:kill_calls_in_progress_flag, 1)
        user.changes_present_set_1
      end
    end
    MorLog.my_debug("Fraud Protection kill calls in progress - end", true)
  end

  def self.send_daily_spend_warning_email
    MorLog.my_debug("Fraud Protection send daily spend warning email - start", true)
    users = User.select(:id, :main_email, :daily_spend_warning_email_sent)
                .where(daily_spend_warning_reached: 1, daily_spend_warning_email_sent: 0, enforce_daily_limit: 1).all
    MorLog.my_debug("Found users: #{users.size}", true)
    if users.present?
      MorLog.my_debug("Sending warning emails for users", true)
      email_template = Email.where(name: 'daily_spend_warning_email', owner_id: 0).first
      email_sender = EmailSender.new
      users.each do |user|
        if user.main_email.blank?
          MorLog.my_debug("blank main_email for user_id #{user.id}. Skipping...", true)
          next
        end
        email_sent = email_sender.send_notification(email_template, user.main_email, user.id)
        if email_sent == _('Email_sent')
          user.update_column(:daily_spend_warning_email_sent, 1)
          user.changes_present_set_1
        end
      end
    end
    MorLog.my_debug("Fraud Protection send daily spend warning email - end", true)
  end

  def fraud_protection_user_reset
    if enforce_daily_limit == 1 && daily_spend_limit_last_reset_at.present? && daily_spend_limit_last_reset_at < 24.hours.ago
      MorLog.my_debug("Reseting fraud proctection for user #{id}", true)
      ActiveRecord::Base.connection.execute(
        "UPDATE users
         SET daily_spend_limit_reached = 0, daily_spend_warning_reached = 0,
             daily_spend_warning_email_sent = 0, daily_spend_limit_last_reset_at = NOW(),
             kill_calls_in_progress_flag = 0, changes_present = 1
         WHERE id = #{id};
        "
      )
    end
  end

  def assign_paypal_settings(params)
    assign_attributes(
      allow_paypal: params[:allow_paypal].to_i,
      paypal_need_approval: params[:paypal_need_approval].to_i,
      paypal_credit_selection: params[:paypal_credit_selection].to_i,
      paypal_fee_selection: params[:paypal_fee_selection].to_i,
      paypal_charge_fee_on_entered_amount: params[:paypal_charge_fee_on_entered_amount].to_d,
      paypal_charge_fee_on_net_amount: params[:paypal_charge_fee_on_net_amount].to_d,
      paypal_do_not_send_confirmation_email: params[:paypal_do_not_send_confirmation_email].to_i
    )
  end

  def allow_paypal?
    allow_paypal == 1
  end

  def two_fa_enabled?
    two_fa_enabled == 1
  end

  def self.bulk_update(params, owner_id)
    update_condition = params.map {|key, value| "#{key.to_s} = #{value}" if value.to_i >= 0 }.compact.join(', ')
    return if update_condition.blank?
    user_id = User.current_user.id
    manager_cond = "AND responsible_accountant_id = #{user_id}" if User.current_user.show_only_assigned_users?
    sql = "UPDATE users SET #{update_condition} where usertype = 'user' AND owner_id = #{owner_id} #{manager_cond.to_s}"
    ActiveRecord::Base.connection.execute(sql)
    Action.add_action_hash(user_id, action: 'users_bulk_update', target_id: owner_id,
                           data: params.map {|key, value| "#{key.to_s}: #{value}" if value.to_i >= 0 }.compact.join(', '),
                           data2: "Users: #{User.current_user.show_only_assigned_users? ? 'Assigned' : 'All'}",
                           target_type: 'user'
                          )
  end

  private

  def save_with_balance
    @save_with_balance_record
  end

  def new_user_balance
    # A.S: To convert set balance to default system currency. #7856
    self.balance		  = self.convert_curr(self.balance)
    self.warning_email_balance = self.convert_curr(self.warning_email_balance)
    self.warning_email_balance_admin = self.convert_curr(self.warning_email_balance_admin)
    self.warning_email_balance_manager = self.convert_curr(self.warning_email_balance_manager)
  end

  def check_min_max_balance
    if self.balance_min and self.balance_max and self.balance_min > self.balance_max
      errors.add(:min_balance, _('minimal_balance_must_be_grater_than_maximal'))
      return false
    end
  end

  def User.financial_status(options)
    users = self.select(:id, :username, :first_name, :last_name, :balance, :balance_min, :balance_max, :warning_email_active, :warning_email_balance, SqlExport.nice_user_sql)
    id, min_balance, max_balance = options[:id], options[:balance_min], options[:balance_max]
    where_sentence = []
    where_sentence << "id = #{id}" if id.present?
    where_sentence << "balance >= #{min_balance}" if min_balance.present?
    where_sentence << "balance <= #{max_balance}" if max_balance.present?
    where_sentence << "owner_id = #{current_user.id} && usertype NOT IN ('admin', 'accountant')"
    if options[:order_by]
      order = options[:order_desc].to_i.zero? ? ' ASC' : ' DESC'
      users = users.order(options[:order_by] + order)
    end
    users = users.where(where_sentence.join(' AND '))
    users
  end

  def sql_for_quick_stats(where_query, current_user_id)
    " SELECT
      aggregates.calls_count, aggregates.duration, aggregates.selfcost,
      aggregates.revenue, (aggregates.revenue - aggregates.selfcost) AS profit
      FROM
      (
        SELECT
          SUM(answered_calls) AS calls_count,
          SUM(CEIL(op_user_billed_billsec)) AS duration,
          SUM(tp_user_billed) AS selfcost,
          SUM(op_user_billed) AS revenue
        FROM aggregates
        JOIN time_periods ON aggregates.time_period_id = time_periods.id
        LEFT JOIN users ON aggregates.op_user_id = users.id
        WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 1 AND users.owner_id = #{current_user_id}
      ) aggregates;"
  end

  def sql_for_selfcost_for_manager(where_query, current_user_id)
    " SELECT sum(op_user_billed) AS selfcost FROM aggregates
      JOIN time_periods ON aggregates.time_period_id = time_periods.id
      WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 1 AND op_user_id = #{current_user_id};"
  end

  def sql_for_quick_stats_user(where_query, current_user_id, billsec_sql)
    " SELECT
      aggregates.calls_count, aggregates.duration, aggregates.selfcost,
      aggregates.revenue, (aggregates.revenue - aggregates.selfcost) AS profit
      FROM
      (
        SELECT
          SUM(answered_calls) AS calls_count,
          SUM(#{billsec_sql}) AS duration,
          SUM(tp_user_billed) AS selfcost,
          SUM(op_user_billed) AS revenue
        FROM aggregates
        JOIN time_periods ON aggregates.time_period_id = time_periods.id
        WHERE time_periods.from_date BETWEEN #{where_query} AND variation = 1 AND op_user_id = #{current_user_id}
      ) aggregates;"
  end

  def es_admin_quick_stats(es_period)
    es_options = {from: es_period[:from], till: es_period[:till]}
    if self.try(:show_only_assigned_users?)
      es_options[:assigned_users] = User.where(responsible_accountant_id: current_user.try(:id)).pluck(:id)
    end
    stats = Elasticsearch.safe_search_m2_calls(es_admin_quick_stats_query(es_options))
    return false if stats.blank?

    calls = stats['hits']['total']
    total_duration = stats['aggregations']['total_billsec']['value']
    total_duration = 0 if total_duration.nil?
    self_cost = stats['aggregations']['total_provider_price']['value']
    revenue = stats['aggregations']['total_user_price']['value']
    profit = revenue - self_cost
    margin = revenue.zero? ? 0 : (profit * 100 / revenue).round
    return calls, total_duration, self_cost, revenue, profit, margin
  end

  def es_user_quick_stats(es_period, user_id, show_user_billsec = false)
    stats = Elasticsearch.safe_search_m2_calls(es_user_quick_stats_query(es_period[:from], es_period[:till], user_id))
    return false if stats.blank?
    stats_aggregations = stats['aggregations']
    calls = stats['hits']['total']
    total_duration = stats_aggregations[(show_user_billsec ? 'user_billsec' : 'total_billsec')]['value']
    total_duration = 0 if total_duration.nil?
    price = stats_aggregations['total_user_price']['value']

    return calls, total_duration, price
  end

  def destroy_automatic_cdr_exports
    AutomaticCdrExport.where(send_to_user_id: id).delete_all
  end

  def assign_username(username)
    self.username = username
    return unless username.to_s.strip.length < minimum_username
    errors.add(:username, _('Username_must_be_longer', (minimum_username - 1)))
  end

  def assign_user_password(user_password)
    bad_password = false
    strong_password = true
    user_password = user_password.to_s.strip
    if user_password.size > 0
      self.password = Digest::SHA1.hexdigest(user_password.to_s.strip)
      bad_password = user_password.present? && user_password.size < minimum_password
      # If passwrod is strong and long enough
      strong_password = user_password.blank? || User.strong_password?(user_password)
    end

    valid_pswd = !bad_password && strong_password
    # Stores a timestamp of the most recent password change. Used for cleaning all user sessions
    monitor_password if valid_pswd
    errors.add(:password, _('Password_must_be_longer', (minimum_password - 1))) if bad_password
    errors.add(:password, _('Password_must_be_strong')) unless strong_password || bad_password
  end
end
