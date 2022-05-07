# DID tags model
class DidTag < ActiveRecord::Base
  attr_protected

  has_many :did_tag_links, foreign_key: 'tag_id'

  validates :name, presence: { message: _('Name_cannot_be_blank') },
                   uniqueness: { message: _('Name_must_be_unique') }
  validates :color_text, presence: { message: _('Text_Color_cannot_be_blank') }
  validates :color_bg, presence: { message: _('Background_Color_cannot_be_blank') }

  validate :validate_colors

  before_destroy :check_asssigned_dids

  def self.get_tags(options = {})
    all
  end

  def show_tag
    return "<span class=\"did_tag_container\" style=\"color: #{color_text}; background-color: #{color_bg};\">#{name}</span>"
  end

  private

  def validate_colors
    return if color_text.blank? || color_bg.blank?
    errors.add(:matching_color, _('Text_Color_cannot_be_same_as_Background_Color')) if color_text == color_bg
    errors.add(:invalid_color_format, _('Text_Color_invalid_Color_Format')) unless color_text.match(/#([A-Fa-f0-9]{6})$/)
    errors.add(:invalid_color_format, _('Background_Color_invalid_Color_Format')) unless color_bg.match(/#([A-Fa-f0-9]{6})$/)
    errors.blank?
  end

  def check_asssigned_dids
    return unless did_tag_links.present?
    errors.add(:tag_links_present, _('DID_Tag_has_assigned_DIDs'))
    false
  end
end
