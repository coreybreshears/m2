# Auto Aggregates Export
class AutoAggregateExport < ActiveRecord::Base

  attr_accessible :template_id, :from, :till, :user_id, :recurrence_type, :frequency,
                  :day_of_week, :day, :month, :frequency_type, :name, :email, :next_run_at,
                  :last_run_at, :owner_id, :from_time, :till_time, :period, :period_type, :email_send_time

  validates :name,
            presence: {message: _('Name_cannot_be_blank')},
            uniqueness: {message: _('Name_must_be_unique'), scope: :user_id}

  before_save :custom_validations

  def custom_validations
    errors.add(:template_id, _('Template_must_be_selected')) if template_id < 1

    validate_address
    validate_from_till_time
    validate_agg_period

    case recurrence_type.to_i
      when 1
        validate_daily
      when 2
        validate_weekly
      when 3
        validate_monthly
      when 4
        validate_yearly
      when 5
        validate_hourly
    end

    return false if errors.count > 0
  end

  private

  def validate_daily
    validate_frequency_type
    validate_frequency if first_frequency_type?
  end

  def validate_weekly
    validate_frequency
  end

  def validate_monthly
    validate_frequency_type
    validate_day
    validate_month
  end

  def validate_yearly
    validate_frequency_type
    validate_frequency
    validate_day
  end

  def validate_hourly
    validate_frequency
  end

  def validate_frequency_type
    unless first_frequency_type? || second_frequency_type?
      errors.add(:frequency_type, _('frequency_type_must_be_selected'))
    end
  end

  def validate_day
    errors.add(:day, _('Day_must_be_between_1_and_31')) if day.to_i > 31 || day.to_i < 1
  end

  def shift_frequency_type
    (recurrence_type.to_i - 1) * 10
  end

  def validate_frequency
    errors.add(:frequency, _('frequency_interval_must_be_provided')) if frequency.to_i < 1
  end

  def validate_month
    errors.add(:month, _('Month_must_be_provided')) if month.to_i < 1
  end

  def validate_address
    errors.add(:to, _('Email_or_User_must_be_provided')) if user_id < 0 && email.empty?

    if email.present?
      email.to_s.gsub(',', ';').split(';').each do |email|
        if /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.match(email.strip).blank?
          errors.add(:email, _('invalid_email'))
          break
        end
      end
    end
  end

  def validate_from_till_time
    errors.add(:base, _('agg_invalid_interval')) if from_time > till_time
  end

  def validate_agg_period
    errors.add(:base, _('agg_period_must_be_provided')) if period.to_i <= 0
  end

  def first_frequency_type?
    frequency_type.to_i == (1 + shift_frequency_type)
  end

  def second_frequency_type?
    frequency_type.to_i == (2 + shift_frequency_type)
  end
end