# Template for Rate Notification
class RateNotificationTemplate < ActiveRecord::Base
  extend UniversalHelpers

  attr_protected

  has_many :rate_notification_jobs

  before_validation :normalize_attribute_values
  validates :name,
            presence: {message: _('Name_must_be_present')},
            uniqueness: {message: _('Name_must_be_unique')},
            length: {maximum: 100, message: _('Name_cannot_be_longer_than_100')}

  validates :header_rows,
            presence: {message: _('Header_Rows_must_be_present')},
            numericality: {
                only_integer: true,
                greater_than: 0,
                message: _('Header_Rows_must_be_greater_than_0')
            }

  validates :client_row,
            allow_blank: true,
            numericality: {
                only_integer: true,
                greater_than: 0,
                message: _('Client_Row_must_be_greater_than_0')
            }

  validates :currency_row,
            allow_blank: true,
            numericality: {
                only_integer: true,
                greater_than: 0,
                message: _('Currency_Row_must_be_greater_than_0')
            }

  validates :timezone_row,
            allow_blank: true,
            numericality: {
                only_integer: true,
                greater_than: 0,
                message: _('Timezone_Row_must_be_greater_than_0')
            }

  validates :footer_row,
            allow_blank: true,
            numericality: {
                only_integer: true,
                greater_than: 0,
                message: _('Footer_Row_must_be_greater_than_0')
            }

  before_destroy :ensure_not_default, :delete_xlsx_template_file

  def self.list_all
    rate_notification_templates = RateNotificationTemplate.where(name: 'Default').all
    rate_notification_templates.concat(RateNotificationTemplate.where("name != 'Default'").order(:name).all)
  end

  def xlsx_default_file_path
    "#{Actual_Dir}/public/rate_notification_templates/default.xlsx"
  end

  def xlsx_template_file_path
    "#{Actual_Dir}/public/rate_notification_templates/#{id}.xlsx"
  end

  def xlsx_file_path
    if File.exists?(xlsx_template_file_path)
      xlsx_template_file_path
    elsif File.exists?(xlsx_default_file_path)
      xlsx_default_file_path
    else
      false
    end
  end

  def self.default_template
    RateNotificationTemplate.where(name: 'Default').first
  end

  def is_default?
    name.to_s == 'Default'
  end

  def generate_data_file(rate_notification_job, tmp_dir, filename)
    full_path = "#{tmp_dir}/#{filename}"
    return true if File.exist?(full_path)

    require 'templateXL/templateXL/templates/rate_notification'

    xlsx_file = TemplateXL::RateNotification.new(xlsx_file_path, full_path, self, rate_notification_job)
    xlsx_file.populate_data
    xlsx_file.save

    File.exists?(full_path)
  end

  def delete_xlsx_template_file
    `rm -rf "#{xlsx_template_file_path}"` if xlsx_template_file_path
  end

  private

  def normalize_attribute_values
    %i[
      name
      client_row client_column
      currency_row currency_column
      timezone_row timezone_column
      footer_text footer_row footer_column
      destination_group_header_name destination_group_column
      destination_header_name destination_column
      prefix_header_name prefix_column
      rate_header_name rate_column
      effective_from_header_name effective_from_column
      rate_difference_raw_header_name rate_difference_raw_column
      rate_difference_percentage_header_name rate_difference_percentage_column
      connection_fee_header_name connection_fee_column
      increment_header_name increment_column
      minimal_time_header_name minimal_time_column
      billing_terms_header_name billing_terms_column
      status_header_name status_column
      custom_column_1_header_name custom_column_1_column custom_column_1_text
      custom_column_2_header_name custom_column_2_column custom_column_2_text
      custom_column_3_header_name custom_column_3_column custom_column_3_text
      custom_column_4_header_name custom_column_4_column custom_column_4_text
      custom_column_5_header_name custom_column_5_column custom_column_5_text
    ].each do |attribute_name|
      self[attribute_name].to_s.strip!
    end
  end

  def ensure_not_default
    if is_default?
      errors.add(:default_template_must_be_present, _('Default_Template_must_be_present'))
      false
    else
      true
    end
  end
end

