# -*- encoding : utf-8 -*-
# M2 Managers' Groups (Administrator's helpers)
class ManagerGroup < ActiveRecord::Base
  attr_protected

  has_many :managers
  has_many :manager_group_rights, dependent: :destroy
  has_many :manager_rights, through: :manager_group_rights

  before_validation :remove_whitespaces

  validates :name,
            uniqueness: {message: _('Manager_Group_name_must_be_unique')},
            presence: {message: _('Manager_Group_name_cannot_be_blank')}

  after_create :create_permissions

  before_destroy :no_managers_assigned


  def create_permissions
    ManagerRight.all.each do |permission|
      self.manager_group_rights.create({
                                           manager_right_id: permission.id,
                                           value: 0
                                       })
    end
  end

  def update_rights(rights)
    rights[:USERS_Users_Kill_Calls] = '0' if rights[:USERS_Users].to_i == 0 && Confline.get_value('M4_Functionality').to_i == 1
    rights.map do |name, value|
      manager_right_id = ManagerRight.where(name: name).first.id
      mgr = ManagerGroupRight.where({
                                          manager_group_id: id,
                                          manager_right_id: manager_right_id
                                      }).first
      if mgr.present?
        mgr.value = value
        mgr.save
      else
        ManagerGroupRight.create({manager_group_id: id, manager_right_id: manager_right_id, value: value})
      end
    end
  end

  private

  def remove_whitespaces
    [:name, :comment].each { |value| self[value].to_s.strip! }
  end

  def no_managers_assigned
    unless managers.count.zero?
      errors.add(:managers_assigned, _('it_has_assigned_Managers')) && (return false)
    end
  end
end
