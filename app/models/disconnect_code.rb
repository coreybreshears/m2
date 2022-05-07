# Tariff Import v2 Templates
class DisconnectCode < ActiveRecord::Base
  attr_protected
  belongs_to :dc_group
  scope :default, -> { where(dc_group_id: 1) }
  scope :global, -> { where(dc_group_id: 2) }

  def self.list_data(options = {})
  	get_codes(options[:dc_group_id])
  end

  def self.get_codes(dc_group_id)
  	codes = default if dc_group_id == 1
  	codes = global if dc_group_id == 2

    if dc_group_id > 2
    	group_codes = select(:id, :code).where(dc_group_id: dc_group_id)
    	global_codes = select(:id).where.not(code: group_codes.pluck(:code))
    							              .where(dc_group_id: 2)
    							              .all.pluck(:id)

    	codes = where(id: global_codes + group_codes.pluck(:id))
    end
    codes.order(code: :asc)
  end

  def changed_from_default?
    default_code = DisconnectCode.default.where(code: code).first
    return false if default_code.blank?
    (default_code.attributes.except('id', 'dc_group_id').to_a - attributes.except('id', 'dc_group_id').to_a).present?
  end

  def global?
    dc_group_id.to_i == 2
  end

  def self.update_code(code, dc_group_id, data)
    code_to_update = where(code: code, dc_group_id: dc_group_id).first

    if code_to_update.blank?
      code_to_update = DisconnectCode.global.where(code: code).first.dup
      code_to_update.id = nil
      code_to_update.dc_group_id = dc_group_id;
    end

    fieldname = data[:field_name].to_s
    if fieldname.present?
      code_to_update[fieldname] = (data[:value].to_i + 1) % 2 if %w[success_when_non_zero_billsec reroute save_cdr].include?(fieldname)
      code_to_update[fieldname] = (data[:value].to_i + 1) % 4 if fieldname == 'pass_reason_header'
    else
      code_to_update.changed_code = data[:changed_code].to_i if data[:changed_code].present?
      code_to_update.changed_reason = data[:changed_reason].to_s if data[:changed_reason].present?
      code_to_update.q850_code = data[:q850_code].to_i if data[:q850_code].present?
    end

    code_to_update.save
    code_to_update.dc_group.changes_present_set_1
    code_to_update
  end

  def reset_global_to_default
    default_code = DisconnectCode.default.where(code: code).first
    assign_attributes(default_code.attributes.except('id', 'dc_group_id'))
    save
    dc_group.changes_present_set_1
    self
  end
end
