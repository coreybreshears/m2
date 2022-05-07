# -*- encoding : utf-8 -*-
# Translations order
class UserTranslation < ActiveRecord::Base
  belongs_to :user
  belongs_to :translation

  attr_protected

  def self.get_active
    where(active: 1, user_id: User.current.id).all
  end

  def self.translations_change_status(id)
    translation, active_translations = where(id: id).first, self.get_active.to_a.size

    tr_active = translation.active = (translation.active == 1 ? 0 : 1)

    if (tr_active == 0 && active_translations != 1) || tr_active == 1
      translation.save
    end
  end
end
