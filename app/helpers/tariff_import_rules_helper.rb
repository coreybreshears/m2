# Tariff Import v2 rules
module TariffImportRulesHelper
  def tariff_rate_import_rules_collection
    @tariff_rate_import_rules_collection ||= TariffRateImportRule.order(:name).all
  end

  def buy_tariffs_collection
    @buy_tariffs_collection ||= Tariff.where(purpose: 'provider').order(:name).all
  end

  def tariff_templates_collection
    @tariff_templates_collection ||= TariffTemplate.order(:name).all
  end

  def import_type_selection
    [[_('Add__Update'), 'add_update'], [_('Replace_All_Rates'), 'replace']]
  end

  def tariff_import_rules_effective_date_selection
    [[_('Template___Inline'), 'template'], [_('Subject'), 'subject'],
     [_('Email_Body'), 'email_body'], [_('File_Name'), 'file_name']
    ]
  end

  def email_notifications_collection
    @email_notifications_collection ||= Email.select("emails.id AS id, name, subject, CONCAT(tariff_email_details.filename, ' (', UPPER(tariff_email_details.attachment_type), ')') AS attachment")
                                             .joins('LEFT JOIN tariff_email_details ON tariff_email_details.email_id = emails.id')
                                             .order(:name).all
  end

  def tariff_import_rule_active_status(active)
    active.to_i == 1 ? _('Active') : _('Inactive')
  end

  def tariff_import_rule_type_nice(type)
    case type.to_s
      when 'add_update'
        _('Add__Update')
      when 'replace'
        _('Replace_All_Rates')
      else
        ''
    end
  end

  def tariff_import_rule_effective_date_nice(type)
    case type.to_s
      when 'template'
        _('Template___Inline')
      when 'subject'
        _('Subject')
      when 'file_name'
        _('File_Name')
      when 'email_body'
        _('Email_Body')
      else
        ''
    end
  end

  def tariff_import_rule_active_status_change_links(tariff_import_rule)
    if tariff_import_rule.active.to_i == 1
      link_to(_('_Yes').upcase, {action: :change_status, id: tariff_import_rule}, {method: :post})
    else
      link_to(_('_No').upcase, {action: :change_status, id: tariff_import_rule}, {method: :post, style: 'color:#D8D8D8;'})
    end
  end
end
