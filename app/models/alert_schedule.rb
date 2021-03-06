# -*- encoding : utf-8 -*-
class AlertSchedule < ActiveRecord::Base
  attr_accessible :id, :name, :status, :comment

  has_many :alert_schedule_periods, dependent: :destroy
  has_many :alert_groups_by_email, class_name: 'AlertGroup', foreign_key: :email_schedule_id

  validates(:name, presence: { message: _('schedule_name_must_be_present') })

  before_destroy :check_groups

  private

  def check_groups
    unless alert_groups_by_email.size.zero?
      errors.add(:groups, _('Is_used_in_groups')) && (return false)
    end
  end
end
