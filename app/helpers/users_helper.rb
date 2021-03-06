# Users Helper
module UsersHelper
  def allow_add_rs_user?
    user_limit = 2
    !reseller? || ((User.where(owner_id: current_user.id).count < user_limit) || (reseller_active? && current_user.own_providers != 1) || reseller_pro_active?)
  end

  def options_for_billing_period(billing_period)
    options_for_select([[_('weekly_mon_sun'), 'weekly'], [_('bi_weekly'), 'bi-weekly'], [_('monthly_1_end'), 'monthly'], [_('Bimonthly_1_end'), 'bimonthly'], [_('Quarterly_1_end'), 'quarterly'], [_('Half_yearly_1_end'), 'halfyearly'], [_('Dynamic'), 'dynamic']], billing_period)
  end

  def user_invoice_grace_period(user, invoice_grace_period)
    invoice_grace_period ? invoice_grace_period : user.invoice_grace_period.to_i
  end

  def user_permission(user, params)
  	admin? && (params[:action] == 'default_user' || ((user.is_user? || user.is_reseller?) && user.owner_id.to_i == 0))
  end

  def dynamic_from_year(time)
    return Date.today.year if time.year > Date.today.year
    time.year
  end

  def digits_used_for_price_select(user)
    options_for_select([[2, 2], [3, 3], [4, 4], [5, 5], [6, 6], [7, 7], [8, 8]], (user.try(:digits_used_for_price) || 6).to_i)
  end

  def user_status_select(user = nil)
    options = [[_('Testing'), 'testing'], [_('Disabled'), 'disabled'],
               [_('Enabled'), 'enabled'], [_('Pending'), 'pending'], [_('Suspended'), 'suspended'],
               [_('Daily_Limit_Exceeded'), 'daily_limit_exceeded'], [_('Vendor'), 'vendor' ]]
    selected_value = if user.present?
                       (user.try(:user_status) || 'testing').to_s
                     else
                       (Confline.get_value('Default_User_user_status') || 'testing').to_s
                     end
    options_for_select(options, selected_value)
  end

  def get_status_name(status = 'testing')
    return 'daily_limit.png' if status == 'daily_limit_exceeded'
    "#{status}.png"
  end
end
