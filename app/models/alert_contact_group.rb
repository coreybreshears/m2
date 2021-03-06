# AlertContactGroup model
class AlertContactGroup < ActiveRecord::Base

  attr_protected

  belongs_to :alert_group
  belongs_to :alert_contact

  validates :alert_group, presence: {message: _('alert_group_must_be_selected') }
  validates :alert_contact, presence: {message: _('alert_contact_must_be_selected') }
end
