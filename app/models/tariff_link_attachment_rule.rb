# Tariff Import v2 Tariff Link Attachment Rules
class TariffLinkAttachmentRule < ActiveRecord::Base
  attr_protected

  validates :name,
            presence: { message: _('Name_cannot_be_blank') },
            uniqueness: { message: _('Name_must_be_unique') }

  validates :string_start,
            uniqueness: { message: _('String_Start_must_be_unique'), scope: [:string_end, :link_pattern] }
  validates :string_end,
            uniqueness: { message: _('String_End_must_be_unique'), scope: [:string_start, :link_pattern] }

  before_create :set_lowest_priority
  after_create :update_all_priorities
  after_save :update_all_priorities
  after_update :update_all_priorities
  after_destroy :update_all_priorities

  scope :lowest_priority, -> { order(priority: :desc).first.try(:priority).to_i }
  scope :ordered_by_priority, -> { order(priority: :asc) }



  def self.all_priority_update(priorities = [])
    return 'invalid' unless priorities.kind_of?(Array)
    priorities.each { |id| return 'invalid' if id.to_s != id.to_i.to_s }
    return 'refresh' if priorities.size != 0 && TariffLinkAttachmentRule.count != priorities.size

    if priorities.present?
      priorities.each_with_index do |tariff_link_attachment_rule_id, index|
        ActiveRecord::Base.connection.execute(
          "UPDATE tariff_link_attachment_rules SET priority = #{index} WHERE id = #{tariff_link_attachment_rule_id}"
        )
      end
    else
      TariffLinkAttachmentRule.select(:id).order(:priority, :id).all.each_with_index do |tariff_link_attachment_rule, index|
        ActiveRecord::Base.connection.execute(
          "UPDATE tariff_link_attachment_rules SET priority = #{index} WHERE id = #{tariff_link_attachment_rule.id}"
        )
      end
    end

    'ok'
  end

  private

  def set_lowest_priority
    self.priority = TariffLinkAttachmentRule.lowest_priority + 1
  end

  def update_all_priorities
    TariffLinkAttachmentRule.all_priority_update
  end
end
