# Tariff Import v2 Templates
class TariffTemplate < ActiveRecord::Base
  extend UniversalHelpers

  attr_protected

  has_many :tariff_template_exceptions, dependent: :delete_all
  accepts_nested_attributes_for :tariff_template_exceptions, allow_destroy: true
  validates_associated :tariff_template_exceptions

  has_many :tariff_import_rules

  before_validation :normalize_attribute_values
  validates :name,
            presence: {message: _('Name_must_be_present')},
            uniqueness: {message: _('Name_must_be_unique')},
            length: {maximum: 100, message: _('Name_cannot_be_longer_than_100')}

  validates :header_lines,
            presence: {message: _('Header_Rows_must_be_present')},
            numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                message: _('Header_Rows_must_be_positive_integer')
            }

  validates :currency_exchange_rate,
            allow_nil: true,
            numericality: {
                greater_than_or_equal_to: 0,
                message: _('Currency_must_be_positive_decimal')
            }

  before_destroy :ensure_no_tariff_import_rules
  after_save :generate_template

  private

  def normalize_attribute_values
    %i[
      name header_lines effective_date_format currency_exchange_rate deleted_rates_text blocked_rates_text
    ].each do |attribute_name|
      self[attribute_name].to_s.strip!
    end

    # If value in input box was left empty, then save them in DB as NULL
    %i[
      prefix_column2 prefix_column_secondary prefix_column2_secondary destination_column2 destination_column_secondary
      destination_column2_secondary connection_fee_column connection_fee_column_secondary effective_date_column
      effective_date_column2 effective_date_column_secondary effective_date_column2_secondary
      effective_date_mapping_sheet effective_date_mapping_datetime effective_date_mapping_column_sheet
      effective_date_mapping_column_main effective_date_mapping_sheet_secondary
      effective_date_mapping_datetime_secondary effective_date_mapping_column_sheet_secondary
      effective_date_mapping_column_main_secondary effective_date_format first_interval_rate_column
      first_interval_rate_column_secondary first_interval_mintime_column first_interval_mintime_field
      first_interval_mintime_column_secondary first_interval_mintime_field_secondary
      first_interval_increment_column first_interval_increment_field first_interval_increment_column_secondary
      first_interval_increment_field_secondary off_peak_first_interval_rate_column
      off_peak_first_interval_rate_column_secondary off_peak_first_interval_mintime_column
      off_peak_first_interval_mintime_field off_peak_first_interval_mintime_column_secondary
      off_peak_first_interval_mintime_field_secondary off_peak_first_interval_increment_column
      off_peak_first_interval_increment_field off_peak_first_interval_increment_column_secondary
      off_peak_first_interval_increment_field_secondary second_interval_rate_column
      second_interval_rate_column_secondary second_interval_mintime_column second_interval_mintime_field
      second_interval_mintime_column_secondary second_interval_mintime_field_secondary
      second_interval_increment_column second_interval_increment_field second_interval_increment_column_secondary
      second_interval_increment_field_secondary off_peak_second_interval_rate_column
      off_peak_second_interval_rate_column_secondary off_peak_second_interval_mintime_column
      off_peak_second_interval_mintime_field off_peak_second_interval_mintime_column_secondary
      off_peak_second_interval_mintime_field_secondary off_peak_second_interval_increment_column
      off_peak_second_interval_increment_field off_peak_second_interval_increment_column_secondary
      off_peak_second_interval_increment_field_secondary end_date_column end_date_column_secondary
      currency_exchange_rate deleted_rates_column deleted_rates_text blocked_rates_column blocked_rates_text
      deleted_rates_column_secondary deleted_rates_text_secondary blocked_rates_column_secondary
      blocked_rates_text_secondary import_column_separator
    ].each do |attribute_name|
      self[attribute_name] = nil if self[attribute_name].to_s.strip.blank?
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

  public

  def generate_template
    lines = []
    lines << '# export file settings'
    lines << "import_column_separator=#{import_column_separator.to_s.present? ? import_column_separator : ','}"
    lines << 'export_column_separator=,'
    lines << 'export_decimal_separator=.'
    lines << 'date_format=YYYY-MM-DD'

    selected_exception_columns = tariff_template_exceptions.pluck(:exception_type).uniq

    exported_columns = 'exported_columns=prefix'
    exported_columns << ',destination' if destination_column.present?
    exported_columns << ',connection_fee' if connection_fee_column.present? || connection_fee_column_secondary.present? || selected_exception_columns.include?('connection_fee_change')

    exported_columns << ',first_interval_rate' if first_interval_rate_column.present? || first_interval_rate_column_secondary.present? || selected_exception_columns.include?('first_interval_rate_change')
    exported_columns << ',first_interval_increment' if first_interval_increment_column.present? || first_interval_increment_column_secondary.present? || selected_exception_columns.include?('first_interval_increment_change')
    exported_columns << ',first_interval_mintime' if first_interval_mintime_column.present? || first_interval_mintime_column_secondary.present? || selected_exception_columns.include?('first_interval_mintime_change')

    exported_columns << ',second_interval_rate' if second_interval_rate_column.present? || second_interval_rate_column_secondary.present?
    exported_columns << ',second_interval_increment' if second_interval_increment_column.present? || second_interval_increment_column_secondary.present?
    exported_columns << ',second_interval_mintime' if second_interval_mintime_column.present? || second_interval_mintime_column_secondary.present?

    exported_columns << ',off_peak_first_interval_rate' if off_peak_first_interval_rate_column.present? || off_peak_first_interval_rate_column_secondary.present?
    exported_columns << ',off_peak_first_interval_increment' if off_peak_first_interval_increment_column.present? || off_peak_first_interval_increment_column_secondary.present?
    exported_columns << ',off_peak_first_interval_mintime' if off_peak_first_interval_mintime_column.present? || off_peak_first_interval_mintime_column_secondary.present?

    exported_columns << ',off_peak_second_interval_rate' if off_peak_second_interval_rate_column.present? || off_peak_second_interval_rate_column_secondary.present?
    exported_columns << ',off_peak_second_interval_increment' if off_peak_second_interval_increment_column.present? || off_peak_second_interval_increment_column_secondary.present?
    exported_columns << ',off_peak_second_interval_mintime' if off_peak_second_interval_mintime_column.present? || off_peak_second_interval_mintime_column_secondary.present?

    exported_columns << ',effective_date' if (effective_date_option.to_i == 0 && (effective_date_column.present? || effective_date_column_secondary.present?)) || (effective_date_option.to_i == 1 && ((effective_date_mapping_sheet.present? && effective_date_mapping_datetime.present? && effective_date_mapping_column_sheet.present? && effective_date_mapping_column_main.present?) || (effective_date_mapping_sheet_secondary.present? && effective_date_mapping_datetime_secondary.present? && effective_date_mapping_column_sheet_secondary.present? && effective_date_mapping_column_main_secondary.present?)))

    exported_columns << ',end_date' if end_date_column.present? || end_date_column_secondary.present?

    exported_columns << ',status_blocked' if blocked_rates_column.present? || blocked_rates_column_secondary.present?
    exported_columns << ',status_deleted' if deleted_rates_column.present? || deleted_rates_column_secondary.present?

    lines << exported_columns

    lines << 'prefix_name=Prefix'
    lines << 'destination_name=Destination'
    lines << 'connection_fee_name=Connection Fee'

    lines << 'first_interval_rate_name=Rate'
    lines << 'first_interval_increment_name=Increment'
    lines << 'first_interval_mintime_name=Min. time'

    lines << 'second_interval_rate_name=Second Interval Rate'
    lines << 'second_interval_increment_name=Second Interval Increment'
    lines << 'second_interval_mintime_name=Second Interval Min. time'

    lines << 'off_peak_first_interval_rate_name=Off-Peak First Interval Rate'
    lines << 'off_peak_first_interval_increment_name=Off-Peak First Interval Increment'
    lines << 'off_peak_first_interval_mintime_name=Off-Peak First Interval Min. time'

    lines << 'off_peak_second_interval_rate_name=Off-Peak Second Interval Rate'
    lines << 'off_peak_second_interval_increment_name=Off-Peak Second Interval Increment'
    lines << 'off_peak_second_interval_mintime_name=Off-Peak Second Interval Min. time'

    lines << 'effective_date_name=Effective from'
    lines << 'end_date_name=End Date'

    lines << 'status_blocked=Status Blocked'
    lines << 'status_deleted=Status Deleted'


    lines << '# which sheet to use for data'
    lines << "rate_sheet=#{rate_sheet}"

    lines << '# how many header lines to skip'
    lines << "header_lines=#{header_lines}"


    lines << '# column-row mapping'

    l_prefix_column = 'prefix_column='
    l_prefix_column << prefix_column if prefix_column.present?
    l_prefix_column << "+#{prefix_column2}" if prefix_column.present? && prefix_column2.present?
    lines << l_prefix_column

    l_destination_column = 'destination_column='
    l_destination_column << destination_column if destination_column.present?
    l_destination_column << "+#{destination_column2}" if destination_column.present? && destination_column2.present?
    lines << l_destination_column

    l_connection_fee_column = 'connection_fee_column='
    l_connection_fee_column << connection_fee_column if connection_fee_column.present?
    lines << l_connection_fee_column

    l_first_interval_rate_column = 'first_interval_rate_column='
    l_first_interval_rate_column << first_interval_rate_column if first_interval_rate_column.present?
    lines << l_first_interval_rate_column

    l_first_interval_increment_column = 'first_interval_increment_column='
    l_first_interval_increment_column << first_interval_increment_column if first_interval_increment_column.present?
    l_first_interval_increment_column << "|/|#{first_interval_increment_field.to_i - 1}" if first_interval_increment_column.present? && first_interval_increment_field.present?
    lines << l_first_interval_increment_column

    l_first_interval_mintime_column = 'first_interval_mintime_column='
    l_first_interval_mintime_column << first_interval_mintime_column if first_interval_mintime_column.present?
    l_first_interval_mintime_column << "|/|#{first_interval_mintime_field.to_i - 1}" if first_interval_mintime_column.present? && first_interval_mintime_field.present?
    lines << l_first_interval_mintime_column

    l_second_interval_rate_column = 'second_interval_rate_column='
    l_second_interval_rate_column << second_interval_rate_column if second_interval_rate_column.present?
    lines << l_second_interval_rate_column

    l_second_interval_increment_column = 'second_interval_increment_column='
    l_second_interval_increment_column << second_interval_increment_column if second_interval_increment_column.present?
    l_second_interval_increment_column << "|/|#{second_interval_increment_field.to_i - 1}" if second_interval_increment_column.present? && second_interval_increment_field.present?
    lines << l_second_interval_increment_column

    l_second_interval_mintime_column = 'second_interval_mintime_column='
    l_second_interval_mintime_column << second_interval_mintime_column if second_interval_mintime_column.present?
    l_second_interval_mintime_column << "|/|#{second_interval_mintime_field.to_i - 1}" if second_interval_mintime_column.present? && second_interval_mintime_field.present?
    lines << l_second_interval_mintime_column

    l_off_peak_first_interval_rate_column = 'off_peak_first_interval_rate_column='
    l_off_peak_first_interval_rate_column << off_peak_first_interval_rate_column if off_peak_first_interval_rate_column.present?
    lines << l_off_peak_first_interval_rate_column

    l_off_peak_first_interval_increment_column = 'off_peak_first_interval_increment_column='
    l_off_peak_first_interval_increment_column << off_peak_first_interval_increment_column if off_peak_first_interval_increment_column.present?
    l_off_peak_first_interval_increment_column << "|/|#{off_peak_first_interval_increment_field.to_i - 1}" if off_peak_first_interval_increment_column.present? && off_peak_first_interval_increment_field.present?
    lines << l_off_peak_first_interval_increment_column

    l_off_peak_first_interval_mintime_column = 'off_peak_first_interval_mintime_column='
    l_off_peak_first_interval_mintime_column << off_peak_first_interval_mintime_column if off_peak_first_interval_mintime_column.present?
    l_off_peak_first_interval_mintime_column << "|/|#{off_peak_first_interval_mintime_field.to_i - 1}" if off_peak_first_interval_mintime_column.present? && off_peak_first_interval_mintime_field.present?
    lines << l_off_peak_first_interval_mintime_column

    l_off_peak_second_interval_rate_column = 'off_peak_second_interval_rate_column='
    l_off_peak_second_interval_rate_column << off_peak_second_interval_rate_column if off_peak_second_interval_rate_column.present?
    lines << l_off_peak_second_interval_rate_column

    l_off_peak_second_interval_increment_column = 'off_peak_second_interval_increment_column='
    l_off_peak_second_interval_increment_column << off_peak_second_interval_increment_column if off_peak_second_interval_increment_column.present?
    l_off_peak_second_interval_increment_column << "|/|#{off_peak_second_interval_increment_field.to_i - 1}" if off_peak_second_interval_increment_column.present? && off_peak_second_interval_increment_field.present?
    lines << l_off_peak_second_interval_increment_column

    l_off_peak_second_interval_mintime_column = 'off_peak_second_interval_mintime_column='
    l_off_peak_second_interval_mintime_column << off_peak_second_interval_mintime_column if off_peak_second_interval_mintime_column.present?
    l_off_peak_second_interval_mintime_column << "|/|#{off_peak_second_interval_mintime_field.to_i - 1}" if off_peak_second_interval_mintime_column.present? && off_peak_second_interval_mintime_field.present?
    lines << l_off_peak_second_interval_mintime_column

    l_effective_date_column = 'effective_date_column='
    if effective_date_option.to_i == 0
      l_effective_date_column << effective_date_column if effective_date_column.present?
      l_effective_date_column << "+#{effective_date_column2}" if effective_date_column.present? && effective_date_column2.present?
    elsif effective_date_option.to_i == 1 && (effective_date_mapping_sheet.present? && effective_date_mapping_datetime.present? && effective_date_mapping_column_sheet.present? && effective_date_mapping_column_main.present?)
      l_effective_date_column << "#{effective_date_mapping_sheet}|#{effective_date_mapping_datetime}|#{effective_date_mapping_column_sheet}|#{effective_date_mapping_column_main}"
    end
    lines << l_effective_date_column

    l_end_date_column = 'end_date_column='
    l_end_date_column << end_date_column if end_date_column.present?
    lines << l_end_date_column

    l_status_blocked_column = 'status_blocked_column='
    if blocked_rates_column.present?
      l_status_blocked_column << blocked_rates_column
      l_status_blocked_column << "|#{(blocked_rates_text.present? ? blocked_rates_text : 'blocked')}"
    end
    lines << l_status_blocked_column

    l_status_deleted_column = 'status_deleted_column='
    if deleted_rates_column.present?
      l_status_deleted_column << deleted_rates_column
      l_status_deleted_column << "|#{(deleted_rates_text.present? ? deleted_rates_text : 'deleted')}"
    end
    lines << l_status_deleted_column

    l_prefix_column_secondary = 'prefix_column_secondary='
    l_prefix_column_secondary << prefix_column_secondary if prefix_column_secondary.present?
    l_prefix_column_secondary << "+#{prefix_column2_secondary}" if prefix_column_secondary.present? && prefix_column2_secondary.present?
    lines << l_prefix_column_secondary

    l_destination_column_secondary = 'destination_column_secondary='
    l_destination_column_secondary << destination_column_secondary if destination_column_secondary.present?
    l_destination_column_secondary << "+#{destination_column2_secondary}" if destination_column_secondary.present? && destination_column2_secondary.present?
    lines << l_destination_column_secondary

    l_connection_fee_column_secondary = 'connection_fee_column_secondary='
    l_connection_fee_column_secondary << connection_fee_column_secondary if connection_fee_column_secondary.present?
    lines << l_connection_fee_column_secondary

    l_first_interval_rate_column_secondary = 'first_interval_rate_column_secondary='
    l_first_interval_rate_column_secondary << first_interval_rate_column_secondary if first_interval_rate_column_secondary.present?
    lines << l_first_interval_rate_column_secondary

    l_first_interval_increment_column_secondary = 'first_interval_increment_column_secondary='
    l_first_interval_increment_column_secondary << first_interval_increment_column_secondary if first_interval_increment_column_secondary.present?
    l_first_interval_increment_column_secondary << "|/|#{first_interval_increment_field_secondary.to_i - 1}" if first_interval_increment_column_secondary.present? && first_interval_increment_field_secondary.present?
    lines << l_first_interval_increment_column_secondary

    l_first_interval_mintime_column_secondary = 'first_interval_mintime_column_secondary='
    l_first_interval_mintime_column_secondary << first_interval_mintime_column_secondary if first_interval_mintime_column_secondary.present?
    l_first_interval_mintime_column_secondary << "|/|#{first_interval_mintime_field_secondary.to_i - 1}" if first_interval_mintime_column_secondary.present? && first_interval_mintime_field_secondary.present?
    lines << l_first_interval_mintime_column_secondary

    l_second_interval_rate_column_secondary = 'second_interval_rate_column_secondary='
    l_second_interval_rate_column_secondary << second_interval_rate_column_secondary if second_interval_rate_column_secondary.present?
    lines << l_second_interval_rate_column_secondary

    l_second_interval_increment_column_secondary = 'second_interval_increment_column_secondary='
    l_second_interval_increment_column_secondary << second_interval_increment_column_secondary if second_interval_increment_column_secondary.present?
    l_second_interval_increment_column_secondary << "|/|#{second_interval_increment_field_secondary.to_i - 1}" if second_interval_increment_column_secondary.present? && second_interval_increment_field_secondary.present?
    lines << l_second_interval_increment_column_secondary

    l_second_interval_mintime_column_secondary = 'second_interval_mintime_column_secondary='
    l_second_interval_mintime_column_secondary << second_interval_mintime_column_secondary if second_interval_mintime_column_secondary.present?
    l_second_interval_mintime_column_secondary << "|/|#{second_interval_mintime_field_secondary.to_i - 1}" if second_interval_mintime_column_secondary.present? && second_interval_mintime_field_secondary.present?
    lines << l_second_interval_mintime_column_secondary

    l_off_peak_first_interval_rate_column_secondary = 'off_peak_first_interval_rate_column_secondary='
    l_off_peak_first_interval_rate_column_secondary << off_peak_first_interval_rate_column_secondary if off_peak_first_interval_rate_column_secondary.present?
    lines << l_off_peak_first_interval_rate_column_secondary

    l_off_peak_first_interval_increment_column_secondary = 'off_peak_first_interval_increment_column_secondary='
    l_off_peak_first_interval_increment_column_secondary << off_peak_first_interval_increment_column_secondary if off_peak_first_interval_increment_column_secondary.present?
    l_off_peak_first_interval_increment_column_secondary << "|/|#{off_peak_first_interval_increment_field_secondary.to_i - 1}" if off_peak_first_interval_increment_column_secondary.present? && off_peak_first_interval_increment_field_secondary.present?
    lines << l_off_peak_first_interval_increment_column_secondary

    l_off_peak_first_interval_mintime_column_secondary = 'off_peak_first_interval_mintime_column_secondary='
    l_off_peak_first_interval_mintime_column_secondary << off_peak_first_interval_mintime_column_secondary if off_peak_first_interval_mintime_column_secondary.present?
    l_off_peak_first_interval_mintime_column_secondary << "|/|#{off_peak_first_interval_mintime_field_secondary.to_i - 1}" if off_peak_first_interval_mintime_column_secondary.present? && off_peak_first_interval_mintime_field_secondary.present?
    lines << l_off_peak_first_interval_mintime_column_secondary

    l_off_peak_second_interval_rate_column_secondary = 'off_peak_second_interval_rate_column_secondary='
    l_off_peak_second_interval_rate_column_secondary << off_peak_second_interval_rate_column_secondary if off_peak_second_interval_rate_column_secondary.present?
    lines << l_off_peak_second_interval_rate_column_secondary

    l_off_peak_second_interval_increment_column_secondary = 'off_peak_second_interval_increment_column_secondary='
    l_off_peak_second_interval_increment_column_secondary << off_peak_second_interval_increment_column_secondary if off_peak_second_interval_increment_column_secondary.present?
    l_off_peak_second_interval_increment_column_secondary << "|/|#{off_peak_second_interval_increment_field_secondary.to_i - 1}" if off_peak_second_interval_increment_column_secondary.present? && off_peak_second_interval_increment_field_secondary.present?
    lines << l_off_peak_second_interval_increment_column_secondary

    l_off_peak_second_interval_mintime_column_secondary = 'off_peak_second_interval_mintime_column_secondary='
    l_off_peak_second_interval_mintime_column_secondary << off_peak_second_interval_mintime_column_secondary if off_peak_second_interval_mintime_column_secondary.present?
    l_off_peak_second_interval_mintime_column_secondary << "|/|#{off_peak_second_interval_mintime_field_secondary.to_i - 1}" if off_peak_second_interval_mintime_column_secondary.present? && off_peak_second_interval_mintime_field_secondary.present?
    lines << l_off_peak_second_interval_mintime_column_secondary

    l_effective_date_column_secondary = 'effective_date_column_secondary='
    if effective_date_option_secondary.to_i == 0
      l_effective_date_column_secondary << effective_date_column_secondary if effective_date_column_secondary.present?
      l_effective_date_column_secondary << "+#{effective_date_column2_secondary}" if effective_date_column_secondary.present? && effective_date_column2_secondary.present?
    elsif effective_date_option_secondary.to_i == 1 && (effective_date_mapping_sheet_secondary.present? && effective_date_mapping_datetime_secondary.present? && effective_date_mapping_column_sheet_secondary.present? && effective_date_mapping_column_main_secondary.present?)
      l_effective_date_column_secondary << "#{effective_date_mapping_sheet_secondary}|#{effective_date_mapping_datetime_secondary}|#{effective_date_mapping_column_sheet_secondary}|#{effective_date_mapping_column_main_secondary}"
    end
    lines << l_effective_date_column_secondary

    l_end_date_column_secondary = 'end_date_column_secondary='
    l_end_date_column_secondary << end_date_column_secondary if end_date_column_secondary.present?
    lines << l_end_date_column_secondary

    l_status_blocked_column_secondary = 'status_blocked_column_secondary='
    if blocked_rates_column_secondary.present?
      l_status_blocked_column_secondary << blocked_rates_column_secondary
      l_status_blocked_column_secondary << "|#{(blocked_rates_text_secondary.present? ? blocked_rates_text_secondary : 'blocked')}"
    end
    lines << l_status_blocked_column_secondary

    l_status_deleted_column_secondary = 'status_deleted_column_secondary='
    if deleted_rates_column_secondary.present?
      l_status_deleted_column_secondary << deleted_rates_column_secondary
      l_status_deleted_column_secondary << "|#{(deleted_rates_text_secondary.present? ? deleted_rates_text_secondary : 'deleted')}"
    end
    lines << l_status_deleted_column_secondary


    lines << (effective_date_format.present? ? "effective_date_column_format=#{effective_date_format}" : '#effective_date_column_format=')


    lines << '# data manipulation'
    tariff_template_exceptions.each do |template_exception|
      lines << "#{template_exception.exception_type}=\"#{template_exception.destination_mask}\"|#{template_exception.value}"
    end

    lines << '# new_rate_column'

    update_column(:generated_template, lines.join('\n'))
  end

  def self.valid_headers
    [
        'Prefix', 'Destination', 'Connection Fee', 'Rate', 'Increment', 'Min. time',
        'Second Interval Rate', 'Second Interval Increment', 'Second Interval Min. time',
        'Off-Peak First Interval Rate', 'Off-Peak First Interval Increment', 'Off-Peak First Interval Min. time',
        'Off-Peak Second Interval Rate', 'Off-Peak Second Interval Increment', 'Off-Peak Second Interval Min. time',
        'Effective from', 'End Date', 'Status Blocked', 'Status Deleted'
    ]
  end
end
