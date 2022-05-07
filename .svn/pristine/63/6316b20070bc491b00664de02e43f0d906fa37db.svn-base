# -*- encoding : utf-8 -*-
# Helper for CDR
module CdrHelper
  def clean_value(value)
    value.to_s.gsub("\"", '')
  end

  def nice_cdr_import_error(er)
    case er.to_i
      when 1
        _('CLI_is_not_number')
      when 2
        _('CDR_exist_in_db_match_call_date_dst_src')
      when 3
        _('Destination_is_not_numerical_value')
      when 4
        _('Invalid_calldate')
      when 5
        _('Billsec_is_not_numerical_value')
      when 6
        _('Provider_ID_not_found_in_DB')
      when 7
        _('Invalid_answer_time')
      when 8
        _('Invalid_end_time')
      when 11
        error = _('Invalid_answer_time_format')
      when 12
        error = _('Invalid_end_time_format')
      when 13
        error = _('Invalid_calldate_format')
      when 14
        error = _('Hangup_cause_code_invalid')
      else
        ''
    end
  end

  def tooltip_export_template_columns(template)
    output = ''

    headers = cdr_export_template_column_headers
    template.columns_array.each_with_index do |column, index|
      output << "#{_('Column')} ##{index + 1}: #{headers[column]} <br/>"
    end

    raw output
  end

  def options_for_select_export_template_columns
    output = [['', '']]
    cdr_export_template_column_headers.each { |value, name| output << [name, value] }
    output.sort
  end

  def cdr_export_template_column_headers
    CdrExportTemplate.column_headers
  end

  def settings_options_cdr_templates
    CdrExportTemplate.where("nice_columns != ''").order(:name).all.map { |template| [template.name, template.id] }
  end

  def date_formats
    [
      '%Y-%m-%d %H:%M:%S', '%Y/%m/%d %H:%M:%S', '%Y,%m,%d %H:%M:%S',
      '%Y.%m.%d %H:%M:%S', '%d-%m-%Y %H:%M:%S',
      '%d/%m/%Y %H:%M:%S', '%d,%m,%Y %H:%M:%S', '%d.%m.%Y %H:%M:%S',
      '%m-%d-%Y %H:%M:%S', '%m/%d/%Y %H:%M:%S',
      '%m,%d,%Y %H:%M:%S', '%m.%d.%Y %H:%M:%S'
    ]
  end

  def nice_columns(template)
    array_of_attributes = []
    template.attributes.each do |attribute|
      array_of_attributes << attribute
    end

    columns = array_of_attributes.drop(6)
    nice_columns = []

    columns.each do |column, number|
      nice_columns[number] = column if number && number != -1
    end
    nice_columns
  end

  def tooltip_import_template_columns(template)
    output = ''
    headers = nice_columns(template)
    headers.each_with_index do |column, index|
      output << "#{_('Column')} ##{index + 1}: #{tooltip_headers[column]} <br/>" if column
    end

    raw output
  end

  def tooltip_headers
    {
      'start_time_col' => _('Start_Time'),
      'billsec_col' => _('Billsec'),
      'dst_col' => _('Dst'),
      'answer_time_col' => _('Answer_time'),
      'end_time_col' => _('End_Time'),
      'clid_col' => _('CLID'),
      'src_name_col' => _('Src_name'),
      'src_number_col' => _('Src_number'),
      'duration_col' => _('Duration'),
      'disposition_col' => _('Disposition'),
      'accountcode_col' => _('Accountcode'),
      'provider_id_col' => _('Provider_ID'),
      'cost_col' => _('Cost')
    }
  end

  def select_columns
    output = [['' ,nil]]
    25.times do |index|
      output << ["#{_('Column')} ##{index+1}", index]
    end
    output
  end
end
