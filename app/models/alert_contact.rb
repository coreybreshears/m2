# AlertContact model
class AlertContact < ActiveRecord::Base
  has_many :alert_contact_groups
  attr_accessible :name, :status, :timezone, :email, :max_emails_per_hour,
                  :emails_this_hour, :max_emails_per_day, :emails_this_day,
                  :phone_number, :comment

  validates :name, presence: {message: _('contact_name_must_be_provided')}
  validates(:max_emails_per_day,
            presence: true,
            numericality: {message: _('max_emails_day_must_be_numerical')}
           )
  validates(:max_emails_per_hour,
            presence: true,
            numericality: {message: _('max_emails_hour_must_be_numerical')}
           )
  validates(:email,
            format: {with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, message: _('invalid_email')}
           )
  validates :phone_number,
            allow_blank: true,
            format: {with: /\A(\d+)\Z/i, message: _('Invalid_Number_for_SMS')}


  before_save lambda { name.try(:strip!) }
  before_destroy :check_groups

  private

  def check_groups
    return if alert_contact_groups.count.zero?
    errors.add(:goups, _('contact_is_used_in_groups')) && (return false)
  end
end
