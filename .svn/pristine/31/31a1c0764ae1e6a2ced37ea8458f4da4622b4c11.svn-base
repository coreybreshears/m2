# MNP Carrier Groups
class MnpCarrierGroup < ActiveRecord::Base

  attr_protected

  has_many :mnp_carrier_codes, dependent: :destroy
  has_many :devices
  validates :name, presence: {message: _('Group_Name_Must_Be_Present')}
  validates_uniqueness_of :name, message: _('Group_Name_Must_Be_Unique')
  before_destroy :check_devices

  after_create  :mnp_cgroup_data_changed
  after_save    :mnp_cgroup_data_changed?
  after_destroy :mnp_cgroup_data_changed

  def mnp_cgroup_data_changed?
    mnp_cgroup_data_changed if self.changed_attributes.present?
  end

  def mnp_cgroup_data_changed
    changes_present_set_1
  end

  def changes_present_set_1
    update_column(:changes_present, 1) if persisted?
  end

  private

  def check_devices
    if devices.present?
      errors.add(:mnp_carrier_group, _('Group_has_assigned_Connection_Points'))
      return false
    end
  end
end
