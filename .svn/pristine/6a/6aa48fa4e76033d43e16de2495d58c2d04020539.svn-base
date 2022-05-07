# Tariff Import v2 Rate import rules
module TariffRateImportRulesHelper
  def tariff_rate_import_rules_tooltip_for_list(object)
    rules_and_actions =
        '<table>' \
          '<tr>' \
            "<td>#{_('Rate_Increase')}:</td>" \
            "<td align='right'>#{object.try(:rate_increase_value) || '-'}</td>" \
            "<td>#{_('Day_s_')}</td>" \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:rate_increase_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Rate_Decrease')}:</td>" \
            "<td align='right'>#{object.try(:rate_decrease_value) || '-'}</td>" \
            "<td>#{_('Day_s_')}</td>" \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:rate_decrease_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('New_Rate')}:</td>" \
            "<td align='right'>#{object.try(:new_rate_value) || '-'} </td>" \
            "<td>#{_('Day_s_')}</td>" \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:new_rate_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Oldest_Effective_Date')}:</td>" \
            "<td align='right'>#{object.try(:oldest_effective_date_value) || '-'}</td>" \
            "<td>#{_('Day_s_')}</td>" \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:oldest_effective_date_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Maximum_Effective_Date')}:</td>" \
            "<td align='right'>#{object.try(:maximum_effective_date_value) || '-'}</td>" \
            "<td>#{_('Day_s_')}</td>" \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:maximum_effective_date_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Max_Increase')}:</td>" \
            "<td align='right'>#{object.try(:max_increase_value) ? nice_number(object.try(:max_increase_value)) : '-'}</td>" \
            '<td>%</td>' \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:max_increase_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Max_Decrease')}:</td>" \
            "<td align='right'>#{object.try(:max_decrease_value) ? nice_number(object.try(:max_decrease_value)) : '-'}</td>" \
            '<td>%</td>' \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:max_decrease_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Max_Rate')}:</td>" \
            "<td align='right'>#{object.try(:max_rate_value) ? nice_number(object.try(:max_rate_value)) : '-'}</td>" \
            '<td>&nbsp;</td>' \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:max_rate_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Zero_Rate')}:</td>" \
            '<td>&nbsp;</td>' \
            '<td>&nbsp;</td>' \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:zero_rate_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Min_Times_Not_Equal')}:</td>" \
            "<td align='right'>#{object.try(:min_times_value) || '-'}</td>" \
            '<td>&nbsp;</td>' \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:min_times_action).to_s.titleize}</td>" \
          '</tr>' \
          '<tr>' \
            "<td>#{_('Increments_Not_Equal')}:</td>" \
            "<td align='right'>#{object.try(:increments_value) || '-'}</td>" \
            '<td>&nbsp;</td>' \
            "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
            "<td>#{object.try(:increments_action).to_s.titleize}</td>" \
          '</tr>' \
        '</table>'

    # Commented out and moved out of structure, return back, when required
    # '<tr>' \
    #   "<td>#{_('Rate_Deletion')}:</td>" \
    #   "<td align='right'>#{object.try(:rate_deletion_value) || '-'}</td>" \
    #   "<td>#{_('Day_s_')}</td>" \
    #   "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
    #   "<td>#{object.try(:rate_deletion_action).to_s.titleize}</td>" \
    # '</tr>' \
    # '<tr>' \
    #   "<td>#{_('Rate_Blocked')}:</td>" \
    #   "<td align='right'>#{object.try(:rate_blocked_value) || '-'}</td>" \
    #   "<td>#{_('Day_s_')}</td>" \
    #   "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
    #   "<td>#{object.try(:rate_blocked_action).to_s.titleize}</td>" \
    # '</tr>' \
    # '<tr>' \
    #   "<td>#{_('Duplicate_Rate')}:</td>" \
    #   '<td>&nbsp;</td>' \
    #   '<td>&nbsp;</td>' \
    #   "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
    #   "<td>#{object.try(:duplicate_rate_action).to_s.titleize}</td>" \
    # '</tr>' \
    # '<tr>' \
    #   "<td>#{_('Code_Moved_to_New_Zone')}:</td>" \
    #   '<td>&nbsp;</td>' \
    #   '<td>&nbsp;</td>' \
    #   "<td style='padding-left: 20px;'>#{_('Action')}:</td>" \
    #   "<td>#{object.try(:code_moved_to_new_zone_action).to_s.titleize}</td>" \
    # '</tr>' \

    tooltip(_('Rules_and_Actions'), rules_and_actions.html_safe)
  end

  def tariff_rate_import_rules_actions_selection
    [[_('None'), 'none'], [_('Alert'), 'alert'], [_('Reject_Rate'), 'reject rate']]
  end
end
