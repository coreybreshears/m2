# Tariff Import v2 Tariff Inbox
class TariffAttachment < ActiveRecord::Base
  attr_protected
  belongs_to :tariff_email
  has_many :tariff_jobs

  def self.map_attachments
    attachments = where(status: 'waiting_for_analysis')
    return if attachments.blank?

    attachments.each do |attachment|
      return unless TariffAttachment.select(:status).where(id: attachment.id).first.status == 'waiting_for_analysis'
      attachment.update_column(:status, :processing)

      attachment.process_attachment
    end
  end

  def self.remapable_attachments(email_id)
    where("tariff_email_id = #{email_id} AND (status = 'import_rules_not_found' OR status LIKE 'invalid_effective_date__format_for_tariff_import_rules%')")
  end

  def self.remap_attachments(email_id)
    attachments = remapable_attachments(email_id)
    attachments.each { |attachment| attachment.process_attachment }
  end

  def process_attachment
    rules = invalid_effective_date_ids
    if size_bytes.to_i == 0
      self.status = 'size_0'
    else
      apply_rules(rules)
    end
    save
  end

  def assign_import_setting(import_rule_id)
    rule = TariffImportRule.where(id: import_rule_id.try(:to_i)).first
    if rule.present?
      self.status = 'import_rules_found'
      job = TariffJob.build_and_create(rule.id, id)
      self.status = "invalid_effective_date__format_for_tariff_import_rules #{rule.id}" unless job
      save
    end
  end

  def get_tariff_import_rule_id
    return tariff_jobs.first.tariff_import_rule_id if tariff_jobs.present?
    0
  end

  private

  def apply_rules(rule_ids = '')
    rules = TariffImportRule.select(:id, :mail_from, :mail_sender, :mail_subject, :mail_text, :file_name)
                            .where("active = 1 #{ "AND id IN(#{rule_ids})" if rule_ids.present? }")
                            .order(:priority).all
    rule_list = []
    rules.each do |rule|
      froms = rule.mail_from.gsub(';', "';'")
                            .gsub(';', " OR '#{tariff_email.from_email}' LIKE ")
      query = []
      query << "#{ActiveRecord::Base::sanitize("#{tariff_email.from_name}")} LIKE #{ActiveRecord::Base::sanitize("#{rule.mail_sender}")}"
      query << "#{ActiveRecord::Base::sanitize("#{tariff_email.subject}")} LIKE #{ActiveRecord::Base::sanitize("#{rule.mail_subject}")}"
      query << "#{ActiveRecord::Base::sanitize("#{tariff_email.message_plain}")} LIKE #{ActiveRecord::Base::sanitize("#{rule.mail_text}")}"
      query << "#{ActiveRecord::Base::sanitize("#{file_full_name}")} LIKE #{ActiveRecord::Base::sanitize("#{rule.file_name}")}"
      froms = "('#{tariff_email.from_email}' LIKE '#{froms}')"

      tariff_import_rule = TariffImportRule.where("#{froms} AND #{query.join(' AND ')} AND id = #{rule.id}").first
      if tariff_import_rule.present?
        rule_list << tariff_import_rule
        break if tariff_import_rule.stop_processing_more_rules.to_i == 1
      end
    end

    self.status = (rule_list.size > 0) ? 'import_rules_found' : 'import_rules_not_found'

    failed_rules = []
    rule_list.each do |rule|
      job = TariffJob.build_and_create(rule.id, id)
      failed_rules << rule.id unless job
    end

    self.status = if failed_rules.size == 0 && rule_list.present?
                    (rule_list.size == 1) ? 'job_created' : 'jobs_created'
                  elsif failed_rules.size > 0
                    "invalid_effective_date__format_for_tariff_import_rules #{failed_rules.join(',')}"
                  else
                    status
                  end
  end

  def invalid_effective_date_ids
    invalid_date_status = 'invalid_effective_date__format_for_tariff_import_rules '
    self.status.to_s.include?(invalid_date_status) ? self.status.split(invalid_date_status)[1] : ''
  end
end
