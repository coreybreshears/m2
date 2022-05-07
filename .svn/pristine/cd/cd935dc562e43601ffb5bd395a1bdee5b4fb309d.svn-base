# MNP Carrier Codes
class MnpCarrierCode < ActiveRecord::Base

  attr_protected

  belongs_to :mnp_carrier_group
  validates :code, presence: {message: _('Carrier_Code_Must_Be_Present')}
  validates_uniqueness_of :code, message: _('Carrier_Code_Must_Be_Unique'), scope: :mnp_carrier_group_id

  after_create  :mnpcc_data_changed
  after_save    :mnpcc_data_changed?
  after_destroy :mnpcc_data_changed

  def mnpcc_data_changed?
    mnpcc_data_changed if self.changed_attributes.present?
  end

  def mnpcc_data_changed
    self.mnp_carrier_group.mnp_cgroup_data_changed
 end



end
