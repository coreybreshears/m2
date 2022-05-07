# Tariff Import v2 Tariff Inbox
class DcGroup < ActiveRecord::Base
  attr_protected

  has_many :disconnect_codes, dependent: :delete_all

  validates :name, presence: { message: _('Group_Name_Must_Be_Present') }
  validates :name, uniqueness: { message: _('Group_Name_Must_Be_Unique') }

  after_destroy :reset_devices

  def reset_to_defaults
    return false if id < 2

    if id == 2
      default_codes = DisconnectCode.default.order(code: :asc)
      global_codes = DisconnectCode.global.order(code: :asc)
      return false if default_codes.blank?
      default_codes.each_with_index do |code, index|
        next if global_codes[index].blank?
        global_codes[index].assign_attributes(code.attributes.except('id', 'dc_group_id'))
        global_codes[index].save
      end

      changes_present_set_1 if global_codes.present?
      return true
    end

    disconnect_codes.destroy_all
    changes_present_set_1
    disconnect_codes.blank?
  end

  def changes_present_set_1
    update_column(:changes_present, 1)
  end

  private

  def reset_devices
    sql_op = "UPDATE devices SET op_dc_group_id = 2 where op_dc_group_id = #{id}"
    sql_tp = "UPDATE devices SET tp_dc_group_id = 2 where tp_dc_group_id = #{id}"

    ActiveRecord::Base.connection.execute(sql_op)
    ActiveRecord::Base.connection.execute(sql_tp)
  end
end
