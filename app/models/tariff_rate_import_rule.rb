# Tariff Import v2 Rate import rules
class TariffRateImportRule < ActiveRecord::Base
  extend UniversalHelpers

  attr_protected

  has_many :tariff_import_rules

  before_validation :normalize_attribute_values
  validates :name,
            presence: {message: _('Rate_Import_Rules_Name_must_be_present')},
            uniqueness: {message: _('Rate_Import_Rules_Name_must_be_unique')},
            length: {maximum: 100, message: _('Rate_Import_Rules_Name_cannot_be_longer_than_100')}

  validates :comment,
            length: {maximum: 256, message: _('Rate_Import_Rules_Comment_cannot_be_longer_than_256')}

  validates :rate_increase_value, :rate_decrease_value, :new_rate_value, :rate_deletion_value, :rate_blocked_value,
            allow_nil: true,
            numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 30,
                message: ->(object, data) do
                  _("Rate_Import_Rules_#{normalize_validates_message_attribute(data[:attribute])}_must_be_integer_between_0_and_30")
                end
            }

  validates :oldest_effective_date_value, :maximum_effective_date_value,
            allow_nil: true,
            numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 365,
                message: ->(object, data) do
                  _("Rate_Import_Rules_#{normalize_validates_message_attribute(data[:attribute])}_must_be_integer_between_0_and_365")
                end
            }

  validates :max_increase_value,
            allow_nil: true,
            numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 500,
                message: _('Rate_Import_Rules_max_increase_value_must_be_decimal_between_0_and_500')
            }

  validates :max_decrease_value, :max_rate_value,
            allow_nil: true,
            numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 100,
                message: ->(object, data) do
                  _("Rate_Import_Rules_#{normalize_validates_message_attribute(data[:attribute])}_must_be_decimal_between_0_and_100")
                end
            }

  validates :min_times_value,
            allow_nil: true,
            format: {
                with: /\A(7[0-1][0-9][0-9]|7200|[1-6][0-9][0-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9]|[0-9])(,(7[0-1][0-9][0-9]|7200|[1-6][0-9][0-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9]|[0-9])){0,3}\z/,
                message: ->(object, data) do
                  _("Rate_Import_Rules_#{normalize_validates_message_attribute(data[:attribute])}_format_is_invalid")
                end
            }

  validates :increments_value,
            allow_nil: true,
            format: {
                with: /\A(7[0-1][0-9][0-9]|7200|[1-6][0-9][0-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9]|[1-9])(,(7[0-1][0-9][0-9]|7200|[1-6][0-9][0-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9]|[1-9])){0,3}\z/,
                message: ->(object, data) do
                  _("Rate_Import_Rules_#{normalize_validates_message_attribute(data[:attribute])}_format_is_invalid")
                end
            }

  validates :rate_increase_action, :rate_decrease_action, :new_rate_action, :rate_deletion_action, :rate_blocked_action,
            :oldest_effective_date_action, :maximum_effective_date_action, :max_increase_action, :max_decrease_action,
            :max_rate_action, :zero_rate_action, :duplicate_rate_action, :min_times_action, :increments_action,
            :code_moved_to_new_zone_action,
            inclusion: {
                in: %w[none alert reject\ rate],
                message: ->(object, data) do
                  # This error will never be shown under proper user's usage circumstances,
                  #   that is why there is no translations for it
                  "#{normalize_validates_message_attribute(data[:attribute])} value is invalid"
                end
            }

  validate :rule_values_must_be_present_if_action_is_not_none

  before_destroy :ensure_no_tariff_import_rules

  def numeric_action(action_name)
    case send("#{action_name}_action".to_sym)
      when 'reject rate'
        2
      when 'alert'
        1
      else
        0
    end
  end

  def numeric_action_with_value(action_name)
    [numeric_action(action_name), send("#{action_name}_value".to_sym)]
  end

  private

  def normalize_attribute_values
    %i[name comment min_time_value increments_value].each do |attribute_name|
      self[attribute_name].to_s.strip!
    end

    # If value in input box was left empty, then save them in DB as NULL
    %i[
      rate_increase_value rate_decrease_value new_rate_value rate_deletion_value rate_blocked_value
      oldest_effective_date_value maximum_effective_date_value max_increase_value max_decrease_value max_rate_value
      min_times_value increments_value
    ].each do |attribute_name|
      self[attribute_name] = nil if self[attribute_name].to_s.strip.blank?
    end
  end

  def rule_values_must_be_present_if_action_is_not_none
    %w[
      rate_increase rate_decrease new_rate rate_deletion rate_blocked oldest_effective_date maximum_effective_date
      max_increase max_decrease max_rate min_times increments
    ].each do |rule_name|
      if self["#{rule_name}_action"] != 'none' && self["#{rule_name}_value"].to_s.strip.blank?
        errors.add("#{rule_name}_value_must_be_present".to_sym, _("Rate_Import_Rules_#{rule_name}_value_must_be_present"))
      end
    end
  end

  def ensure_no_tariff_import_rules
    if tariff_import_rules.present?
      errors.add(:assigned_to_tariff_import_rules, _('Assigned_to_Tariff_Import_Rules'))
      false
    else
      true
    end
  end
end
