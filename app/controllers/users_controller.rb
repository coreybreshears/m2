# Users managing.
class UsersController < ApplicationController
  layout :determine_layout

  include SqlExport

  before_filter :check_post_method,
                only: [
                    :destroy, :create, :update, :update_personal_details, :update_user_personal_details, :logout_user,
                    :get_user_documents, :upload_user_document, :delete_user_document, :bulk_update
               ]

  before_filter :authorize, except: [:users_kill_calls_in_progress, :send_daily_spend_warning_email]
  before_filter :authorize_assigned_users,
                if: -> { current_user.try(:show_only_assigned_users?) },
                except: [:users_kill_calls_in_progress, :send_daily_spend_warning_email]

  before_filter :check_localization, except: [:gdpr_agreed_user_details]
  before_filter :access_denied,
                only: [:users_postpaid_and_allowed_loss_calls, :default_user_errors_list, :kill_all_calls, :delete_user_document],
                if: -> { user? },
                except: [:users_kill_calls_in_progress, :send_daily_spend_warning_email]

  before_filter :access_denied, only: [:bulk_management, :bulk_update], unless: -> { m4_functionality? }
  before_filter :find_user,
                only: [
                    :update, :custom_invoice_xlsx_template, :custom_invoice_xlsx_template_update,
                    :custom_invoice_xlsx_template_download, :gdpr_agreed_user_details, :logout_user,
                    :kill_all_calls, :upload_user_document, :get_user_documents
                ]
  before_filter :find_user_from_session,
                only: [:update_personal_details, :personal_details, :update_user_personal_details]

  before_filter :check_params, only: [:create, :update, :default_user_update]
  before_filter :check_with_integrity,
                only: [
                    :edit, :list, :new, :default_user, :users_postpaid_and_allowed_loss_calls, :default_user_errors_list
                ]

  before_filter :find_responsible_accountants, only: [:edit, :default_user, :new, :create, :update]
  before_filter :check_selected_rs_user_count, only: [:update], unless: -> { reseller_pro_active? }
  before_filter :number_separator, only: [:edit, :update]
  before_filter :find_reseller, only: [:reseller_users]
  before_filter :find_document, only: [:download_user_document, :delete_user_document]

  def index
    redirect_to action: :list and return false
  end

  def list
    @page_title = _('Users')
    @page_icon = 'vcard.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Users'
    @default_currency = Currency.first.try(:name)
    @roles = Role.where(["name !='guest' AND name !='admin'"])

    @options = default_user_options(session[:user_list_stats], true)

    search_params = [
      :user_type, :s_id, :s_agr_number, :s_acc_number, :s_email, :responsible_accountant_id,
      :s_first_name, :s_username, :s_last_name, :s_clientid
    ]

    @search = (search_params.any? { |key| @options[key].present? } || @options[:sub_s].to_i > -1)

    users_number = User.users_for_users_list(@options).all.size

    # page params
    fpage, @total_pages, @options = Application.pages_validator(session, @options, users_number)

    @users = User.users_for_users_list(@options).order(@options[:order])
                 .limit("#{fpage}, #{session[:items_per_page].to_i}").all

    # Mapping accountants(managers as for m2) with appointed users
    @responsible_accountants = User.responsible_acc_for_list

    session[:user_list_stats] = @options
  end

  # @reseller in before filter find_re
  def reseller_users
    @page_title = _('Reseller_users')
    @page_icon = 'vcard.png'

    if (@reseller.own_providers == 0 && !reseller_active?) || (@reseller.own_providers == 1 && !reseller_pro_active?)
      @users = User.where(owner_id: @reseller.id).limit(2)
    else
      @users = @reseller.reseller_users
    end
  end

  def hidden
    @page_title = _('Hidden_users')
    @page_icon = 'vcard.png'
    @default_currency = Currency.first.try(:name)
    @roles = Role.where(["name !='guest'"])

    @options = default_user_options(session[:user_hiden_stats], false)
    owner = correct_owner_id
    cond = ['users.hidden = 1 AND users.owner_id = ?']
    joins, var = [], [owner]
    select = ['users.*', 'tariffs.purpose', "#{SqlExport.nice_user_sql}"]
    add_contition_and_param(@options[:user_type], @options[:user_type], 'users.usertype = ?', cond, var) if @options[:user_type].to_i != -1
    add_contition_and_param(@options[:s_id], @options[:s_id], 'users.id = ?', cond, var) if @options[:s_id].to_i != -1
    add_contition_and_param(@options[:s_agr_number], @options[:s_agr_number].to_s + '%', 'users.agreement_number LIKE ?', cond, var) if @options[:s_agr_number].present?
    add_contition_and_param(@options[:s_acc_number], @options[:s_acc_number].to_s + '%', 'users.accounting_number LIKE ?', cond, var) if @options[:s_acc_number].present?
    add_contition_and_param(@options[:s_email], @options[:s_email].to_s, "(main_email = ? OR noc_email = '#{ActiveRecord::Base::sanitize("#{@options[:s_email]}")[1..-2]}' OR billing_email = '#{ActiveRecord::Base::sanitize("#{@options[:s_email]}")[1..-2]}' OR rates_email = '#{ActiveRecord::Base::sanitize("#{@options[:s_email]}")[1..-2]}')", cond, var) if @options[:s_email].present?
    if current_user.usertype == 'manager' && current_user.show_only_assigned_users?
      current_manager_id = current_user.id
      add_contition_and_param(current_manager_id, current_manager_id, 'users.responsible_accountant_id = ?', cond, var)
    end
    %w(first_name, username, last_name, clientid).each { |col|
      add_contition_and_param(@options["s_#{col}".to_sym], '%' + @options["s_#{col}".intern].to_s + '%', "users.#{col} LIKE ?", cond, var) }

    if @options[:sub_s].to_i > -1
      group_by = 'users.id'
    end

    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'
    joins and joins = joins.empty? ? nil : joins.join(' ')

    # page params
    @user_size = User.select(select.join(',')).joins(joins).where([cond.join(' AND '), *var]).group(group_by)
    @options[:page] = (@options[:page].to_i < 1) ? 1 : @options[:page].to_i
    @total_pages = (@user_size.size.to_d / session[:items_per_page].to_d).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i && @total_pages.to_i > 0
    fpage = ((@options[:page] - 1) * session[:items_per_page]).to_i

    @users = User.select(select.join(',')).joins(joins).where([cond.join(' AND '), *var]).order(@options[:order]).group(group_by).limit("#{fpage}, #{session[:items_per_page].to_i}")
    @search = ((cond.size > 1 or @options[:sub_s].to_i > -1) ? 1 : 0)

    session[:user_hiden_stats] = @options
  end

  def hide
    user = User.where(id: params[:id]).first
    if user.blank? or user.id == 0
      flash[:notice] = _('User_was_not_found')
      redirect_to action: 'list' and return false
    end

    if user.hidden == 1
      user.hidden = 0
      user.save
      flash[:status] = _('User_unhidden') + ': ' + nice_user(user)
      redirect_to action: 'list'
    else
      user.hidden = 1
      user.save
      flash[:status] = _('User_hidden') + ': ' + nice_user(user)
      redirect_to action: 'hidden'
    end
  end

  def show
    @user = User.where(id: params[:id]).first
  end

  def new
    @page_title = _('New_user')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/User_Details'

    owner = manager? ? 0 : session[:user_id]

    @countries = Direction.order(:name)
    @default_country_id = Confline.get_value('Default_Country_ID').to_i

    @user = Confline.get_default_object(User, owner)
    @user.agreement_date = Time.now.to_s(:db)
    @user.owner_id = owner
    @address = Confline.get_default_object(Address, owner)
    @tax = Confline.get_default_object(Tax, owner)
    @user.tax = @tax
    @user.address = @address
    @user.agreement_number = next_agreement_number
    @user.change_warning_balance_currency

    @blacklists_on = true if admin? || manager?
    @number_pools = NumberPool.order(:name).all.to_a
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
    @show_rspro_button = (reseller_pro_active? || (User.where(owner_id: current_user.id, own_providers: 1).count == 0))
    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user.id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user.id).count
  end

  def create
    @page_title = _('New_user')
    @page_icon = 'add.png'

    blacklist_whitelist_number_pool_params_fix

    params[:user] = params[:user].each_value(&:strip!)
    params[:address] = params[:address].each_value(&:strip!) if params[:address]
    params[:user][:responsible_accountant_id] = current_user.id.to_s if manager?

    if ['reseller'].include?(params[:user][:usertype])
      if params[:accountant_type].to_i == 0
        dont_be_so_smart
        redirect_to :root and return false
      else
        params[:user][:acc_group_id] = params[:accountant_type].to_i
      end
      params[:hide_non_answered_calls] = 0
    else
      params[:user][:acc_group_id] = 0
    end

    if params[:privacy]
      params[:user][:hide_destination_end] = (params[:privacy][:global].to_i == 1) ? -1 :
          params[:user][:hide_destination_end] = params[:privacy].values.sum { |value| value.to_i }
    end

    params[:user][:generate_invoice] = (params[:user][:generate_invoice].to_i == 1) ? 1 : 0
    params[:user][:generate_invoice_manually] = (params[:user][:generate_invoice_manually].to_i == 1) ? 1 : 0
    params[:user][:generate_prepaid_invoice] = (params[:user][:generate_prepaid_invoice].to_i == 1) ? 1 : 0

    #    if  !Email.address_validation(params[:address][:email]) and params[:address][:email].to_s.length > 0
    #      flash[:notice] = _('Please_enter_correct_email')
    #      redirect_to :action => 'new' and return false
    #    end

    owner_id = correct_owner_id
    if reseller? && params[:user][:usertype] != 'user'
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @user = Confline.get_default_object(User, owner_id)
    @user.attributes = params[:user]
    @user.owner_id = owner_id
    @user.warning_email_active = params[:user][:warning_email_active].to_i

    params_password = params[:password][:password] if params[:password]
    bad_password = params_password.to_s.strip.length < @user.minimum_password
    # If passwrod is strong and long enough
    strong_password = User.strong_password? params_password

    @user.errors.add(:password, _('Password_must_be_longer', (@user.minimum_password - 1))) if bad_password
    @user.errors.add(:password, _('Password_must_be_strong')) unless strong_password || bad_password

    @user.password = Digest::SHA1.hexdigest(params[:password][:password].to_s.strip)
    @user.agreement_date = params[:agr_date][:year].to_s + '-' + params[:agr_date][:month].to_s + '-' + params[:agr_date][:day].to_s

    # if params[:unlimited].to_i == 1
    #   @user.credit = 0
    # else
    #   @user.credit = params[:credit].to_d
    #   @user.credit = 0
    # end
    # --> Refactor
    @user.credit = 0

    @countries = Direction.order(:name)

    @user.block_conditional_use = params[:block_conditional_use].to_i
    @user.allow_loss_calls = params[:allow_loss_calls].to_i
    @user.hide_non_answered_calls = params[:hide_non_answered_calls].to_i

    tax = Tax.create(tax_from_params)

    @user.tax_id = tax.id

    @user.warning_email_active = params[:warning_email_active].to_i

    @user.balance = params[:user][:balance].to_d

    if params[:warning_email_active].present? && params[:date].present?
      @user.warning_email_hour = (params[:user][:warning_email_hour].to_i != -1) ? params[:date][:warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
    end

    @address = Address.new(params[:address])
    if @address.save
      @user.address_id = @address.id
    else
      @user.tax.destroy if @user.tax
      @user.address.destroy if @user.address
      flash_errors_for(_('User_was_not_created'), @address)
      render :new and return false
    end

    minimum_username = @user.minimum_username
    if params[:user][:username].strip.length < minimum_username
      @user.errors.add(:username, _('Username_must_be_longer', (minimum_username - 1)))
    end

    current_user_id = current_user.id
    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user_id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user_id).count

    unless params[:warning_email_balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ or params[:warning_email_balance].to_s == ''
      @user.errors.add(:warning_email_balance, _('user_warning_balance_numerical'))
    end

    if params[:warning_email_active].to_i == 1
      @user.warning_email_balance = params[:warning_email_balance].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    end
    @user.warning_balance_increases = params[:warning_balance_increases].to_i

    unless reseller?
      unless params[:warning_email_balance_admin].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ or params[:warning_email_balance_admin].to_s == ''
        @user.errors.add(:warning_email_balance_admin, _('admin_warning_balance_numerical'))
      end

      unless params[:warning_email_balance_manager].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ or params[:warning_email_balance_manager].to_s == ''
        @user.errors.add(:warning_email_balance_manager, _('manager_warning_balance_numerical'))
      end

      if params[:warning_email_active].to_i == 1
        @user.warning_email_balance_admin = params[:warning_email_balance_admin].to_s.strip.sub(/[\,\.\;]/, '.').to_d
        @user.warning_email_balance_manager = params[:warning_email_balance_manager].to_s.strip.sub(/[\,\.\;]/, '.').to_d
      end
    end

    # M2 min/max balance
    unless deny_balance_range_change
      balance_min_stripped = params[:balance_min].to_s.strip.sub(/[\,\.\;]/, '.')
      unless /^-?[\d]+(\.[\d]+){0,1}$/ === balance_min_stripped
        @user.errors.add(:balance_min, _('Minimal_balance_numerical'))
      end

      balance_max_stripped = params[:balance_max].to_s.strip.sub(/[\,\.\;]/, '.')
      unless /^-?[\d]+(\.[\d]+){0,1}$/ === balance_max_stripped
        @user.errors.add(:balance_max, _('Maximal_balance_numerical'))
      end
    end
    max_call_rate_stripped = params[:max_call_rate].to_s.strip.sub(/[\,\.\;]/, '.')
    unless /^-?[\d]+(\.[\d]+){0,1}$/ === max_call_rate_stripped
      @user.errors.add(:max_call_rate, _('Maximal_balance_numerical'))
    end

    user_exchange_rate = current_user.currency.exchange_rate.to_d
    unless deny_balance_range_change
      @user.balance_min = balance_min_stripped.to_d / user_exchange_rate
      @user.balance_max = balance_max_stripped.to_d / user_exchange_rate
    end
    @user.max_call_rate = max_call_rate_stripped.to_d / user_exchange_rate

    if m4_functionality?
      if params[:min_rate_margin].present?
        min_rate_margin_stripped = params[:min_rate_margin].to_s.strip.sub(/[\,\.\;]/, '.')
        unless /^-?[\d]+(\.[\d]+){0,1}$/ === min_rate_margin_stripped
          @user.errors.add(:min_rate_margin, _('Min_Rate_Margin_numerical'))
        end

        @user.min_rate_margin = min_rate_margin_stripped.to_d
      end

      if params[:min_rate_margin].present?
        min_rate_margin_percent_stripped = params[:min_rate_margin_percent].to_s.strip.sub(/[\,\.\;]/, '.')
        unless /^-?[\d]+(\.[\d]+){0,1}$/ === min_rate_margin_percent_stripped
          @user.errors.add(:min_rate_margin_percent, _('Min_Rate_Margin_Percent_numerical'))
        end

        @user.min_rate_margin_percent = min_rate_margin_percent_stripped.to_d
      end
      @user.assign_fraud_protection_attributes(params[:user], true)
    end

    @user.billing_period = ['weekly', 'bi-weekly', 'monthly', 'bimonthly', 'quarterly', 'halfyearly', 'dynamic'].include?(params[:billing_period]) ? params[:billing_period].to_s : 'monthly'
    if params[:billing_period] == 'dynamic'
      @user.billing_dynamic_days = params[:billing_dynamic_days]
      @user.billing_dynamic_generation_time = params[:billing_dynamic_generation_time]

      @user.billing_dynamic_from = user_time_from_params(*params[:billing_dynamic_from].values, true)
      @user.billing_run_at = InvoiceJob.set_run_at(
        billing_period: 'dynamic',
        billing_dynamic_days: params[:billing_dynamic_days],
        billing_dynamic_from: @user.billing_dynamic_from,
        dynamic_hour: @user.billing_dynamic_generation_time
      )
    elsif ['bimonthly', 'quarterly', 'halfyearly'].include?(params[:billing_period])
      @user.billing_run_at = InvoiceJob.set_run_at(billing_period: params[:billing_period])
    end
    @user.invoice_grace_period = params[:invoice_grace_period].to_i if params[:invoice_grace_period]

    if params[:invoice_grace_period].to_i < 0 || params[:invoice_grace_period].to_i > 365 || (!is_number?(params[:invoice_grace_period].to_s) && params[:invoice_grace_period].present?)
      @user.errors.add(:invoice_grace_period, _('grace_period_must_be_integer_between_0_365'))
    end

    @user.assign_paypal_settings(params[:user]) if paypal_addon_active? && paypal_payments_active?
    # M2 company emails
    params_main_email = params[:main_email]
    params_noc_email = params[:noc_email]
    params_billing_email = params[:billing_email]
    params_rates_email = params[:rates_email]
    @user.main_email = params_main_email.to_s.strip if params_main_email
    @user.noc_email = params_noc_email.to_s.strip if params_noc_email
    @user.billing_email = params_billing_email.to_s.strip if params_billing_email
    @user.rates_email = params_rates_email.to_s.strip if params_rates_email

    # Validates all four emails
    @user.validate_company_emails

    g_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
    n_pools = NumberPool.order(:name).all.to_a

    if @user.errors.count.zero? && @user.valid?
      @user.attributes.delete(:id)
      @user_create = User.create(@user.attributes)
      if @user_create.errors.count == 0
        flash[:status] = _('user_created')
        redirect_to action: 'list' and return false
      else
        @user.tax.destroy if @user.tax
        @user.address.destroy if @user.address
        @user.fix_when_is_rendering
        @blacklists_on = true if admin? || manager?
        @number_pools = n_pools
        @bl_global_setting = g_setting
        flash_errors_for(_('User_was_not_created'), @user_create)
        render :new and return false
      end
    else
      @user.tax.destroy if @user.tax
      @user.address.destroy if @user.address
      @user.fix_when_is_rendering
      @blacklists_on = true if admin? || manager?
      @number_pools = n_pools
      @bl_global_setting = g_setting
      flash_errors_for(_('User_was_not_created'), @user)
      render :new and return false
    end
  end

  def gdpr_agreed_user_details
    Action.add_action_hash(current_user, action: 'GDPR_Agreed_user_details', target_id: @user.id, target_type: 'user')
    session["gdpr_agreed_user_details_#{@user.id}"] = true
    render layout: false, nothing: true
  end

  def edit
    if params[:id].to_i == 0
      redirect_to action: 'personal_details' and return false
    end

    @return_controller = params[:return_to_controller] || 'users'
    @return_action = params[:return_to_action] || 'list'

    redirect_to action: 'list' and return false unless params[:id]
    join = ['LEFT JOIN `addresses` ON `addresses`.`id` = `users`.`address_id`']
    join << 'LEFT JOIN `taxes` ON `taxes`.`id` = `users`.`tax_id`'
    join << 'LEFT JOIN `tariffs` ON `tariffs`.`id` = `users`.`tariff_id`'
    @user = User.select('users.*, tariffs.purpose').joins([join.join(' ')]).where(['users.id = ?', params[:id]]).first
    redirect_to action: 'list' and return false unless @user
    current_manager = current_user
    check_owner_for_user(@user.id)

    @page_title = _('users_settings') + ': ' + nice_user(@user)
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/User_Details'

    @blacklists_on = true if admin? || manager?
    @number_pools = NumberPool.order(:name).all.to_a
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'

    owner = corrected_user_id

    @countries = Direction.order(:name)

    # For backwards compatibility - user had no address before, so let's give it to him
    unless @user.address
      address = Address.new
      address.save
      @user.address_id = address.id
      @user.save
    end

    @user.assign_default_tax if !@user.tax || @user.tax_id.to_i == 0

    @address = @user.address

    @create_own_providers = Confline.get_value('Disallow_to_create_own_providers', @user.id).to_i
    @devices = @user.devices

    current_user_users_number = User.where(owner_id: current_user.id, own_providers: 1).count
    @show_rspro_button = (reseller_pro_active? or (current_user_users_number == 0) or (@user.own_providers == 1))
    @selected_user_users_number = User.where(owner_id: @user.id).count
    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user.id).count
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user.id).count

    # Warning balance email send log
    @warning_balance_email_send_log = {}

    send_log_for_user =
        Action.select('date', 'target_type')
        .where("(action = 'warning_balance_send') AND (target_id = #{@user.id.to_i}) AND (data = #{@user.id.to_i})")
        .order('date')
        .last
    @warning_balance_email_send_log[:user] =
      "Last email sent: #{send_log_for_user.date.strftime('%F %T')} to #{send_log_for_user.target_type}" if
        send_log_for_user.present?

    send_log_for_admin =
        Action.select('date', 'target_type')
        .where("(action = 'warning_balance_send') AND (target_id = 0) AND (data = #{@user.id.to_i})")
        .order('date')
        .last
    @warning_balance_email_send_log[:admin] =
      "Last email sent: #{send_log_for_admin.date.strftime('%F %T')} to #{send_log_for_admin.target_type}" if
        send_log_for_admin.present?

    send_log_for_manager =
        Action.select('date', 'target_type')
        .where("(action = 'warning_balance_send') AND (target_id = #{@user.responsible_accountant_id.to_i}) AND (data = #{@user.id.to_i})")
        .order('date')
        .last
    @warning_balance_email_send_log[:manager] =
      "Last email sent: #{send_log_for_manager.date.strftime('%F %T')} to #{send_log_for_manager.target_type.to_s}" if
        send_log_for_manager.present?
  end

  # sets @user in before filter
  def update
    owner_valid = check_owner_for_user(@user.id)
    return false unless owner_valid

    if @user.own_providers == 1
      params[:own_providers] = 1
    end

    params[:user][:responsible_accountant_id] = @user.responsible_accountant_id.to_s if manager?

    params_password = params[:password][:password] if params[:password]
    pswd_blank = params_password.blank?
    bad_username = true if params[:user][:username].present? and params[:user][:username].to_s.strip.length < @user.minimum_username
    bad_password = params_password.present? && params_password.to_s.strip.length < @user.minimum_password
    # If passwrod is strong and long enough
    strong_password = pswd_blank || User.strong_password?(params_password)

    blacklist_whitelist_number_pool_params_fix

    params[:billing_dynamic_from] = user_time_from_params(*params[:billing_dynamic_from].values, true)

    notice, par = @user.validate_from_update(current_user, params)

    if notice.present?
      flash[:notice] = notice
      redirect_to(:root) && (return false)
    end

    @count_rs = User.where(usertype: 'reseller', own_providers: 0, owner_id: current_user.id).all.size
    @count_rspro = User.where(usertype: 'reseller', own_providers: 1, owner_id: current_user.id).all.size

    if par[:user].blank?
      dont_be_so_smart
      redirect_to :root and return false
    end

    warning_balance_email_active_reset = {
      user: @user.warning_email_balance,
      admin: @user.warning_email_balance_admin,
      manager: @user.warning_email_balance_manager,
      hour: @user.warning_email_hour,
      increases: @user.warning_balance_increases
    }

    two_fa_enabled = params[:user][:two_fa_enabled].to_i if m4_functionality? && two_fa_enabled?
    @user.update_from_edit(par.except(:two_fa_enabled), current_user, tax_from_params)
    @return_controller = 'users'
    @return_action = 'list'

    unless params[:warning_email_balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance].to_s == ''
      @user.errors.add(:warning_email_balance, _('user_warning_balance_numerical'))
    end

    unless params[:warning_email_balance_admin].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_admin].to_s == ''
      @user.errors.add(:warning_email_balance_admin, _('admin_warning_balance_numerical'))
    end

    unless params[:warning_email_balance_manager].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ || params[:warning_email_balance_manager].to_s == ''
      @user.errors.add(:warning_email_balance_manager, _('manager_warning_balance_numerical'))
    end

    if params[:warning_email_active].to_i == 1
      @user.assign_attributes(
          warning_balance_increases: params[:warning_balance_increases].to_i,
          warning_email_balance: params[:warning_email_balance].to_s.strip.sub(/[\,\.\;]/, '.').to_d,
          warning_email_balance_admin: params[:warning_email_balance_admin].to_s.strip.sub(/[\,\.\;]/, '.').to_d,
          warning_email_balance_manager: params[:warning_email_balance_manager].to_s.strip.sub(/[\,\.\;]/, '.').to_d
      )
    end
    @user.assign_attributes({
                                main_email: params[:main_email].try(:to_s).try(:strip),
                                noc_email: params[:noc_email].try(:to_s).try(:strip),
                                billing_email: params[:billing_email].try(:to_s).try(:strip),
                                rates_email: params[:rates_email].try(:to_s).try(:strip)
                            }.reject { |key, val| val == nil })

    # Validates all four emails
    @user.validate_company_emails

    # M2 min/max balance
    unless deny_balance_range_change
      unless /^-?[\d]+(\.[\d]+){0,1}$/ === params[:balance_min].to_s.strip.sub(/[\,\.\;]/, '.')
        @user.errors.add(:balance_min, _('Minimal_balance_numerical'))
      end

      unless /^-?[\d]+(\.[\d]+){0,1}$/ === params[:balance_max].to_s.strip.sub(/[\,\.\;]/, '.')
        @user.errors.add(:balance_max, _('Maximal_balance_numerical'))
      end
    end

    unless /^-?[\d]+(\.[\d]+){0,1}$/ === params[:max_call_rate].to_s.strip.sub(/[\,\.\;]/, '.')
      @user.errors.add(:max_call_rate, _('Maximal_balance_numerical'))
    end

    user_exchange_rate = current_user.currency.exchange_rate.to_d
    unless deny_balance_range_change
      @user.assign_attributes(
        balance_min: params[:balance_min].to_s.strip.sub(/[\,\.\;]/, '.').to_d / user_exchange_rate,
        balance_max: params[:balance_max].to_s.strip.sub(/[\,\.\;]/, '.').to_d / user_exchange_rate,
        max_call_rate: params[:max_call_rate].to_s.strip.sub(/[\,\.\;]/, '.').to_d / user_exchange_rate
      )
    else
      @user.assign_attributes(
        max_call_rate: params[:max_call_rate].to_s.strip.sub(/[\,\.\;]/, '.').to_d / user_exchange_rate
      )
    end

    if m4_functionality?
      if params[:min_rate_margin].present?
        min_rate_margin_stripped = params[:min_rate_margin].to_s.strip.sub(/[\,\.\;]/, '.')
        unless /^-?[\d]+(\.[\d]+){0,1}$/ === min_rate_margin_stripped
          @user.errors.add(:min_rate_margin, _('Min_Rate_Margin_numerical'))
        end

        @user.assign_attributes(min_rate_margin: min_rate_margin_stripped.to_d)
      end

      if params[:min_rate_margin_percent].present?
        min_rate_margin_percent_stripped = params[:min_rate_margin_percent].to_s.strip.sub(/[\,\.\;]/, '.')
        unless /^-?[\d]+(\.[\d]+){0,1}$/ === min_rate_margin_percent_stripped
          @user.errors.add(:min_rate_margin_percent, _('Min_Rate_Margin_Percent_numerical'))
        end

        @user.assign_attributes(min_rate_margin_percent: min_rate_margin_percent_stripped.to_d)
      end
      @user.assign_fraud_protection_attributes(params[:user], true)
      @user.two_fa_enabled = two_fa_enabled if two_fa_enabled?
    end

    @user.assign_paypal_settings(params[:user]) if paypal_addon_active? && paypal_payments_active?

    warning_email_balance_errors = @user.errors.messages.keys.select do |key|
      key.to_s.[] 'warning_email_balance'
    end

    # Reset warning email send activeness if params changed
    if warning_balance_email_active_reset[:user] != @user.warning_email_balance
      @user.warning_email_sent = 0
    end

    if warning_balance_email_active_reset[:admin] != @user.warning_email_balance_admin
      @user.warning_email_sent_admin = 0
    end

    if warning_balance_email_active_reset[:manager] != @user.warning_email_balance_manager
      @user.warning_email_sent_manager = 0
    end

    if (warning_balance_email_active_reset[:hour] != @user.warning_email_hour) or
      (warning_balance_email_active_reset[:increases] != @user.warning_balance_increases) or
      (@user.warning_email_active == 0)
      @user.assign_attributes(
          warning_email_sent: 0,
          warning_email_sent_admin: 0,
          warning_email_sent_manager: 0
      )
    end

    valid_user = @user.errors.blank? && warning_email_balance_errors.size.zero? && !bad_username && !bad_password && @user.address.valid? && strong_password

    # Stores a timestamp of the most recent password change. Used for cleaning all user sessions
    @user.monitor_password if valid_user && !pswd_blank

    if valid_user && @user.save
      if @user.usertype == 'reseller'
        @user.check_default_user_conflines

        if params[:own_providers].to_i == 1 and params[:create_own_providers].to_i == 1
          Confline.set_value('Disallow_to_create_own_providers', 1, @user.id)
        elsif Confline.get_value('Disallow_to_create_own_providers', @user.id)
          Confline.set_value('Disallow_to_create_own_providers', 0, @user.id)
        end
      end
      @user.fraud_protection_user_reset if m4_functionality?
      # @user.address.update_attributes(params[:address])
      @user.address.save

      flash[:status] = _('user_details_changed') + ': ' + nice_user(@user)
      redirect_to(action: :edit, id: @user.id) and return false
    else
      check_owner_for_user(@user.id)

      owner = manager? ? User.where(id: session[:user_id].to_i).first.get_owner.id.to_i : session[:user_id]

      @countries = Direction.order(:name)

      # For backwards compatibility - user had no address before, so let's give it to him
      unless @user.address
        address = Address.new
        address.save
        @user.address_id = address.id
        @user.save
      end

      @user.fix_when_is_rendering
      @user.assign_default_tax if !@user.tax or @user.tax_id.to_i == 0
      @address = @user.address
      @devices = @user.devices
      @blacklists_on = true if admin? || manager?
      @number_pools = NumberPool.order(:name).all.to_a
      @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'

      @user.errors.add(:password, _('Password_must_be_longer', (@user.minimum_password - 1))) if bad_password
      @user.errors.add(:password, _('Password_must_be_strong')) unless strong_password || bad_password
      @user.errors.add(:username, _('Username_must_be_longer', (@user.minimum_username - 1))) if bad_username

      if !@user.address.valid?
        flash_errors_for(_('User_was_not_updated'), @user.address)
      else
        flash_errors_for(_('User_was_not_updated'), @user)
      end
      render :edit
    end
  end

  def destroy
    return_controller = 'users'
    return_action = 'list'
    params_return_to_controller = params[:return_to_controller]
    params_return_to_action = params[:return_to_action]
    return_controller = params_return_to_controller if params_return_to_controller
    return_action = params_return_to_action if params_return_to_action

    user = User.where(id: params[:id]).first
    user_id = params[:id].to_i
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to action: 'list' and return false
    end
    error = check_owner_for_user(user)
    unless error
      dont_be_so_smart and return false
    end

    devices = user.devices

    if user.id.to_i == session[:user_id]
      flash[:notice] = _('Cant_delete_self')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.calls_or_calls_in_aggregates_present
      flash[:notice] = _('Cant_delete_user_has_calls')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.m2_payments.count > 0
      flash[:notice] = _('Cant_delete_user_it_has_payments')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user.usertype == 'reseller'
      rusers = User.where(owner_id: user.id).count.to_i
      if rusers > 0
        flash[:notice] = _('Cant_delete_reseller_whit_users')
        redirect_to(controller: return_controller, action: return_action) && (return false)
      end
    end

    if user.usertype == 'accountant'
      accountant_users = User.where(responsible_accountant_id: user.id).count.to_i
      if accountant_users > 0
        flash[:notice] = _('Cant_delete_accountant_with_users')
        redirect_to(controller: return_controller, action: return_action) && (return false)
      end
    end

    if Alert.where(check_type: 'user', check_data: user.id).first
      flash[:notice] = _('User_Has_alerts')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if DpeerTpoint.where(device_id: devices.pluck(:id)).present?
      flash[:notice] = _('User_Has_dial_peer_devices')
      redirect_to(controller: return_controller, action: return_action) && (return false)
    end

    if user_id != 0
      username, nice_name = user.username, nice_user(user)
      user.destroy_everything
      action_hash = {action: 'user_deleted', target_id: user_id, data: username, target_type: 'user', data2: nice_name}
      Action.add_action_hash(current_user, action_hash)
      flash[:status] = _('User_deleted')
    else
      flash[:notice] = _('Cant_delete_sysadmin')
    end

    redirect_to controller: return_controller, action: return_action
  end

  # in before filter : user (find_user_from_session)
  def personal_details
    @page_title = _('Personal_details')
    @page_icon = 'edit.png'

    @address = @user.address
    @countries = Direction.order(:name)

    @disallow_email_editing = Confline.get_value('Disallow_Email_Editing', current_user.owner.id) == '1'

    unless @user.address
      address = Address.new
      address.save
      @user.address_id = address.id
      @user.save
    end

    @search_user = @user
    @devices = if user?
                 Device.find_all_for_select(current_user.id)
               else
                 @search_user ? Device.where(user_id: @search_user.id) : []
               end

    @currency_name = @current_user.currency.try(:name).to_s
    if user?
      render :user_personal_details, locals: {
        warning_email_hour: @user.warning_email_hour.to_i,
        user_credit: @user.credit, user_type: ((@user.postpaid == 1) ? 'Postpaid' : 'Prepaid'),
        agreement_date: (@user.agreement_date || Time.now), user_address: @user.address,
        currencies: Currency.get_active.collect { |curr| [curr.name, curr.id] },
        warning_email_options: [['Enabled', 1], ['Disabled', 0]], time_zones: ActiveSupport::TimeZone.all,
        balance_check_hash: Confline.get_value('Devices_Check_Ballance').to_i == 1
      }
    end
  end

  # in before filter : user (find_user_from_session)
  def update_personal_details
    current_user_id = current_user.id.to_i
    usertype = @user.usertype
    if params[:user].blank? || @user.id != current_user_id
      owner_valid = check_owner_for_user(@user.id)
      return false unless owner_valid
    end

    params_password = params[:password][:password] if params[:password]
    bad_username = true if not params[:user] and params[:user][:username].present? and params[:user][:username].to_s.strip.length < @user.minimum_username
    bad_password = params_password.present? && params_password.to_s.strip.length < @user.minimum_password
    # If passwrod is strong and long enough
    strong_password = params_password.blank? || User.strong_password?(params_password)
    pswd_not_empty = params[:password][:password].to_s.length > 0

    if params[:user].present?
      @user.update_attributes(current_user.safe_attributtes(params[:user].except(:two_fa_enabled).each_value(&:strip!), @user.id))
      # @user.usertype = usertype
      @user.assign_attributes({
        warning_email_active: params[:warning_email_active].to_i,
        password: (Digest::SHA1.hexdigest(params[:password][:password]) if pswd_not_empty),
        warning_email_hour: (params[:user][:warning_email_hour].to_i != -1) ? params[:date][:user_warning_email_hour].to_i : params[:user][:user_warning_email_hour].to_i
      }.reject { |keey, val| val == nil })
    end

    # Stores a timestamp of the most recent password change. Used for cleaning all user sessions
    @user.monitor_password if pswd_not_empty
    @user.two_fa_enabled = params[:user][:two_fa_enabled].to_i if m4_functionality? && two_fa_enabled?
    @user.assign_attributes({
                                main_email: params[:main_email].try(:to_s).try(:strip),
                                noc_email: params[:noc_email].try(:to_s).try(:strip),
                                billing_email: params[:billing_email].try(:to_s).try(:strip),
                                rates_email: params[:rates_email].try(:to_s).try(:strip)
                            }.reject { |key, val| val == nil })

    # Validates all four emails
    @user.validate_company_emails

    if !@user.address
      address = Address.create(params[:address].each_value(&:strip!)) if params[:address]
      @user.address_id = address.id
    else
      @user.address.update_attributes(params[:address].each_value(&:strip!)) if params[:address]
    end

    if !bad_username && !bad_password && @user.address.valid? && @user.errors.blank? && @user.save && strong_password

      # Renew_session(@user)
      session[:first_name] = @user.first_name
      session[:last_name] = @user.last_name
      @user.address.save
      session[:show_currency] = @user.currency.try(:name)
      flash[:status] = _('Personal_details_changed')
      redirect_to :root
    else
      if %w[user manager].include?(current_user.usertype)
        @devices = current_user.devices
      else
        @devices = Device.find_all_for_select(corrected_user_id)
      end
      @countries = Direction.order(:name)
      @address = @user.address

      @user.errors.add(:password, _('Password_must_be_longer', (@user.minimum_password - 1))) if bad_password
      @user.errors.add(:password, _('Password_must_be_strong')) unless strong_password || bad_password
      @user.errors.add(:username, _('Username_must_be_longer', (@user.minimum_username - 1))) if bad_username

      if !@user.address.valid?
        flash_errors_for(_('User_was_not_updated'), @user.address)
      else
        flash_errors_for(_('User_was_not_updated'), @user)
      end
      redirect_to(action: 'personal_details', main_email: params[:main_email], noc_email: params[:noc_email], billing_email: params[:billing_email], rates_email: params[:rates_email])
    end
  end

  def update_user_personal_details
    @user.assign_user_personal_details(params[:user], params[:date], params[:address])

    if @user.errors.blank? && @user.save
      @user.fraud_protection_user_reset if m4_functionality?
      flash[:status] = _('Personal_details_changed')
      redirect_to action: 'personal_details'
    else
      flash_errors_for(_('User_was_not_updated'), @user)
      render_user_personal_details
    end
  end

  def default_user
    @page_title = _('Default_user')
    @page_icon = 'edit.png'
    owner = correct_owner_id
    if Confline.where(["name LIKE 'Default_Tax_%' AND owner_id = ?", owner]).count > 0
      @tax = Confline.get_default_object(Tax, owner)
    else
      @tax = Tax.new
      if reseller?
        reseller = User.where(id: owner).first
        @tax = reseller.get_tax.dup
      else
        @tax.assign_default_tax({}, {save: false})
      end
    end
    @user = Confline.get_default_object(User, owner)
    @user.owner_id = owner # owner_id nera default data. taigi reikia ji papildomai nustatyt
    @address = Confline.get_default_object(Address, owner)
    @user.tax = @tax
    @user.address = @address

    @countries = Direction.order(:name)

    @password_length = Confline.get_value('Default_User_password_length', owner).to_i
    @username_length = Confline.get_value('Default_User_username_length', owner).to_i

    @password_length = 8 if @password_length.equal? 0
    @password_length = 6 unless User.use_strong_password?
    @username_length = 1 if @username_length.equal? 0

    @warning_email = {}
    @warning_email[:balance] = Confline.get_value('Default_User_warning_email_balance', owner)
    @warning_email[:balance_admin] = Confline.get_value('Default_User_warning_email_balance_admin', owner)
    @warning_email[:balance_manager] = Confline.get_value('Default_User_warning_email_balance_manager', owner)

    current_user = User.current
    exchange_rate = current_user.currency.exchange_rate.to_d
    if current_user && current_user.try(:currency)
      @warning_email[:balance] = (@warning_email[:balance].to_d * exchange_rate).to_d
      @warning_email[:balance_admin] = (@warning_email[:balance_admin].to_d * exchange_rate).to_d
      @warning_email[:balance_manager] = (@warning_email[:balance_manager].to_d * exchange_rate).to_d
    end

    @blacklists_on = true if admin? || manager?
    @number_pools = NumberPool.order(:name).all.to_a
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
  end

  def default_user_update
    owner = correct_owner_id

    blacklist_whitelist_number_pool_params_fix
    params[:user][:generate_invoice] = params[:user][:generate_invoice].to_i
    params[:user][:generate_invoice_manually] = params[:user][:generate_invoice_manually].to_i
    params[:user][:generate_prepaid_invoice] = params[:user][:generate_prepaid_invoice].to_i
    params[:user][:allow_loss_calls] = params[:allow_loss_calls].to_i
    params[:user][:hide_non_answered_calls] = params[:hide_non_answered_calls].to_i
    params[:user][:block_conditional_use] = params[:block_conditional_use].to_i
    params[:user][:block_at] = params[:block_at_date][:year].to_s + '-' + params[:block_at_date][:month].to_s + '-' + params[:block_at_date][:day].to_s
    params[:user][:warning_email_active] = params[:warning_email_active].to_i
    params[:user][:acc_group_id] = params[:accountant_type]
    params[:user][:balance] = current_user.convert_curr(params[:user][:balance].to_d)
    params[:user][:balance_min] = current_user.convert_curr(params[:balance_min].to_s.strip.sub(/[\,\.\;]/, '.').to_d)
    params[:user][:balance_max] = current_user.convert_curr(params[:balance_max].to_s.strip.sub(/[\,\.\;]/, '.').to_d)


    if params[:unlimited].to_i == 1
      params[:user][:credit] = 0
    else
      params[:user][:credit] = params[:credit].to_d
      params[:user][:credit] = 0
    end

    # privacy
    if params[:privacy]
      if params[:privacy][:global].to_i == 1
        params[:user][:hide_destination_end] = -1
      else
        params[:user][:hide_destination_end] = params[:privacy].values.sum { |value| value.to_i }
      end
    end

    if params[:user][:balance_min] > params[:user][:balance_max]
      flash[:notice] = _('minimal_balance_must_be_grater_than_maximal')
      redirect_to(action: :default_user) && (return false)
    end

    if params[:username_length].strip.to_i < 1
      flash[:notice] = _('Username_must_be_longer', 0)
      redirect_to(action: :default_user) && (return false)
    end

    password_length = params[:password_length].strip.to_i

    if User.use_strong_password?
      if password_length < 8
        flash[:notice] = _('Password_must_be_longer', 7)
        redirect_to(action: :default_user) && (return false)
      end
    else
      if password_length < 6
        flash[:notice] = _('Password_must_be_longer', 5)
        redirect_to(action: :default_user) && (return false)
      end
    end

    if password_length > 30
      flash[:notice] = _('Password_cannot_be_longer_than')
      redirect_to(action: :default_user) && (return false)
    end

    if m4_functionality?
      if params[:min_rate_margin].present?
        min_rate_margin_stripped = params[:min_rate_margin].to_s.strip.sub(/[\,\.\;]/, '.')
        unless /^-?[\d]+(\.[\d]+){0,1}$/ === min_rate_margin_stripped
          flash[:notice] = _('Min_Rate_Margin_numerical')
          redirect_to(action: :default_user) && (return false)
        end

        params[:user][:min_rate_margin] = min_rate_margin_stripped.to_d
      end

      if params[:min_rate_margin_percent].present?
        min_rate_margin_percent_stripped = params[:min_rate_margin_percent].to_s.strip.sub(/[\,\.\;]/, '.')
        unless /^-?[\d]+(\.[\d]+){0,1}$/ === min_rate_margin_percent_stripped
          flash[:notice] = _('Min_Rate_Margin_Percent_numerical')
          redirect_to(action: :default_user) && (return false)
        end

        params[:user][:min_rate_margin_percent] = min_rate_margin_percent_stripped.to_d
      end
      # Fraud Protection
      params[:user][:enforce_daily_limit] = params[:user][:enforce_daily_limit].to_i
      params[:user][:daily_spend_limit] = params[:user][:daily_spend_limit]
      params[:user][:daily_spend_warning] = params[:user][:daily_spend_warning]
      params[:user][:kill_calls_in_progress] = params[:user][:kill_calls_in_progress].to_i
      params[:user][:show_daily_limit] = params[:user][:show_daily_limit].try(:to_i)
      params[:user][:allow_customer_to_edit] = params[:user][:allow_customer_to_edit].to_i
    end

    unless Email.address_validation(params[:main_email])
      flash[:notice] = _('enter_correct_main_email')
      redirect_to(action: :default_user) && (return false)
    end

    unless Email.address_validation(params[:noc_email])
      flash[:notice] = _('enter_correct_noc_email')
      redirect_to(action: :default_user) && (return false)
    end

    unless Email.address_validation(params[:billing_email])
      flash[:notice] = _('enter_correct_billing_email')
      redirect_to(action: :default_user) && (return false)
    end

    unless Email.address_validation(params[:rates_email])
      flash[:notice] = _('enter_correct_rates_email')
      redirect_to(action: :default_user) && (return false)
    end

    [:billing_email, :main_email, :noc_email, :rates_email].each { |key| params[:user][key] = params[key] }

    unless params[:warning_email_balance].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ or params[:warning_email_balance].to_s == ''
      flash[:notice] = _('user_warning_balance_numerical')
      redirect_to(action: :default_user, warning_email_balance: params[:warning_email_balance]) and return false
    end

    unless params[:warning_email_balance_admin].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ or params[:warning_email_balance_admin].to_s == ''
      flash[:notice] = _('admin_warning_balance_numerical')
      redirect_to(action: :default_user, warning_email_balance_admin: params[:warning_email_balance_admin]) and return false
    end

    unless params[:warning_email_balance_manager].to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/ or params[:warning_email_balance_manager].to_s == ''
      flash[:notice] = _('manager_warning_balance_numerical')
      redirect_to(action: :default_user, warning_email_balance_manager: params[:warning_email_balance_manager]) and return false
    end

    params[:warning_email_balance] = params[:warning_email_balance].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    params[:warning_email_balance_admin] = params[:warning_email_balance_admin].to_s.strip.sub(/[\,\.\;]/, '.').to_d
    params[:warning_email_balance_manager] = params[:warning_email_balance_manager].to_s.strip.sub(/[\,\.\;]/, '.').to_d

    params[:user][:billing_period] = params[:billing_period].to_s
    if params[:billing_period] == 'dynamic'
      params[:user][:billing_dynamic_days] = params[:billing_dynamic_days]
      params[:user][:billing_dynamic_generation_time] = params[:billing_dynamic_generation_time]
      params[:user][:billing_dynamic_from] = user_time_from_params(*params[:billing_dynamic_from].values, true)
    end
    params[:user][:invoice_grace_period] = params[:invoice_grace_period].to_i

    if params[:invoice_grace_period].to_i < 0 or params[:invoice_grace_period].to_i > 365 or (!is_number?(params[:invoice_grace_period].to_s) and params[:invoice_grace_period].present?)
      flash[:notice] = _('grace_period_must_be_integer_between_0_365')
      redirect_to(action: :default_user, invoice_grace_period: params[:invoice_grace_period]) and return false
    end

    if params[:warning_email_active]
      params[:user][:warning_email_hour] = (params[:user][:warning_email_hour].to_i != -1) ? params[:date][:user_warning_email_hour].to_i : params[:user][:warning_email_hour].to_i
    end

    if paypal_addon_active? && paypal_payments_active?
      params[:user][:allow_paypal] = params[:user][:allow_paypal].to_i
      params[:user][:paypal_need_approval] = params[:user][:paypal_need_approval].to_i
      params[:user][:paypal_fee_selection] = params[:user][:paypal_fee_selection].to_i
      params[:user][:paypal_credit_selection] = params[:user][:paypal_credit_selection].to_i
      params[:user][:paypal_charge_fee_on_entered_amount] = params[:user][:paypal_charge_fee_on_entered_amount].to_d
      params[:user][:paypal_charge_fee_on_net_amount] = params[:user][:paypal_charge_fee_on_net_amount].to_d
      params[:user][:paypal_do_not_send_confirmation_email] = params[:user][:paypal_do_not_send_confirmation_email].to_i
    end

    Confline.set_default_object(User, owner, params[:user])
    Confline.set_default_object(Address, owner, params[:address])

    tax = tax_from_params
    @blacklists_on = true if admin? || manager?
    @number_pools = NumberPool.order(:name).all.to_a
    @bl_global_setting = Confline.get_value('blacklist_enabled', 0).to_i.equal?(1) ? 'Yes' : 'No'
    tax[:total_tax_name] = 'TAX' if tax[:total_tax_name].blank?
    tax[:tax1_name] = params[:total_tax_name].to_s if params[:tax1_name].blank?
    Confline.set_default_object(Tax, owner, tax)

    params[:password_length] = 8 if params[:password_length].to_i < 1
    Confline.set_value('Default_User_password_length', params[:password_length].to_i, owner)
    Confline.set_value('Default_User_username_length', params[:username_length].to_i, owner)

    current_user = User.current
    if current_user && current_user.try(:currency)
      params[:warning_email_balance] = (params[:warning_email_balance].to_d / current_user.currency.exchange_rate.to_d).to_d
      params[:warning_email_balance_admin] = (params[:warning_email_balance_admin].to_d / current_user.currency.exchange_rate.to_d).to_d
      params[:warning_email_balance_manager] = (params[:warning_email_balance_manager].to_d / current_user.currency.exchange_rate.to_d).to_d
    end

    Confline.set_value('Default_User_send_warning_balance_sms', params[:send_warning_balance_sms].to_i, owner)
    Confline.set_value('Default_User_warning_balance_increases', params[:warning_balance_increases].to_i, owner)
    Confline.set_value('Default_User_warning_email_balance', params[:warning_email_balance], owner)
    Confline.set_value('Default_User_warning_email_balance_admin', params[:warning_email_balance_admin], owner)
    Confline.set_value('Default_User_warning_email_balance_manager', params[:warning_email_balance_manager], owner)

    flash[:status] = _('Default_User_Saved')
    redirect_to action: :default_user
  end

  # lets hope thats temporary hack so that we wouldnt duplicate code
  # when dinamicaly generating queries. may be someday we wouldnt be
  # generating them this way.
  def users_sql
    joins = []
    joins << 'LEFT JOIN tariffs ON users.tariff_id = tariffs.id'
    joins << 'LEFT JOIN addresses ON users.address_id = addresses.id'
    select = []
    select << 'users.*'
    select << 'addresses.city, addresses.county'
    select << 'tariffs.name AS tariff_name'
    return select.join(','), joins.join(' ')
  end

  def users_weak_passwords

    unless user?
      select, join = users_sql
      @users = User.select(select).joins(join).where(["password = SHA1('') or password = SHA1(username)"])
    end

  end

  def default_user_errors_list
    @page_title, @page_icon, @help_link = [_('Default_users_are_set_to_postpaid_and_allowed_loss_calls'), 'vcard.png', 'http://wiki.ocean-tel.uk/index.php/Loss_Making_Calls']

    ownr = Confline.get_default_user_pospaid_errors
    ids = []; ownr.each { |owner| ids << owner['owner_id'] }
    @default_users_postpaid_and_loss_calls = User.where(id: ids)

    # order
    @options = params.reject { |key, _| %w(controller action).member? key.to_s }

    @options[:order_desc] = params[:order_desc].to_i
    @options[:order_by] = params[:order_by]

    @default_users_postpaid_and_loss_calls = User.where(id: ids).sort_by! { |user| nice_user(user).downcase }
    @default_users_postpaid_and_loss_calls.reverse! if @options[:order_desc].to_i.zero?
  end

  # we need to find all accountants that might be responsible for admins users, so that we could
  # show them in /users/edit/X or /users/default_user. but only for admin. and there would be no
  # purpose to show that list /users/edit/X if X would be smt other than simple admins users.
  # But that's in theory, at this moment we dont have infomration about user - @user is set in
  # controller's action, dont know why...
  def find_responsible_accountants
    if admin? || manager? # and (params[:action] == 'default_user' or (@user.is_user? and @user.owner_id.to_i == 0))
      @responsible_accountants = User.responsible_acc
    end
  end

  def default_user_options(session_user_stats, its_list)
    default = {
      items_per_page: session[:items_per_page].to_i,
      page: '1',
      order_by: 'nice_user',
      order_desc: 0,
      s_username: '',
      s_first_name: '',
      s_last_name: '',
      s_agr_number: '',
      s_acc_number: '',
      s_clientid: '',
      sub_s: '-1',
      user_type: '-1',
      s_email: '',
      s_id: ''
    }
    default[:responsible_accountant_id] = '' if its_list
    options = params[:clean] ? default : ((params[:clear] || !session_user_stats) ? default : session_user_stats)
    default.each { |key, value| options[key] = params[key] if params[key] }
    options[:order_by_full] = options[:order_by] + ((options[:order_desc] == 1) ? " DESC" : " ASC")
    options[:order] = User.users_order_by(params, options)

    return options
  end

  def get_users_map
    output = []
    style = "width='177px' nowrap='true' style='margin-left:20px;padding-left:6px;font-size:10px;font-weight: normal;'"
    @user_str = params[:livesearch].to_s

    unless @user_str.blank?
      output, @total_users = User.seek_by_filter(current_user, @user_str, style, params)
    end

    if params[:empty_click].to_s == 'true'
      output = ["<tr><td id='-2' #{style}>" << _('Enter_value_here') << '</td></tr>']
    end

    render(text: output.join)
  end

  def authorize_assigned_users
    params_id = params[:id]
    return if params_id.blank? || [params_id.to_i].include?(current_user.id)
    return if User.check_responsability(params_id)
    flash[:notice] = _('Dont_be_so_smart')
    redirect_to(action: :list) && (return false)
  end

  def custom_invoice_xlsx_template
    @options = {
        functionality_status: (params[:functionality_status] || Confline.get_value('custom_invoice_xlsx_template_for_this_user', @user.id).to_i),
        invoice_cells: {}
    }

    M2Invoice.xlsx_template_cells.each do |name_of_cell|
      @options[:invoice_cells][name_of_cell] = params[:invoice_cells][name_of_cell] ||
          Confline.get("Cell_m2_#{name_of_cell}", @user.id).try(:value) ||
          Confline.get_value("Cell_m2_#{name_of_cell}", 0)
    end
  end

  def custom_invoice_xlsx_template_update
    invoice_cells = M2Invoice.xlsx_template_cells
    cell_values = []
    invoice_cells.each { |name_of_cell| cell_values << params[:invoice_cells][name_of_cell.to_sym].to_s.upcase.strip }
    array_without_empty_values = cell_values.reject(&:empty?)

    if array_without_empty_values.uniq.length != array_without_empty_values.length
      flash[:notice] = _('duplicate_value_in_cell_address_field')
    end

    invoice_cells.each do |cell_name|
      param_of_cell = params[:invoice_cells][cell_name.to_sym]
      if param_of_cell.present? && !(param_of_cell =~ /^([a-zA-Z]([0]*[1-9]+|[1-9]+\d+)+\s*)$/)
        flash[:notice] = _('value_does_not_match_cell_address_format')
        break
      end
    end

    if flash[:notice].present?
      redirect_to(
          action: :custom_invoice_xlsx_template, id: @user.id,
          functionality_status: params[:functionality_status], invoice_cells: params[:invoice_cells]
      )
      return false
    end

    invoice_cells.each do |cell_name|
      param_of_cell = params[:invoice_cells][cell_name.to_sym]
      full_cell_name = 'Cell_m2_' + cell_name
      user_id = @user.id

      if param_of_cell.empty?
        Confline.set_value(full_cell_name, '', user_id)
      else
        Confline.set_value(full_cell_name, param_of_cell.to_s.upcase.strip, user_id)
      end
    end

    Confline.set_value('custom_invoice_xlsx_template_for_this_user', params[:functionality_status], @user.id)

    if params[:file].present?
      path = File.join('public/invoice_templates', "custom_user_template_#{@user.id}.xlsx")
      File.open(path, 'wb') { |file| file.write(params[:file].read) }
    end

    flash[:status] = _('Custom_Invoice_XLSX_Template_successfully_updated')
    redirect_to(action: :custom_invoice_xlsx_template, id: @user.id) && (return false)
  end

  def custom_invoice_xlsx_template_download
    return false unless @user.custom_invoice_xlsx_template_file_exist?
    send_data(
        File.open(@user.custom_invoice_xlsx_template_file_location).read,
        filename: "Custom_XLSX_Template_UserID_#{@user.id}.xlsx"
    )
  end

  def logout_user
    return false if @user.logged == 0 || !current_user.is_admin? || @user.is_admin?
    @user.kick_user
    flash[:status] = _('User_was_kicked')
    redirect_to(action: :list) && (return false)
  end

  def suggest_strong_password
    return unless request.xhr?
    lowercase_tokens = %w[a b c d e f g h i j k l m n o p q r s t u v w x y z]
    uppercase_tokens = %w[A B C D E F G H I J K L M N O P Q R S T U V W X Y Z]
    digit_tokens = %w[0 1 2 3 4 5 6 7 8 9]
    symbol_tokens = %w[! @ # $ % & / ( ) + ? *]
    all_tokens = lowercase_tokens + uppercase_tokens + digit_tokens + symbol_tokens
    all_tokens_size = all_tokens.size
    password = []

    16.times do
      rand_index = rand(all_tokens_size)
      new_symbol = all_tokens[rand_index]
      all_tokens.delete_at(rand_index)
      all_tokens_size -= 1
      password << new_symbol
    end

    render json: {data: password.join}
  end

  def kill_all_calls
    if manager? && !authorize_manager_fn_permissions(fn: :users_users_kill_calls)
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(action: :root) && (return false)
    end

    active_calls = Activecall.where("active = 1 AND (user_id = #{@user.id} OR provider_id = #{@user.id})").all
    Activecall.hangup_calls(active_calls)
    flash[:status] = _('Calls_were_killed')
    redirect_to(action: :edit, id: @user.id) && (return false)
  end

  def upload_user_document
    return unless request.xhr?
    document = params[:file]
    description = params[:document_description]
    user_document = UserDocument.create(
      name: document.original_filename.to_s,
      description: description,
      upload_date: Time.now.strftime('%Y-%m-%d'),
      user_id: @user.id
    )
    file_name = @user.id.to_s + '_' + user_document.id.to_s + '_' + Time.now.to_s.gsub(' ', '_') + document.original_filename.to_s
    full_path = "/usr/local/m2/user_documents/#{file_name}"

    File.open(full_path, 'wb') do |file|
      file.write(document.read)
    end

    unless File.exist?(full_path)
      user_document.delete
      render json: {error_message: 'File_was_not_found'}, status: :unprocessable_entity
    end

    user_document.update_attribute(:full_file_name, full_path)
    render json: {data: 'file_was_created'}
  end

  def get_user_documents
    return unless request.xhr?
    documents = @user.user_documents
    responses = []
    documents.each do |doc|
      responses << {
        id: doc.id,
        name: doc.name,
        description: doc.description,
        filtered_description: doc.description.to_s.gsub('"', '&quot;').gsub("'", '&#92;&#39;'),
        filtered_name: doc.name.to_s.gsub('"', '&quot;').gsub("'", '&#92;&#39;'),
        upload_date: nice_date(doc.upload_date.try(:to_time))
      }
    end
    render json: {data: responses}
  end

  def delete_user_document
    return unless request.xhr?
    @user = @document.user
    full_file_name = @document.full_file_name.to_s

    File.delete(full_file_name) if File.exist?(full_file_name)
    @document.delete

    if File.exist?(full_file_name)
      render json: {error_message: 'Document_was_not_deleted'}, status: :unprocessable_entity
    else
      response = _('Document_was_deleted')
    end

    render json: {data: response}
  end

  def download_user_document
    if admin? || manager? || @document.user_id.to_i == current_user.id
      if File.exist?(@document.full_file_name.to_s)
        send_data(File.open(@document.full_file_name).read, filename: @document.name, type: 'text/plain')
        return
      else
        flash[:notice] = _('Document_was_not_found')
        if @document.user_id.to_i == current_user.id
          redirect_to(action: :personal_details) && (return false)
        else
          redirect_to(action: :edit, id: @document.user_id.to_i) && (return false)
        end
      end
    else
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
  end

  def users_kill_calls_in_progress
    return render nothing: true, status: 403 unless request.local?
    User.users_kill_calls_in_progress if m4_functionality?
    render nothing: true, status: 200
  end

  def send_daily_spend_warning_email
    return render nothing: true, status: 403 unless request.local?
    User.send_daily_spend_warning_email if m4_functionality?
    render nothing: true, status: 200
  end

  def bulk_management
  end

  def bulk_update
    User.bulk_update(params[:user], corrected_user_id)
    flash[:status] = _('Users_were_updated_successfully')
    redirect_to(action: :list) && (return false)
  end

  private

  def check_owner_for_user(user)
    if user.class != User
      user = User.where({id: user}).first
    end

    if !user
      flash[:notice] = _('User_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    session_user_id = session[:user_id]
    if manager?
      if user.id == session_user_id
        redirect_to(action: :personal_details) && (return true)
      end
      owner_id = User.where(id: session_user_id.to_i).first.get_owner.id.to_i
      if [:admin, :manager].include?(user.usertype.to_sym)
        flash[:notice] = _('You_have_no_permission')
        redirect_to(action: :list) && (return false)
      end
    else
      owner_id = session_user_id
    end

    if user.owner_id != owner_id
      flash[:notice] = _('You_have_no_permission')
      redirect_to(action: :list) && (return false)
    end
    return true
  end

  def check_params
    unless params[:user]
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def find_user
    join = ["LEFT JOIN `addresses` ON `addresses`.`id` = `users`.`address_id`"]
    join << "LEFT JOIN `taxes` ON `taxes`.`id` = `users`.`tax_id`"
    join << "LEFT JOIN `tariffs` ON `tariffs`.`id` = `users`.`tariff_id`"
    @user = User.select("users.*, tariffs.purpose")
                .joins([join.join(' ')])
                .where(['users.id = ?', params[:id].to_i]).first

    unless @user and @user.owner_id == current_user.get_correct_owner_id
      flash[:notice] = _('User_not_found')
      redirect_to :root and return false
    end
  end

  def find_document
    @document = UserDocument.where(id: params[:id].to_i).first

    unless @document
      flash[:notice] = _('Document_was_not_found')
      redirect_to(:root) && (return false)
    end

    if current_user.try(:show_only_assigned_users?) &&
       @document.try(:user).try(:responsible_accountant_id).to_i != current_user.id
      flash[:notice] = _('Document_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_user_from_session
    @user = User.where(id: session[:user_id]).first

    unless @user
      flash[:notice] = _('User_not_found')
      redirect_to :root and return false
    end
  end

  def check_with_integrity
    session[:integrity_check] = current_user.integrity_recheck_user if current_user
  end

  def check_selected_rs_user_count
    users_count = User.where(owner_id: params[:id]).all.size
    if (params[:own_providers].to_i == 1) and (users_count > 2)
      dont_be_so_smart
      redirect_to :root and return false
    end
  end

  def find_reseller
    @reseller = User.where(id: params[:id]).first if params[:id].to_i > 0
    unless @reseller
      flash[:notice] = _('Not_found')
      redirect_to controller: 'stats', action: 'resellers' and return false
    end
  end

  def blacklist_whitelist_number_pool_params_fix
    if admin? || manager?
      case params[:user][:enable_static_list].to_s
      when 'blacklist'
        params[:user][:static_list_id] = params[:user][:static_list_id_blacklist]
      when 'whitelist'
        params[:user][:static_list_id] = params[:user][:static_list_id_whitelist]
      end

      case params[:user][:enable_static_source_list].to_s
      when 'blacklist'
        params[:user][:static_source_list_id] = params[:user][:static_source_list_id_blacklist]
      when 'whitelist'
        params[:user][:static_source_list_id] = params[:user][:static_source_list_id_whitelist]
      end

      params[:user].delete(:static_list_id_blacklist)
      params[:user].delete(:static_list_id_whitelist)
      params[:user].delete(:static_source_list_id_blacklist)
      params[:user].delete(:static_source_list_id_whitelist)
    end
  end

  def render_user_personal_details
    @address = @user.address
    @countries = Direction.order(:name)
    @disallow_email_editing = Confline.get_value('Disallow_Email_Editing', current_user.owner.id) == '1'
    render :user_personal_details, locals: {
      warning_email_hour: @user.warning_email_hour.to_i,
      user_credit: @user.credit, user_type: ((@user.postpaid == 1) ? 'Postpaid' : 'Prepaid'),
      agreement_date: (@user.agreement_date || Time.now), user_address: @user.address,
      currencies: Currency.get_active.collect { |curr| [curr.name, curr.id] },
      warning_email_options: [['Enabled', 1], ['Disabled', 0]], time_zones: ActiveSupport::TimeZone.all,
      balance_check_hash: Confline.get_value('Devices_Check_Ballance').to_i == 1
    }
  end
end
