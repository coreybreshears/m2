# Routing group model
class RoutingGroup < ActiveRecord::Base
  attr_protected

  has_many :devices, foreign_key: 'op_routing_group_id'
  has_many :rgroup_dpeers, dependent: :destroy

  validates_presence_of :name, message: _('routing_group_must_have_name')

  after_save :device_op_routing_group_changed?, :routing_group_data_changed?
  after_create :routing_group_data_changed
  after_destroy :routing_group_data_changed

  before_destroy :validate_delete


  def routing_group_data_changed?
    routing_group_data_changed if self.changed_attributes.present?
  end

  def routing_group_data_changed
    changes_present_set_1
  end

  def changes_present_set_1
    update_column(:changes_present, 1) if persisted?
  end

  def device_op_routing_group_changed?
    device_op_routing_group_changed if self.changed_attributes.present?
  end

  def device_op_routing_group_changed
    self.devices.each { |device| device.op_routing_data_changed_set_1 }
  end

  def validate_delete
    op = Device.where('op_routing_group_id = ? OR op_match_rg_id = ? OR (mnp_use = 1 AND mnp_routing_group_id = ?)'\
      ' OR (us_jurisdictional_routing = 1 AND (op_rg_inter = ? OR op_rg_intra = ? OR op_rg_indeter = ?))', *([id] * 6)).first
    errors.add(:device, _('routing_group_is_used_in_device')) if op

    alert_action_alert = Alert.exists?(action_alert_change_routing_group_id: id)
    alert_action_clear = Alert.exists?(action_alert_change_routing_group_id: id)
    errors.add(:device, _('routing_group_is_used_in_alerts')) if alert_action_alert || alert_action_clear

    return (errors.size > 0) ? false : true
  end

  def self.routing_group_list(options)
    ids = RoutingGroup.manager_rg(options[:user])
    RoutingGroup.select('routing_groups.*, COUNT(DISTINCT dial_peers.id) AS grdp, failover_rg.name AS failover_rg_name'\
      ', failover_rg.id AS failover_rg_id, COUNT(failover_dp.id) AS failover_grdp')
                .joins('LEFT JOIN rgroup_dpeers ON (rgroup_dpeers.routing_group_id = routing_groups.id)')
                .joins('LEFT JOIN dial_peers ON (dial_peers.id = rgroup_dpeers.dial_peer_id)')
                .joins('LEFT JOIN routing_groups AS failover_rg '\
                  'ON (failover_rg.id = routing_groups.parent_routing_group_id)')
                .joins('LEFT JOIN rgroup_dpeers AS failover_rg_dpeers'\
                  ' ON (failover_rg_dpeers.routing_group_id = failover_rg.id)')
                .joins('LEFT JOIN dial_peers AS failover_dp ON (failover_dp.id = failover_rg_dpeers.dial_peer_id)')
                .group('routing_groups.id')
                .where("routing_groups.name LIKE ? #{ids}", options[:wcard])
                .order(options[:order_by])
                .offset(options[:fpage])
                .limit(options[:items_limit])
  end

  def self.rg_dropdown(user)
    ids = RoutingGroup.manager_rg(user, true)
    RoutingGroup.where(ids).order('name ASC').all
  end

  def self.manager_rg(user, no_and = false)
    ids = ''
    if user.show_only_assigned_users?
      all_rg_groups = RoutingGroup.select(:id).all.pluck(:id)
      non_assigned_rgs = all_rg_groups - Device.select(:op_routing_group_id).all.pluck(:op_routing_group_id).uniq

      assigned_manager_ids = Device.select(:op_routing_group_id)
                                   .joins('LEFT JOIN users ON users.id = devices.user_id')
                                   .where("users.responsible_accountant_id = #{user.id}")
                                   .all.pluck(:op_routing_group_id).uniq

      ids = non_assigned_rgs + assigned_manager_ids
      ids = ids.present? ? "AND routing_groups.id IN(#{ids.join(',')})" : 'AND routing_groups.id = -1'
      ids = ids.to_s.gsub('AND', '') if no_and
    end
    ids
  end
end
