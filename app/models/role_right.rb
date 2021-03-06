# Role right model
class RoleRight < ActiveRecord::Base

  attr_protected

  belongs_to :role;
  belongs_to :right;
  validates_uniqueness_of :role_id, scope: :right_id

# returns authorization for controller_action
  def RoleRight::get_authorization(role, controller, action)
    #sql = "SELECT role_rights.permission FROM role_rights left join rights ON role_rights.right_id = rights.id left join roles on role_rights.role_id = roles.id WHERE roles.name = '#{role.to_s}' AND rights.controller = '#{controller.to_s}' AND rights.action = '#{action.to_s}';"
    #sql = "SELECT role_rights.permission FROM role_rights where role_id = (select id from roles where name = '#{role.to_s}' LIMIT 1) AND right_id = (SELECT id from rights where controller = '#{controller.to_s}' and rights.action = '#{action.to_s}' LIMIT 1);"
    sql = "SELECT role_rights.permission FROM role_rights where role_id = #{role.to_s} AND right_id = (SELECT id from rights where controller = '#{controller.to_s}' and rights.action = '#{action.to_s}' LIMIT 1);"
    rez = ActiveRecord::Base.connection.select_all(sql)
    if rez.count == 0 && Kernel.const_get(controller.to_s.camelize.to_s + "Controller").new.respond_to?(action.to_s)
      new_right(controller, action, controller.capitalize + "_" + action)
      rez = ActiveRecord::Base.connection.select_all(sql)
    end
    return rez[0]['permission'].to_i if rez[0] && rez[0]['permission']
    0
  end

# returns whole permissions and user roles table
  def RoleRight::get_auth_list
    sql = "SELECT role_rights.id, name, controller, action, permission FROM role_rights left join rights ON role_rights.right_id = rights.id left join roles on role_rights.role_id = roles.id order by controller, action, name;"
    return ActiveRecord::Base.connection.select_all(sql)
  end

  # Adds new right and creates it coresonding enteries for each role
  def RoleRight::new_right(controller, action, description)
    rez = ActiveRecord::Base.connection.select_all("
      SELECT COUNT(*) as num FROM rights where controller = '#{controller}' AND action = '#{action}';"
    )
    if rez[0]['num'].to_i == 0
      right = Right.new(controller: controller.to_s, action: action.to_s, description: description, saved: 1)
      begin
        if right.save
          Role.all.each do |role|
            role_right = RoleRight.new(role_id: role.id, right_id: right.id)
            # 2011-03-18 [2:33:19 PM EEST] MK: tik adminui turi buti 1
            role_right.permission = (%w[admin accountant reseller user].include?(role.name.downcase) ? 1 : 0)
            role_right.save
          end
        end
      rescue => e
        MorLog.my_debug e.to_yaml
      end
    end
  end
end
