# Alert Group model
class AlertGroup < ActiveRecord::Base
  attr_protected

  belongs_to :email_schedule, class_name: 'AlertSchedule', foreign_key: 'email_schedule_id'
  has_many :alert_contact_groups, foreign_key: :alert_group_id, dependent: :destroy
  has_many :alerts, class_name: 'Alert', foreign_key: :alert_groups_id
  validate :one_of_schedules_present

  before_destroy :check_for_alerts

  validates :name, presence: {message: _('group_name_must_be_provided')}
  validates(:max_emails_per_month,
            numericality: {message: _('max_emails_month_must_be_numerical')}
           )
  before_save :check_if_out_of_range

  private

  def check_if_out_of_range
    max_emails_per_month = self.max_emails_per_month.to_s
    max_emails_per_month_int = max_emails_per_month.to_i

    if max_emails_per_month.to_s =~ /[0-9]*/
      self.max_emails_per_month = 0 if max_emails_per_month_int <= 0
      self.max_emails_per_month = 4294967295 if max_emails_per_month_int > 4294967295
    end
  end

  def one_of_schedules_present
    return true unless email_schedule_id.to_i == 0
    errors.add(:schedule, _('at_least_one_schedule_must_be_selected'))
  end

  def check_for_alerts
    return true if alerts.size.zero?
    errors.add(:alert, _('group_is_assigned_to_alert'))
    false
  end
end
