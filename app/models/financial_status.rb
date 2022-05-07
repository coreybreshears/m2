# Financial Status model
class FinancialStatus < ActiveRecord::Base
  attr_protected

  def FinancialStatus.financial_status(options,  users, current_user)
    users = users.select(:id, :username, :first_name, :last_name, :balance, :balance_min, :balance_max, :warning_email_active, :hidden, :warning_email_balance, SqlExport.nice_user_sql)
    id, min_balance, max_balance, accountant = [options[:s_user_id], options[:min_balance], options[:max_balance], options[:s_accountant_id]]
    option_current_user = options[:current_user]
    if [min_balance, max_balance].any? {|var| /^(?!0\d)\d*(\.\d+)?$/ !~ var.to_s}
      return users.none
    end

    where_sentence = []
    default_values = ['-2', '', nil, _('All').downcase]
    where_sentence << "id = #{id}" if id.present? && !default_values.include?(id)
    where_sentence << "balance >= #{min_balance.to_d / options[:exchange_rate]}" if min_balance.present?
    where_sentence << "balance <= #{max_balance.to_d / options[:exchange_rate]}" if max_balance.present?
    where_sentence << "responsible_accountant_id = #{accountant}" if accountant.present? && !default_values.include?(accountant)
    where_sentence << "owner_id = #{current_user} && usertype NOT IN ('admin', 'accountant', 'manager')"
    where_sentence << "hidden = 0"
    if option_current_user.usertype == 'manager' && option_current_user.show_only_assigned_users?
      where_sentence << "responsible_accountant_id = '#{option_current_user.id}'"
    end
    if options[:order_by]
      order = options[:order_desc].to_i.zero? ? ' ASC' : ' DESC'
      users = users.order(options[:order_by] + order)
    end

    where = where_sentence.join(' AND ')
    users = users.where(where)
    return users, where
  end
end