# -*- encoding : utf-8 -*-
# Device Disconnect Code Changes
class HgcMapping < ActiveRecord::Base
  attr_protected

  before_save :hgc_not_same
  before_save :hgc_incoming_id_unique

  def self.nice_disconnect_code_changes(device_id)
    disconnect_code_changes = self.
        select('hgc_mappings.id AS id, hgc_i.description AS incoming_hgc, hgc_o.description AS outgoing_hgc').
        joins('LEFT JOIN hangupcausecodes AS hgc_i ON hgc_mappings.hgc_incoming_id = hgc_i.id').
        joins('LEFT JOIN hangupcausecodes AS hgc_o ON hgc_mappings.hgc_outgoing_id = hgc_o.id').
        where(device_id: device_id).order('hgc_i.code ASC').all

    return disconnect_code_changes
  end

  private

  def hgc_not_same
    if hgc_incoming_id == hgc_outgoing_id
      errors.add(:hgc_not_same, _('Incoming_and_Outgoing_Disconnect_Codes_must_be_different'))
      return false
    end
  end

  def hgc_incoming_id_unique
    is_hgc_unique = HgcMapping.where(device_id: device_id, hgc_incoming_id: hgc_incoming_id).present?
    if is_hgc_unique
      errors.add(:hgc_not_unique, _('Incoming_Disconnect_Code_must_be_unique'))
      return false
    end
  end
end
