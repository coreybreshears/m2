# Alert model
class Alert < ActiveRecord::Base
  attr_protected

  has_many :alert_dependency, dependent: :destroy, foreign_key: :owner_alert_id
  belongs_to :alert_group
  validates_numericality_of :clear_after, message: _('clear_after_not_numerical')
  validates_numericality_of :hgc, only_integer: true, greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 400, message: _('hgc_must_be_integer_between')
  after_destroy { |alert| AlertDependency.where(alert_id: id).destroy_all }
  after_commit :set_name

  def validation(current_user_id, clear_on_date_blank, alert_dependencies = [])
    clear_after_int = clear_after.to_i
    alert_if_less_equals_zero = alert_if_less == 0
    alert_if_more_equals_zero = alert_if_more == 0
    clear_after_greater_than_zero = clear_after_int > 0
    clear_if_less_equals_zero = clear_if_less == 0
    clear_if_more_equals_zero = clear_if_more == 0
    disable_clear_on = disable_clear == 1

    if check_type == 'origination_point' || check_type == 'termination_point'
      if check_data.present?
        device = Device.where(id: check_data).first
        device_user = device.try(:user)
      end

      errors.add(:check_type, _('device_must_be_selected')) if check_data != 'all' && (!device || !(device_user && device_user.owner_id == current_user_id))
      if check_type_secondary == 'destination' && !check_data_secondary.to_s.strip.match(/\A[0-9%]+\Z/)
        errors.add(:check_type, _('Prefix_was_not_found'))
      end
    end

    if (check_type == 'user') && !%w[all postpaid prepaid].member?(check_data)
      user = User.where(id: check_data, owner_id: current_user_id).first if check_data.present?
      errors.add(:check_type, _('user_must_be_selected')) unless user
    end

    if check_type == 'destination' && !check_data.to_s.strip.match(/\A[0-9%]+\Z/)
      errors.add(:check_type, _('Prefix_was_not_found'))
    end

    if alert_type != 'group'
      if (alert_if_more > clear_if_less && alert_if_less_equals_zero && clear_if_more_equals_zero) ||
         (alert_if_less < clear_if_more && alert_if_more_equals_zero && clear_if_less_equals_zero) ||
         (alert_if_less > alert_if_more && alert_if_more_equals_zero && (disable_clear_on || clear_after_greater_than_zero)) ||
         (alert_if_more > alert_if_less && alert_if_less_equals_zero && (disable_clear_on || clear_after_greater_than_zero))
      else
        if alert_type.to_s == 'price_sum'
          # Skip validation for price sum
        elsif alert_if_more <= clear_if_less && clear_if_less != 0
          errors.add(:alert_if, _('Alert') + ' >= ' + _('must_be_higher_than') + _('Clear') + ' <= ')
        elsif alert_if_less >= clear_if_more && alert_if_less != 0
          errors.add(:alert_if, _('Alert') + ' <= ' + _('must_be_lower_than') + _('Clear') + ' >= ')
        elsif alert_if_more_equals_zero && alert_if_less_equals_zero && clear_if_more_equals_zero && clear_if_less_equals_zero
          errors.add(:alert_if, _('Alert_cannot_be_equal_to_Clear'))
        else
          errors.add(:alert_if, _('logic_error_in_alerts'))
        end
      end
    end

    alert_type_all = alert_type == 'group'

    if alert_dependencies.count < 2 && alert_type_all
      errors.add(:alert_group, _('Alert_group_must_have_more_than_one_alert'))
    end

    if (action_alert_email == 1 || action_clear_email == 1 || action_alert_sms == 1 || action_clear_sms == 1) && alert_groups_id.to_i == 0
      errors.add(:notify, _('group_must_be_selected'))
    end

    if action_alert_sms_text.to_s.size > 160 || action_clear_sms_text.to_s.size > 160
      errors.add(:action_sms_text_too_long, _('Action_SMS_Text_too_long'))
    end

    unless /\A[A-Za-z0-9\s_!"%'()*+,-.\/:<=>?]*\z/.match(action_alert_sms_text.to_s)
      errors.add(:action_alert_sms_text_invalid, _('Invalid_Action_SMS_Text'))
    end

    unless /\A[A-Za-z0-9\s_!"%'()*+,-.\/:<=>?]*\z/.match(action_clear_sms_text.to_s)
      errors.add(:action_clear_sms_text_invalid, _('Invalid_Action_SMS_Text'))
    end

    if clear_after_int < 0 || clear_after_int > 200000
      errors.add(:notify, _('clear_after_notice'))
    end

    if disable_clear != 1
      if clear_on_date == false
        clear_on_date = nil
        errors.add(:notify, _('Wrong_date_format'))
      elsif clear_on_date.present? && clear_on_date < Time.now
        errors.add(:notify, _('Clear_on_date_in_past'))
      elsif (1..4).include?(clear_on_date_blank)
        errors.add(:notify, _('Clear_on_date_values'))
      end
    end
    if alert_type_all
      alert_dependencies.each do |alert|
        alert.owner_alert_id = id
        if Alert.find(alert.alert_id).check_type != check_type
          errors.add(:notify, _('dependencies_must_have_the_same_object_type'))
          break
        end
        if AlertDependency.cycle_exists?(alert)
          errors.add(:notify, _('cycle_exists_in_your_alert_groups'))
          break
        end
      end
    end

    errors.blank?
  end

  def self.alerts_order_by(options)
    option_order_by = options[:order_by].to_s

    case option_order_by.strip
    when 'id'
      order_by = 'id'
    else
      order_by = option_order_by
    end

    if order_by != ''
      order_by << ((option_order_by.to_i == 0) ? ' ASC' : ' DESC')
    end

    order_by
  end

  def apply_limitations
    min = 0.0
    min = -9999999 if alert_type.to_s == 'price_sum'
    max = 100 if %w[asr].member?(alert_type)
    max = 600 if %w[acd].member?(alert_type)
    max = 30.0 if %w[pdd ttc].member?(alert_type)
    max = 9999999 if %w[billsec_sum].member?(alert_type)
    max = 99999 if %w[calls_total calls_answered calls_not_answered sim_calls price_sum].member?(alert_type)
    max = 400 if %w[hgc_absolute hgc_percent].member?(alert_type)
    max_second = 100000

    alert_if_less_dec = alert_if_less.to_d
    alert_if_more_dec = alert_if_more.to_d
    clear_if_less_dec = clear_if_less.to_d
    clear_if_more_dec = clear_if_more.to_d
    ignore_if_calls_less_dec = ignore_if_calls_less.to_d
    ignore_if_calls_more_dec = ignore_if_calls_more.to_d

    return if alert_type == 'group'
    self.alert_if_less = min if alert_if_less_dec < min || alert_if_less.to_s == ''
    self.alert_if_less = max if alert_if_less_dec > max
    self.alert_if_more = min if alert_if_more_dec < min || alert_if_more.to_s == ''
    self.alert_if_more = max if alert_if_more_dec > max
    self.clear_if_less = min if clear_if_less_dec < min || clear_if_less.to_s == ''
    self.clear_if_less = max if clear_if_less_dec > max
    self.clear_if_more = min if clear_if_more_dec < min || clear_if_more.to_s == ''
    self.clear_if_more = max if clear_if_more_dec > max
    self.clear_after = 0 if clear_after.blank?
    self.ignore_if_calls_less = min if ignore_if_calls_less_dec < min || ignore_if_calls_less.to_s == ''
    self.ignore_if_calls_less = max_second if ignore_if_calls_less_dec > max_second
    self.ignore_if_calls_more = min if ignore_if_calls_more_dec < min || ignore_if_calls_more.to_s == ''
    self.ignore_if_calls_more = max_second if ignore_if_calls_more_dec > max_second
  end

  def self.schedule_update(schedule, periods)
    err = []
    schedule.alert_schedule_periods.each do |period|
      period_id = period.id.to_s
      period_fields = periods[period_id]
      next unless period_fields.is_a? Hash

      periods.try(:delete, period_id)
      if period_fields['start']
        period_start = period_fields[:start]
        period.start = period.start.change(hour: period_start[:hour], min: period_start[:minute])
      end
      if period_fields['end']
        period_end = period_fields[:end]
        period.end = period.end.change(hour: period_end[:hour], min: period_end[:minute])
      end

      err << _('invalid_period') unless period.save
    end

    periods.try(:each) do |_, values|
      tmp = schedule.alert_schedule_periods.new
      values_start = values[:start]
      values_end = values[:end]
      tmp.start = tmp.start.change(hour: values_start[:hour], min: values_start[:minute])
      tmp.end	= tmp.end.change(hour: values_end[:hour], min: values_end[:minute])
      tmp.day_type = values[:day_type]

      err << _('invalid_period') unless tmp.save
    end

    err
  end

  def self.group_update(group)
    group.email_schedule_id = 0 if group.email_schedule_id.to_i <= 0
    group
  end

  def self.group_add(new_group)
    new_group.email_schedule_id = 0 if new_group.email_schedule_id.to_i <= 0
    new_group
  end

  def self.new_schedule(params)
    last_fake	= "#{AlertSchedulePeriod.last.try(:id).to_i + 1}#{Time.now.to_i}"
    js_new = AlertSchedulePeriod.new

    start_hour = params[:start_hour].to_i
    start_min	= params[:start_min].to_i
    end_hour = params[:end_hour].to_i
    end_min = params[:end_min].to_i

    js_new.start = js_new.start.change(hour: start_hour, min: start_min)
    js_new.end = js_new.end.change(hour: end_hour, min: end_min)

    js_new[:id] = last_fake
    js_new[:day_type] = params[:day_type]

    js_new
  end

  def set_name
    return if name.present?
    self.name = "Alert_#{id}"
    save
  end

  def tp_dial_peers
    dial_peers_select = [[_('None'), 0]]
    dial_peers = []
    dial_peers = DialPeer.all.pluck(:name, :id) if check_data == 'all'
    dial_peers = Device.where(id: check_data.to_i).first.try(:dial_peers).pluck(:name, :id) if check_data.to_i > 0
    dial_peers_select + dial_peers
  end
end
