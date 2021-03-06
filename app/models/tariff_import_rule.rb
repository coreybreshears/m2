# Tariff Import v2 rules
class TariffImportRule < ActiveRecord::Base
  extend UniversalHelpers

  attr_protected

  before_destroy :ensure_no_tariff_jobs

  belongs_to :tariff_rate_import_rule
  belongs_to :tariff
  belongs_to :tariff_template
  has_many :tariff_jobs

  before_validation :normalize_attribute_values
  validates :name,
            presence: {message: _('Name_must_be_present')},
            uniqueness: {message: _('Name_must_be_unique')},
            length: {maximum: 100, message: _('Name_cannot_be_longer_than_100')}

  validates :tariff_rate_import_rule_id,
            presence: {message: _('Rate_Import_Rules_must_be_selected')}

  validates :tariff_id,
            presence: {message: _('Target_Tariff_must_be_selected')}

  validates :import_type,
            inclusion: {
                in: %w[add_update replace],
                message: _('Import_Type_is_invalid')
            }

  validates :tariff_template_id,
            presence: {message: _('Import_Template_must_be_selected')}

  validates :effective_date_from,
            inclusion: {
                in: %w[template subject file_name email_body],
                message: _('Effective_Date_is_invalid')
            }

  validates :mail_from,
            presence: {message: _('Mail_From_must_be_present')},
            length: {maximum: 1024, message: _('Mail_From_cannot_be_longer_than_1024')}

  validates :mail_sender, :mail_subject, :mail_text, :file_name,
            allow_blank: true,
            length: {
                maximum: 256,
                message: ->(object, data) do
                  _("#{normalize_validates_message_attribute(data[:attribute])}_cannot_be_longer_than_256")
                end
            }

  validates :trigger_received_email_notification_recipients, :trigger_review_email_notification_recipients,
            :trigger_imported_email_notification_recipients, :trigger_alerts_email_notification_recipients,
            :trigger_rejects_email_notification_recipients, :trigger_rejected_email_notification_recipients,
            allow_blank: true, # Allows to save empty/nil, but subsequent validation disallows it if email is assigned
            length: {
                maximum: 256,
                message: _('Email_Notification_Recipients_cannot_be_longer_than_256')
            }

  validates :default_connection_fee,
            allow_nil: false,
            numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 50000,
                message: _('Import_Rules_default_connection_fee_value_must_be_decimal_between_0_and_50000')
            }

  validates :default_increment,
            allow_nil: false,
            numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 7200,
                message: _('Import_Rules_default_increment_value_must_be_integer_between_0_and_7200')
            }

  validates :default_min_time,
            allow_nil: false,
            numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 7200,
                message: _('Import_Rules_default_min_time_value_must_be_integer_between_0_and_7200')
            }

  validate :ensure_tariff_rate_import_rules_exists, :ensure_tariff_exists, :ensure_tariff_template_exists,
           :ensure_mail_from_valid, :email_notification_recipients_must_be_present_if_notification_assigned,
           :ensure_email_notification_recipients_valid

  before_create :set_lowest_priority
  after_create :update_all_priorities
  after_save :update_all_priorities
  after_update :update_all_priorities
  after_destroy :update_all_priorities

  # Highest priority - 0, Lowest priority - highest value
  scope :lowest_priority, -> { order(priority: :desc).first.try(:priority).to_i }

  def self.tariff_import_rule_select
    pluck(:name, :id)
  end

  private

  def normalize_attribute_values
    %i[
      name effective_date_prefix effective_date_format mail_from mail_sender mail_subject mail_text file_name
      trigger_received_email_notification_recipients trigger_review_email_notification_recipients
      trigger_imported_email_notification_recipients trigger_alerts_email_notification_recipients
      trigger_rejects_email_notification_recipients trigger_rejected_email_notification_recipients
    ].each do |attribute_name|
      self[attribute_name].to_s.strip! if self[attribute_name]
    end

    self.mail_from = '' if self.mail_from.to_s.gsub(';', '').blank?

    if effective_date_from.to_s == 'template'
      self.effective_date_prefix = ''
      self.effective_date_format = ''
    end

    # If value in input box was left empty, then save them in DB as NULL
    %i[
      effective_date_prefix effective_date_format mail_from mail_sender mail_subject mail_text file_name
      trigger_received_email_notification_recipients trigger_review_email_notification_recipients
      trigger_imported_email_notification_recipients trigger_alerts_email_notification_recipients
      trigger_rejects_email_notification_recipients trigger_rejected_email_notification_recipients
    ].each do |attribute_name|
      self[attribute_name] = nil if self[attribute_name].to_s.strip.blank?
    end
  end

  def ensure_tariff_rate_import_rules_exists
    if tariff_rate_import_rule_id.present? && tariff_rate_import_rule.blank?
      errors.add(:tariff_rate_import_rules_were_not_found, _('Rate_Import_Rules_were_not_found'))
    end
  end

  def ensure_tariff_exists
    if tariff_id.present? && tariff.try(:purpose).to_s != 'provider'
      errors.add(:tariff_was_not_found, _('Target_Tariff_was_not_found'))
    end
  end

  def ensure_tariff_template_exists
    if tariff_template_id.present? && tariff_template.blank?
      errors.add(:tariff_template_was_not_found, _('Import_Template_was_not_found'))
    end
  end

  def ensure_mail_from_valid
    if mail_from.present?
      mails = mail_from.to_s.split(';')

      mails.each do |mail|
        mail.gsub!(/\s+/, '')
        # Allows '%', for example: '%@%.%'
        unless mail.match(/^[a-zA-Z0-9_\+%-]+(\.[a-zA-Z0-9_\+%-]+)*@[a-zA-Z0-9%-]+(\.[a-zA-Z0-9%-]+)*\.([a-zA-Z0-9%_]{1,63})$/)
          errors.add(:mail_from_format_is_invalid, _('Mail_From_format_is_invalid'))
          break
        end
      end
    end
  end

  def email_notification_recipients_must_be_present_if_notification_assigned
    %i[
      trigger_received_email_notification trigger_review_email_notification trigger_imported_email_notification
      trigger_alerts_email_notification trigger_rejects_email_notification trigger_rejected_email_notification
    ].each do |notification_name|
      if self["#{notification_name}_id"].present? && self["#{notification_name}_recipients"].to_s.strip.blank?
        errors.add("#{notification_name}_recipients_must_be_present_if_notification_assigned".to_sym, _("#{notification_name}_Recipients_must_be_present"))
      end
    end
  end

  def ensure_email_notification_recipients_valid
    %i[
      trigger_received_email_notification_recipients trigger_review_email_notification_recipients
      trigger_imported_email_notification_recipients trigger_alerts_email_notification_recipients
      trigger_rejects_email_notification_recipients trigger_rejected_email_notification_recipients
    ].each do |recipient|
      if self[recipient].present?
        unless Email.address_validation(self[recipient].to_s)
          errors.add("#{recipient}_Recipients_format_is_invalid".to_sym, _("#{recipient}_Recipients_format_is_invalid"))
        end
      end
    end
  end

  def set_lowest_priority
    self.priority = TariffImportRule.lowest_priority + 1
  end

  def update_all_priorities
    TariffImportRule.all_priority_update
  end

  def ensure_no_tariff_jobs
    if tariff_jobs.exists?
      errors.add(:tariff_jobs_exists, _('Assigned_Tariff_Jobs_exists')) && (return false)
    end
  end

  def ensure_no_active_tariff_jobs
    if active_tariff_jobs_present?
      errors.add(:active_tariff_jobs_exists, _('Assigned_Active_Tariff_Jobs_exists')) && (return false)
    end
  end

  public

  def active_tariff_jobs_present?
    tariff_jobs.where("status NOT IN ('#{TariffJob.completed_statuses.join("', '")}')").exists?
  end

  def change_status
    update_column(:active, (active.to_i == 1 ? 0 : 1))
  end

  def self.all_priority_update(priorities = [])
    return 'invalid' unless priorities.kind_of?(Array)
    priorities.each { |id| return 'invalid' if id.to_s != id.to_i.to_s }
    return 'refresh' if priorities.size != 0 && TariffImportRule.count != priorities.size

    if priorities.present?
      priorities.each_with_index do |tariff_import_rule_id, index|
        ActiveRecord::Base.connection.execute(
          "UPDATE tariff_import_rules SET priority = #{index} WHERE id = #{tariff_import_rule_id}"
        )
      end
    else
      TariffImportRule.select(:id).order(:priority, :id).all.each_with_index do |tariff_import_rule, index|
        ActiveRecord::Base.connection.execute(
          "UPDATE tariff_import_rules SET priority = #{index} WHERE id = #{tariff_import_rule.id}"
        )
      end
    end

    'ok'
  end
end
