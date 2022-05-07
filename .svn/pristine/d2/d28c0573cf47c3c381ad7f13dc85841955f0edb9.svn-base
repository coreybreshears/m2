# Settings for Jqx Tables on each User and Table individually
class JqxTableSetting < ActiveRecord::Base
  attr_protected

  belongs_to :user

  def self.select_table(user_id, table_identifier, column_visibility = '')
    where(user_id: user_id, table_identifier: table_identifier).first ||
        create(user_id: user_id, table_identifier: table_identifier, column_visibility: column_visibility, column_order: '')
  end
end
