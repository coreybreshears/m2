# MNP Prefixes
class MnpPrefix < ActiveRecord::Base

  attr_protected

  validates :prefix, presence: {message: _('Prefix_Must_Be_Present')}
  validates_uniqueness_of :prefix, message: _('Prefix_Must_Be_Unique')
end
