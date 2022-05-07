# Tariff Import v2 Tariff Inbox
module TariffInboxHelper
  def attachment_item(email, item, tooltip_title = '', translation = false)
    content = ''
    email.tariff_attachments.each do |attachment|
      items = attachment[item.to_s].to_s.split(' ')
      attachment_item = if translation && attachment[item.to_s].present?
                          "#{_(items[0].split('_').map(&:capitalize).join('_'))} #{items[1]}"
                        else
                          attachment[item.to_s]
                        end

      tooltip_html = tooltip(tooltip_title, attachment_item)
      content += tooltip_title.present? ? "<span #{tooltip_html} class=\"attachment_item#{attachment.id}\">" : '<div>'
      content += attachment_item if attachment_item.present?
      content += "</span><br/><div class=\"attachment_spacing#{attachment.id}\" style=\"display:none;\"></div>"
    end
    content.html_safe
  end

  def import_rules_remapable?(email_id)
    TariffAttachment.remapable_attachments(email_id).blank?
  end

  def limit_emails(emails, fpage)
    emails.limit("#{fpage[:fpage].to_i}, #{session[:items_per_page].to_i}")
  end

  def import_rules(attachment)
    import_rules = TariffJob.select(:tariff_import_rule_id)
                            .where(tariff_attachment_id: attachment.id)
                            .pluck(:tariff_import_rule_id)
    TariffImportRule.where(id: import_rules).all
  end
end
