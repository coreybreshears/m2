# PermissionsHelper module
module PermissionsHelper
  def check_selectable_field(name)
    exceptions = %w[users_usage_create1 devices_usage_create1 calls_statistics_usage_active2
                     finances_statistics_usage_active2 various_statistics_usage_active2
                   ]
    exceptions.member?(name) ? false : true
  end
end
