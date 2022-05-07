# RgroupDpeer model
class RgroupDpeer < ActiveRecord::Base
  attr_protected

  belongs_to :routing_group
  belongs_to :dial_peer

  validates_numericality_of :dial_peer_priority,
                            greater_than_or_equal_to: 0,
                            message: _('priority_must_be_positive_number')

  after_create :device_op_routing_group_changed, :rg_data_changed
  after_save :device_op_routing_group_changed?, :rg_data_changed?
  after_destroy :device_op_routing_group_changed, :rg_data_changed

  def device_op_routing_group_changed?
    device_op_routing_group_changed if self.changed_attributes.present?
  end

  def device_op_routing_group_changed
    self.routing_group.device_op_routing_group_changed
  end

  def rg_data_changed?
    rg_data_changed if self.changed_attributes.present?
  end

  def rg_data_changed
    self.routing_group.routing_group_data_changed
  end

end
