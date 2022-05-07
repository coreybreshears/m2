# -*- encoding : utf-8 -*-
# Assigned Termination points (Connection points) to Dial Peers
class DpeerTpoint < ActiveRecord::Base
  attr_accessible :id, :dial_peer_id, :device_id, :tp_percent, :tp_weight, :warn_about_quality

  belongs_to :dial_peer
  belongs_to :device
  before_validation :set_defaults, on: :create

  validates_numericality_of :device_id,
                            greater_than_or_equal_to: 0,
                            message: _('Dont_Be_So_Smart')
  validates_numericality_of :tp_percent,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            message: _('percent_must_be_number_between_0_100')
  validates_numericality_of :tp_weight,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 100,
                            message: _('weight_must_be_number_between_0_100')
  validates_numericality_of :tp_cps,
                            greater_than_or_equal_to: 0,
                            message: _('cps_must_be_number_greater_than_or_equal_0')
  validates_numericality_of :tp_call_limit,
                            greater_than_or_equal_to: 0,
                            message: _('cps_must_be_number_greater_than_or_equal_0')

  after_create :dialpeer_terminationpoint_data_changed
  after_save :dialpeer_terminationpoint_data_changed?
  after_destroy :dialpeer_terminationpoint_data_changed

  def dialpeer_terminationpoint_data_changed?
    dialpeer_terminationpoint_data_changed if self.changed_attributes.present?
  end

  def dialpeer_terminationpoint_data_changed
    self.dial_peer.dial_peer_data_changed
  end

  def set_defaults
    self.tp_percent = 100 unless self.tp_percent
    self.tp_weight = 1 unless self.tp_weight
  end
end
