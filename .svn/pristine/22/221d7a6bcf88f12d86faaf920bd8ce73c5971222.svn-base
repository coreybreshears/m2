# Tariff Import v2 Template Exceptions
class TariffTemplateException < ActiveRecord::Base
  attr_protected

  belongs_to :tariff_template

  before_validation :normalize_attribute_values
  validates :destination_mask,
            presence: {message: _('Exception_Mask_must_be_present')},
            length: {maximum: 150, message: _('Exception_Mask_cannot_be_longer_than_150')}

  validates :value,
            presence: {message: _('Exception_Value_must_be_present')},
            length: {maximum: 50, message: _('Exception_Value_cannot_be_longer_than_50')}

  private

  def normalize_attribute_values
    %i[destination_mask value].each { |attribute_name| self[attribute_name].to_s.strip! }
  end
end
