# Dial Peers model
class DialPeer < ActiveRecord::Base

  attr_protected

  attr_accessor :destination_by, :destination_group

  has_many :rgroup_dpeers
  has_many :dpeer_tpoints, dependent: :destroy
  has_many :devices, through: :dpeer_tpoints
  has_many :routing_groups, through: :rgroup_dpeers
  has_one :tp_deviation, dependent: :destroy

  before_validation :set_defaults
  before_destroy :validate_delete

  after_create :dial_peer_data_changed
  after_save :dial_peer_data_changed?
  after_destroy :dial_peer_data_changed

  validates_presence_of :name, message: _('dial_peer_must_have_name')
  validates_length_of :name, maximum: 100, message: _('dial_peer_name_is_to_long')
  validates_numericality_of :minimal_rate_margin, message: _('Minimal_margin_must_be_decimal_number'), allow_nil: true
  validates_numericality_of :minimal_rate_margin_percent, message: _('Minimal_margin_percent_must_be_decimal_number'), allow_nil: true
  validates_numericality_of :call_limit, message: _('Call_Limit_must_be_integer'), only_integer: true
  validates :dst_mask, presence: {message: _('Destinations_mask_must_be_written'), if: lambda{@destination_by == 'tariff_id'}}, allow_blank: false

  before_save :handle_destination_by, :validate_regexp

  def validate_regexp
    [self.src_regexp, self.src_deny_regexp, self.dst_regexp, self.dst_deny_regexp].each { |regexp|
      begin
        Regexp.new(regexp.to_s.strip)
      rescue RegexpError => e
        errors.add(:dial_peer_regexp, _('Invalid_regexp') + ' - ' + e.to_s)
      end
    }

    return errors.size > 0 ? false : true
  end

  def handle_destination_by
    if self.destination_by == 'tariff_id'
      self.dst_regexp = nil
    else
      self.dst_mask = ''
    end
  end

  def dial_peer_data_changed?
    dial_peer_data_changed if self.changed_attributes.present?
  end

  def dial_peer_data_changed
    self.routing_groups.each { |routing_group| routing_group.device_op_routing_group_changed }
    changes_present_set_1
  end

  def changes_present_set_1
    update_column(:changes_present, 1) if persisted?
  end

  def set_defaults
    self.minimal_rate_margin = nil unless self.minimal_rate_margin
    self.minimal_rate_margin_percent = nil unless self.minimal_rate_margin_percent
    self.call_limit = 0 unless self.call_limit
  end

  def validate_delete
    if RgroupDpeer.exists?(dial_peer_id: self.id)
      errors.add(:rgroup, _('dial_peer_is_used_in_routong_group'))
    end

    alert_action_alert = Alert.exists?(enable_tp_in_dial_peer: id)
    alert_action_clear = Alert.exists?(disable_tp_in_dial_peer: id)
    if alert_action_alert || alert_action_clear
      errors.add(:rgroup, _('dial_peer_is_used_in_alerts'))
    end

    return errors.size > 0 ? false : true
  end

  #Overrides for default accessor behaviour
  def destination_by
    @destination_by ||= self.dst_mask.present? ? 'tariff_id' : 'regexp'
  end

  def update_minimal_margins(params)
    self.minimal_rate_margin = nil if params[:minimal_rate_margin]
    self.minimal_rate_margin_percent = nil if params[:minimal_rate_margin_percent]
  end

  def update_from_params(dialpeer_attributes)
    update_minimal_margins(dialpeer_attributes)
    assign_attributes(dialpeer_attributes)
    self.no_follow = 0 if dialpeer_attributes[:tp_priority] == 'weight'
    self.tariff_id = 0 if dialpeer_attributes[:destination_by] == 'regexp'
  end

  def active_tps
    Device.select('devices.*')
          .joins(:dpeer_tpoints)
          .where('dpeer_tpoints.active = 1 AND dial_peer_id = ?', id)
          .order(:name)
  end

  def active_dpeer_tpoints
    DpeerTpoint.where(active: 1, dial_peer_id: id)
  end

  def dpeer_tp_active?(device_id)
    dpeer_tpoints.where(device_id: device_id).first.try(:active).to_i == 1
  end

  def self.dial_peer_list(options)
    order_by = options[:order_by].to_s.gsub('tp_priority', 'CAST(tp_priority AS CHAR)')
    DialPeer.select('dial_peers.*, COUNT(dpeer_tpoints.id) AS tp_list')
            .joins('LEFT JOIN dpeer_tpoints ON dial_peers.id = dpeer_tpoints.dial_peer_id')
            .group('dial_peers.id')
            .where('dial_peers.name LIKE ?', options[:wcard])
            .order(order_by)
            .offset(options[:fpage])
            .limit(options[:items_limit])
  end

  def change_action(dp_before)
    return if changes_present == 0
    changed_keys = (dp_before.attributes.to_a - attributes.to_a).to_h.except('id', 'changes_present').keys
    before = dp_before.process_attributes(changed_keys)
    after = process_attributes(changed_keys)
    Action.add_action_hash(0, target_id: id, action: 'Dial Peer Changed', data3: before, data4: after, target_type: 'dial_peer')
  end

  def process_attributes(changed_keys)
    keys_to_truncate = {
      name: 10,
      src_regexp: 10,
      src_deny_regexp: 10,
      dst_regexp: 10,
      dst_deny_regexp: 10,
      comment: 10,
      dst_mask: 10
    }

    # reject fields that haven't been changed
    result = attributes.reject { |key, _| changed_keys.exclude?(key.to_s) }
    # truncate longer values
    keys_to_truncate.each do |key, value|
      next unless result.key?(key.to_s)
      result[key.to_s] = result[key.to_s].to_s.truncate(value, omission: '')
    end
    # join attributes to string field1:value field2:value ...
    DialPeer.map_attributes(result).to_a.map { |attrs| attrs.join(':')}.join(' ')
  end

  def self.map_attributes(attributes)
    result = {}

    attrs = {
      active: 'act', name: 'name', comment: 'cmt', dst_regexp: 'drgxp', dst_deny_regexp: 'ddenrgxp',
      src_regexp: 'srgxp', src_deny_regexp: 'sdenrgxp', weight: 'weight', stop_hunting: 'stph',
      minimal_rate_margin: 'minrm', tp_priority: 'tpp', dst_mask: 'dmsk', tariff_id: 'tariff_id',
      minimal_rate_margin_percent: 'minrmperc', no_follow: 'noflw', skip_failover_routing_group: 'sfrg',
      secondary_tp_priority: 'stpp', call_limit: 'clmt'
    }

    attributes.each { |key, value| result[attrs[key.to_sym]] = value }
    result
  end
end
