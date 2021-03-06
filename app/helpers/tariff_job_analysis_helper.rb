# Tariff Import v2 Tariff Job Analysis
module TariffJobAnalysisHelper
  def tariff_job_analysis_tooltip_for_list(result)
    non_importable_reasons = if result['non_importable_reasons'].present?
                               result['non_importable_reasons'].split(';').map { |reason| reason.titleize }.join(' <br> ')
                             else
                               '-'
                             end
    rules_and_actions =
        '<table>' \
          '<tr>' \
            "<td>#{_('Rate_Increase')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_rate_increase'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Rate_Decrease')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_rate_decrease'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('New_Rate')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_new_rate'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Oldest_Effective_Date')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_oldest_effective_date'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Maximum_Effective_Date')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_maximum_effective_date'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Max_Increase')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_max_increase'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Max_Decrease')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_max_decrease'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Max_Rate')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_max_rate'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Zero_Rate')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_zero_rate'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Duplicate_Rate')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_duplicate_rate'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Min_Times')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_min_times'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Increments')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right'>#{import_rule_value(result['import_rule_increments'])}</td>" \
          '</tr>' \
          '<tr>' \
            "<td style=\"vertical-align:top\">#{_('Non_Importable_Reasons')}:&nbsp;&nbsp;&nbsp;&nbsp;</td>" \
            "<td align='right' style=\"vertical-align:top\"> #{non_importable_reasons}</td>" \
          '</tr>' \
        '</table>'

    tooltip(_('Import_Rule'), rules_and_actions.html_safe)
  end

  def column_with_errors(results)
    error_class = ''
    return 'tariff_job_analysis_rejected' if results['non_importable'].to_i > 0
    results.reject {|column| column[/^(?!import_rule_).+/]}.each do |_, value|
      error_class = if value == 1 || (error_class == 'tariff_job_analysis_alert' && value != 2)
                      'tariff_job_analysis_alert'
                    elsif value == 2
                      'tariff_job_analysis_rejected'
                    end

      break if error_class == 'tariff_job_analysis_rejected'
    end
    error_class
  end

  def search_present?
    session[:tariff_job_analysis_search].present?
  end

  def import_rule_search_options
    [[_('All'), -1], [_('None'), 0], [_('Alert'), 1], [_('Rejected'), 2]]
  end

  def non_importable_options
    [
        [_('All'), -1],
        [_('None'), 'none'],
        [_('Any'), 'any'],
        [_('Could_Not_Determine_Direction_Code'), 'could_not_determine_direction_code;'],
        [_('Rate_Invalid'), 'rate_invalid;'],
        [_('Effective_From_Invalid'), 'effective_from_invalid;'],
        [_('Prefix_is_not_numeric'), 'prefix_is_not_numeric;']
    ]
  end

  def import_rule_value(import_rule)
    case import_rule
    when 1
      _('Alert')
    when 2
      _('Rejected')
    else
      '-'
    end
  end

  def import_rule_columns
    %w[import_rule_rate_increase import_rule_rate_decrease
       import_rule_new_rate import_rule_oldest_effective_date
       import_rule_maximum_effective_date import_rule_max_increase
       import_rule_max_decrease import_rule_max_rate
       import_rule_zero_rate import_rule_duplicate_rate
       import_rule_min_times import_rule_increments
      ]
  end

  def tariff_name(tariff_job)
    tariff_job.try(:tariff_import_rule).try(:tariff).try(:name)
  end

  def tariff_id(tariff_job)
    tariff_job.try(:tariff_import_rule).try(:tariff_id)
  end

  def tariff_job_analysis_tariff_import_rule_type_nice(type)
    case type.to_s
      when 'add_update'
        "#{_('Add__Update')} #{_('Rates')}"
      when 'replace'
        _('Replace_All_Rates')
      else
        ''
    end
  end
end
