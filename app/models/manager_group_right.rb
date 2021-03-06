# Manager Group Right model
class ManagerGroupRight < ActiveRecord::Base
  attr_protected
  belongs_to :manager_right
  belongs_to :manager_group

  def self.manager_permissions(manager)
    permissions_access_level = self.where(manager_group_id: manager.manager_group_id).all
    manager_permissions = ManagerRight.get_permissions(permissions_access_level)
    return manager_permissions
  end
end
