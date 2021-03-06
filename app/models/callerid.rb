# -*- encoding : utf-8 -*-
# Devices' CLI
class Callerid < ActiveRecord::Base
  include UniversalHelpers

  belongs_to :device
  attr_accessible :cli, :device_id, :description, :added_at, :banned,
                  :created_at, :updated_at, :ivr_id, :comment

  validate :cli_uniqueness
  validates_presence_of :cli, message: _('Please_enter_details')
  validates_numericality_of :cli, message: _('CLI_must_be_number')
  validates_presence_of :device, message: _('Please_select_user')

  before_destroy :validate_device

  def validate_device
    if self.device.control_callerid_by_cids.to_i == self.id
      self.errors.add(:device, _('CID_is_assigned_to_Device'))
      return false
    end
  end

  def Callerid.create_from_csv(name, options)
    CsvImportDb.log_swap('analize')
    MorLog.my_debug("CSV create_clids_from_csv #{name}", 1)
    options_imp_clid = options[:imp_clid]

    usa_sql = "INSERT INTO callerids (cli, device_id, description, created_at)
    SELECT DISTINCT(replace(col_#{options_imp_clid}, '\\r', '')), '-1', 'this cli created from csv', '#{Time.now.to_s(:db)}'  FROM #{name}
    LEFT JOIN callerids on (callerids.cli = replace(col_#{options_imp_clid}, '\\r', ''))
    WHERE not_found_in_db = 1 and nice_error != 1 and callerids.id is null"
    #MorLog.my_debug usa_sql
    begin
      ActiveRecord::Base.connection.execute(usa_sql)
      ActiveRecord::Base.connection.select_value("SELECT COUNT(DISTINCT(replace(col_#{options_imp_clid}, '\\r', ''))) FROM #{name} WHERE not_found_in_db = 1 and nice_error != 1 ").to_i
    rescue
      0
    end
  end

  def cli_uniqueness
    existing_cli = Callerid.where(cli: self.cli.to_s.gsub(/\s/, '')).where.not(id: self.id.to_i).first
    if existing_cli
      user = existing_cli.device.user
      owner_id = user.try(:owner_id)

      link_nice_user = ->(user) do
        nice_name = nice_user(user)
        "<a href=#{Web_Dir + "/users/edit/#{user.id}"}>#{nice_name}</a>"
      end

      user_current = User.current
      if user_current
        current_user_id = User.current.id.to_i
        if owner_id.to_i == current_user_id
          errors.add(:cli_uniqueness, _('cli_exists_assigned', link_nice_user.call(user)))
        else
          user_owner = User.where(id: owner_id).first
          if user_owner.try(:owner_id).to_i == current_user_id
            errors.add(:cli_uniqueness, _('cli_exists_assigned', link_nice_user.call(user_owner)))
          else
            errors.add(:cli_uniqueness, _('cli_already_exists'))
          end
        end
      end
    end
  end
end
