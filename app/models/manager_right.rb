# Manager Right model
class ManagerRight < ActiveRecord::Base
  attr_protected

  has_many :manager_group_rights
  has_many :manager_groups, through: :manager_group_rights

  def self.get_permissions(permissions_access_level)
    permissions = default_permissions
    right_method_map = permissions_id_method_map

    permissions_access_level.each do |permission_access_level|
      right_method_map.select do |right_method|
        if right_method[:manager_right_id] == permission_access_level.manager_right_id
          permissions << send(right_method[:method], permission_access_level.value) if respond_to? right_method[:method]
        end
      end
    end

    permissions.flatten
  end

  private

  def self.permissions_id_method_map
    [
      {manager_right_id: id_by_name('USERS_Users'), method: :users_users},
      {manager_right_id: id_by_name('USERS_Users_Deny_Balance_range_change'), method: :users_users_deny_balance_range_change},
      {manager_right_id: id_by_name('USERS_Users_Kill_Calls'), method: :users_users_kill_calls},
      {manager_right_id: id_by_name('USERS_Connection_Points_Edit'), method: :users_connection_points_edit},
      {manager_right_id: id_by_name('USERS_Connection_Points_List'), method: :users_connection_points_list},
      {manager_right_id: id_by_name('BILLING_Tariffs'), method: :billing_tariffs},
      {manager_right_id: id_by_name('BILLING_CDR_Import'), method: :billing_cdr_import},
      {manager_right_id: id_by_name('BILLING_CDR_Rerating'), method: :billing_cdr_rerating},
      {manager_right_id: id_by_name('ROUTING_Routing_Groups'), method: :routing_routing_groups},
      {manager_right_id: id_by_name('ROUTING_Dial_Peers'), method: :routing_dial_peers},
      {manager_right_id: id_by_name('ACCOUNTING_Financial_Status'), method: :accounting_financial_status},
      {manager_right_id: id_by_name('ACCOUNTING_Payments'), method: :accounting_payments},
      {manager_right_id: id_by_name('ACCOUNTING_Customer_Invoices'), method: :accounting_customer_invoices},
      {manager_right_id: id_by_name('ACCOUNTING_Balance_Report'), method: :accounting_balance_report},
      {manager_right_id: id_by_name('SECURITY_Integrity_Check'), method: :security_integrity_check},
      {manager_right_id: id_by_name('SECURITY_Alerts'), method: :security_alerts},
      {manager_right_id: id_by_name('SECURITY_Alerts_Contacts'), method: :security_contacts},
      {manager_right_id: id_by_name('SECURITY_Alerts_Schedules'), method: :security_schedules},
      {manager_right_id: id_by_name('SECURITY_Alerts_Groups'), method: :security_groups},
      {manager_right_id: id_by_name('REPORTS_Calls_by_Clients'), method: :reports_calls_by_clients},
      {manager_right_id: id_by_name('REPORTS_Aggregates'), method: :reports_aggregates},
      {manager_right_id: id_by_name('REPORTS_Calls_List'), method: :reports_calls_list},
      {manager_right_id: id_by_name('REPORTS_Calls_List_Archived_Calls'), method: :reports_calls_list_archived_calls},
      {manager_right_id: id_by_name('REPORTS_Active_Calls'), method: :reports_active_calls},
      {manager_right_id: id_by_name('REPORTS_Calls_Dashboard'), method: :reports_calls_dashboard},
      {manager_right_id: id_by_name('REPORTS_Hangup_Cause'), method: :reports_hangup_cause},
      {manager_right_id: id_by_name('REPORTS_Load_Stats'), method: :reports_load_stats},
      {manager_right_id: id_by_name('REPORTS_Action_log'), method: :reports_action_log},
      {manager_right_id: id_by_name('REPORTS_Search'), method: :reports_search},
      {manager_right_id: id_by_name('MAINTENANCE_Settings'), method: :maintenance_settings},
      {manager_right_id: id_by_name('MAINTENANCE_Default_User'), method: :maintenance_default_user},
      {manager_right_id: id_by_name('MAINTENANCE_Default_Device'), method: :maintenance_default_device},
      {manager_right_id: id_by_name('MAINTENANCE_Currencies'), method: :maintenance_currencies},
      {manager_right_id: id_by_name('MAINTENANCE_Emails'), method: :maintenance_emails},
      {manager_right_id: id_by_name('MAINTENANCE_Backups'), method: :maintenance_backups},
      {manager_right_id: id_by_name('MAINTENANCE_Background_Tasks'), method: :maintenance_background_tasks},
      {manager_right_id: id_by_name('MAINTENANCE_Servers'), method: :maintenance_servers},
      {manager_right_id: id_by_name('MAINTENANCE_Number_Pools'), method: :maintenance_number_pools},
      {manager_right_id: id_by_name('MAINTENANCE_Directions'), method: :maintenance_directions},
      {manager_right_id: id_by_name('MAINTENANCE_Directions_Groups'), method: :maintenance_directions_groups},
      {manager_right_id: id_by_name('BILLING_Custom_Tariffs'), method: :billing_custom_tariffs},
      {manager_right_id: id_by_name('SECURITY_Blocked_IPs'), method: :security_blocked_ips},
      {manager_right_id: id_by_name('REPORTS_Destination_Groups'), method: :reports_destination_groups},
      {manager_right_id: id_by_name('REPORTS_TP_Deviations'), method: :reports_tp_deviations},
      {manager_right_id: id_by_name('REPORTS_Calls_Per_Hour'), method: :reports_call_per_hour},
      {manager_right_id: id_by_name('DASHBOARD_Quick_Stats'), method: :quick_stats},
      {manager_right_id: id_by_name('REPORTS_Aggregate_Templates'), method: :reports_aggreagte_templates},
      {manager_right_id: id_by_name('REPORTS_Aggregate_Auto_Export'), method: :reports_aggreagte_auto_export},
      {manager_right_id: id_by_name('Show_only_assigned_Users'), method: :show_only_assigned_users},
      {manager_right_id: id_by_name('REPORTS_Calls_List_Hide_Vendors_Rate'), method: :reports_calls_list_hide_vendors_rate},
      {manager_right_id: id_by_name('REPORTS_Calls_List_Hide_Vendors_Price'), method: :reports_calls_list_hide_vendors_price},
      {manager_right_id: id_by_name('USERS_Connection_Points_Deny_Tariff_change'), method: :users_connection_points_deny_tariff_change},
      {manager_right_id: id_by_name('USERS_Connection_Points_Deny_Routing_Group_change'), method: :users_connection_points_deny_routing_group_change},
      {manager_right_id: id_by_name('REPORTS_Active_Calls_Hide_Vendors_Information'), method: :reports_active_calls_hide_vendors_information},
      {manager_right_id: id_by_name('BILLING_Tariffs_Vendors_Tariffs'), method: :billing_tariffs_vendors_tariffs},
      {manager_right_id: id_by_name('BILLING_Tariffs_Users_Tariffs'), method: :billing_tariffs_users_tariffs},
      {manager_right_id: id_by_name('BILLING_Tariffs_Rate_Notifications'), method: :billing_tariffs_rate_notifications},
      {manager_right_id: id_by_name('Call_Tracing'), method: :call_tracing},
      {manager_right_id: id_by_name('BILLING_Tariffs_Tariff_Import_Inbox'), method: :billing_tariffs_tariff_import_inbox},
      {manager_right_id: id_by_name('BILLING_Tariffs_Tariff_Import_Jobs'), method: :billing_tariffs_tariff_import_jobs},
      {manager_right_id: id_by_name('BILLING_Tariffs_Tariff_Import_Import_Rules'), method: :billing_tariffs_tariff_import_import_rules},
      {manager_right_id: id_by_name('BILLING_Tariffs_Tariff_Import_Rate_Import_Rules'), method: :billing_tariffs_tariff_import_rate_import_rules},
      {manager_right_id: id_by_name('BILLING_Tariffs_Tariff_Import_Templates'), method: :billing_tariffs_tariff_import_templates},
      {manager_right_id: id_by_name('BILLING_Tariffs_Tariff_Import_Link_Attachment_Rules'), method: :billing_tariffs_tariff_import_link_attachment_rules}
    ]
  end

  def self.id_by_name(name)
    where(name: name.to_s).first.try(:id) || 0
  end

  def self.default_permissions
    [
      {controller: :callc, action: :change_currency},
      {controller: :devices, action: :ajax_get_user_devices},
      {controller: :devices, action: :cli_user_devices},
      {controller: :callc, action: :login},
      {controller: :callc, action: :logout},
      {controller: :callc, action: :main},
      {controller: :users, action: :get_users_map},
      {controller: :users, action: :personal_details},
      {controller: :users, action: :update_personal_details},
      {controller: :callc, action: :toggle_search}
    ]
  end

  def self.users_users(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :functions, action: :login_as},
          {controller: :functions, action: :login_as_execute},
          {controller: :users, action: :create},
          {controller: :users, action: :destroy},
          {controller: :users, action: :edit},
          {controller: :users, action: :hide},
          {controller: :users, action: :hidden},
          {controller: :users, action: :list},
          {controller: :users, action: :new},
          {controller: :users, action: :update},
          {controller: :users, action: :custom_invoice_xlsx_template},
          {controller: :users, action: :custom_invoice_xlsx_template_update},
          {controller: :users, action: :custom_invoice_xlsx_template_download},
          {controller: :users, action: :gdpr_agreed_user_details},
          {controller: :users, action: :kill_all_calls},
          {controller: :users, action: :delete_user_document},
          {controller: :users, action: :upload_user_document},
          {controller: :users, action: :get_user_documents},
          {controller: :users, action: :download_user_document},
          {controller: :users, action: :bulk_management},
          {controller: :users, action: :bulk_update}

        ]
    end
  end

  def self.users_connection_points_list(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :devices, action: :devices_all},
      {controller: :devices, action: :disconnect_code_changes},
      {controller: :devices, action: :show_devices},
      {controller: :devices, action: :user_devices}
    ]
  end

  def self.users_connection_points_edit(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :devices, action: :create},
      {controller: :devices, action: :destroy},
      {controller: :devices, action: :devices_all},
      {controller: :devices, action: :device_edit},
      {controller: :devices, action: :device_update},
      {controller: :devices, action: :disconnect_code_changes},
      {controller: :devices, action: :disconnect_code_changes_create},
      {controller: :devices, action: :disconnect_code_changes_destroy},
      {controller: :devices, action: :index},
      {controller: :devices, action: :new},
      {controller: :devices, action: :show_devices},
      {controller: :devices, action: :user_devices},
      {controller: :devices, action: :devicecodecs_sort}
    ]
  end

  def self.billing_tariffs(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :destination_groups, action: :retrieve_destinations_remote},
          {controller: :destination_groups, action: :retrieve_groups_remote},
          {controller: :tariffs, action: :bad_rows_from_csv},
          {controller: :tariffs, action: :check_prefix_availability},
          {controller: :tariffs, action: :change_tariff_for_connection_points},
          {controller: :tariffs, action: :create},
          {controller: :tariffs, action: :delete_all_rates},
          {controller: :tariffs, action: :destinations_csv},
          {controller: :tariffs, action: :destroy},
          {controller: :tariffs, action: :edit},
          {controller: :tariffs, action: :generate_providers_rates_csv},
          {controller: :tariffs, action: :generate_request_for_tariff_generator},
          {controller: :tariffs, action: :import_csv2},
          {controller: :tariffs, action: :list},
          {controller: :tariffs, action: :new},
          {controller: :tariffs, action: :rate_destroy},
          {controller: :tariffs, action: :ratedetail_destroy},
          {controller: :tariffs, action: :ratedetail_edit},
          {controller: :tariffs, action: :ratedetails_manage},
          {controller: :tariffs, action: :ratedetail_update},
          {controller: :tariffs, action: :rate_check},
          {controller: :tariffs, action: :rate_details},
          {controller: :tariffs, action: :rates_list},
          {controller: :tariffs, action: :rate_new},
          {controller: :tariffs, action: :rate_try_to_add},
          {controller: :tariffs, action: :tariff_generator},
          {controller: :tariffs, action: :update},
          {controller: :tariffs, action: :update_effective_from_ajax},
          {controller: :tariffs, action: :update_rates},
          {controller: :tariffs, action: :update_tariff_change_checkbox},
          {controller: :tariffs, action: :update_tariff_for_conection_points},
          {controller: :tariffs, action: :update_rates_by_destination_mask},
          {controller: :tariffs, action: :zero_rates_from_csv},
          {controller: :functions, action: :check_separator},
          {controller: :tariffs, action: :compare_tariffs}
        ]
    end
  end

  def self.billing_custom_tariffs(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :destination_groups, action: :retrieve_destinations_remote},
          {controller: :destination_groups, action: :retrieve_groups_remote},
          {controller: :tariffs, action: :bad_rows_from_csv},
          {controller: :tariffs, action: :check_prefix_availability},
          {controller: :tariffs, action: :create},
          {controller: :tariffs, action: :delete_all_rates},
          {controller: :tariffs, action: :destroy},
          {controller: :tariffs, action: :edit},
          {controller: :tariffs, action: :generate_providers_rates_csv},
          {controller: :tariffs, action: :import_csv2},
          {controller: :tariffs, action: :rate_destroy},
          {controller: :tariffs, action: :ratedetail_destroy},
          {controller: :tariffs, action: :ratedetail_edit},
          {controller: :tariffs, action: :ratedetails_manage},
          {controller: :tariffs, action: :ratedetail_update},
          {controller: :tariffs, action: :rate_check},
          {controller: :tariffs, action: :rate_details},
          {controller: :tariffs, action: :rates_list},
          {controller: :tariffs, action: :rate_new},
          {controller: :tariffs, action: :rate_try_to_add},
          {controller: :tariffs, action: :update},
          {controller: :tariffs, action: :update_effective_from_ajax},
          {controller: :tariffs, action: :update_rates},
          {controller: :tariffs, action: :update_tariff_change_checkbox},
          {controller: :tariffs, action: :update_tariff_for_conection_points},
          {controller: :tariffs, action: :update_rates_by_destination_mask},
          {controller: :tariffs, action: :zero_rates_from_csv},
          {controller: :tariffs, action: :create_custom_tariff},
          {controller: :tariffs, action: :custom_tariffs}
        ]
    end
  end

  def self.billing_cdr_import(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :cdr, action: :bad_rows_from_csv},
          {controller: :cdr, action: :cli_add},
          {controller: :cdr, action: :fix_bad_cdr},
          {controller: :cdr, action: :not_import_bad_cdr},
          {controller: :cdr, action: :import_csv},
          {controller: :devices, action: :cli_user_devices},
          {controller: :functions, action: :check_separator}
        ]
    end
  end

  def self.billing_cdr_rerating(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :cdr, action: :rerating},
          {controller: :stats, action: :call_list_to_csv},
          {controller: :stats, action: :call_list_to_pdf}
        ]
    end
  end

  # ROUNTING
  def self.routing_routing_groups(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :routing_groups, action: :create},
          {controller: :routing_groups, action: :destroy},
          {controller: :routing_groups, action: :edit},
          {controller: :routing_groups, action: :list},
          {controller: :routing_groups, action: :new},
          {controller: :routing_groups, action: :rgroup_dpeer_add},
          {controller: :routing_groups, action: :rgroup_dpeer_destroy},
          {controller: :routing_groups, action: :rgroup_dpeers_list},
          {controller: :routing_groups, action: :rgroup_dpeer_status_change},
          {controller: :routing_groups, action: :retrieve_dial_peers_management_remote},
          {controller: :routing_groups, action: :dial_peers_management_assignment_remote},
          {controller: :routing_groups, action: :dial_peers_management},
          {controller: :routing_groups, action: :update},
          {controller: :routing_groups, action: :update_rgroup_dpeers}

        ]
    end
  end

  def self.routing_dial_peers(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :dial_peers, action: :assign_termination_point},
          {controller: :dial_peers, action: :change_status_termination_point},
          {controller: :dial_peers, action: :create},
          {controller: :dial_peers, action: :destroy},
          {controller: :dial_peers, action: :edit},
          {controller: :dial_peers, action: :index},
          {controller: :dial_peers, action: :list},
          {controller: :dial_peers, action: :new},
          {controller: :dial_peers, action: :remove_termination_point},
          {controller: :dial_peers, action: :termination_points_list},
          {controller: :dial_peers, action: :update},
          {controller: :dial_peers, action: :update_termination_point},
          {controller: :dial_peers, action: :active_tps},
          {controller: :routing_groups, action: :retrieve_routing_groups_management_remote},
          {controller: :routing_groups, action: :dial_peers_management_assignment_remote},
          {controller: :routing_groups, action: :routing_groups_management}

        ]
    end
  end

  # ACCOUNTING
  def self.accounting_financial_status(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :financial_statuses, action: :list}
        ]
    end
  end

  def self.accounting_payments(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :payments, action: :confirm},
          {controller: :payments, action: :create},
          {controller: :payments, action: :change_comment},
          {controller: :payments, action: :destroy},
          {controller: :payments, action: :get_currency_by_user_id},
          {controller: :payments, action: :list},
          {controller: :payments, action: :new}
        ]
    end
  end

  def self.accounting_balance_report(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :balance_reports, action: :list},
          {controller: :balance_reports, action: :user_statement_report}
        ]
    end
  end

  def self.accounting_customer_invoices(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :m2_invoices, action: :edit},
          {controller: :m2_invoices, action: :export_to_xlsx},
          {controller: :m2_invoices, action: :destroy},
          {controller: :m2_invoices, action: :list},
          {controller: :m2_invoices, action: :invoice_lines},
          {controller: :m2_invoices, action: :recalculate_invoice},
          {controller: :m2_invoices, action: :update},
          {controller: :m2_invoices, action: :manual_generation_time},
          {controller: :m2_invoices, action: :generate_invoices_status},
          {controller: :m2_invoices, action: :customer_invoices_recalculate},
          {controller: :m2_invoices, action: :recalculate_invoice}
        ]
    end
  end

  # SECURITY
  def self.security_integrity_check(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :devices, action: :devices_weak_passwords},
          {controller: :devices, action: :insecure_devices},
          {controller: :functions, action: :integrity_check},
          {controller: :users, action: :default_user_errors_list},
          {controller: :users, action: :users_postpaid_and_allowed_loss_calls},
          {controller: :users, action: :users_weak_passwords},
          {controller: :destination_groups, action: :destinations_to_dg},
          {controller: :destination_groups, action: :destinations_to_dg_update},
          {controller: :destination_groups, action: :auto_assign_warning},
          {controller: :destination_groups, action: :auto_assign_destinations_to_dg}
        ]
    end
  end

  def self.security_alerts(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :alerts, action: :add_alert_to_group},
          {controller: :alerts, action: :ajax_get_dial_peers},
          {controller: :alerts, action: :alert_add},
          {controller: :alerts, action: :alert_edit},
          {controller: :alerts, action: :alert_destroy},
          {controller: :alerts, action: :alert_new},
          {controller: :alerts, action: :alert_toggle},
          {controller: :alerts, action: :alert_update},
          {controller: :alerts, action: :contact_edit},
          {controller: :alerts, action: :index},
          {controller: :alerts, action: :list},
          {controller: :alerts, action: :remove_alert_from_group},
          {controller: :alerts, action: :update_dependency_selector},
          {controller: :devices, action: :origination_points_ajax},
          {controller: :devices, action: :termination_points_ajax}
        ]
    end
  end

  def self.security_contacts(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :alerts, action: :contacts},
          {controller: :alerts, action: :contact_add},
          {controller: :alerts, action: :contact_destroy},
          {controller: :alerts, action: :contact_edit},
          {controller: :alerts, action: :contact_toggle},
          {controller: :alerts, action: :contact_update}
        ]
    end
  end

  def self.security_schedules(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :alerts, action: :drop_period},
          {controller: :alerts, action: :new_schedule},
          {controller: :alerts, action: :schedules},
          {controller: :alerts, action: :schedule_add},
          {controller: :alerts, action: :schedule_edit},
          {controller: :alerts, action: :schedule_destroy},
          {controller: :alerts, action: :schedule_update},
          {controller: :alerts, action: :schedule_toggle}
        ]
    end
  end

  def self.security_groups(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :alerts, action: :groups},
          {controller: :alerts, action: :group_add},
          {controller: :alerts, action: :group_contact_add},
          {controller: :alerts, action: :group_contact_destroy},
          {controller: :alerts, action: :group_contacts},
          {controller: :alerts, action: :group_destroy},
          {controller: :alerts, action: :group_edit},
          {controller: :alerts, action: :group_toggle},
          {controller: :alerts, action: :group_update}
        ]
    end
  end

  # REPORTS
  def self.reports_calls_by_clients(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :show_user_stats},
          {controller: :stats, action: :user_stats}
        ]
    end
  end

  def self.reports_aggregates(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :aggregates, action: :list},
          {controller: :aggregates, action: :aggregates_download_table_data}
        ]
    end
  end

  def self.reports_calls_list(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :calls_list},
          {controller: :calls, action: :call_info},
          {controller: :calls, action: :retrieve_pcap_file},
          {controller: :calls, action: :retrieve_call_log_freeswitch_text},
          {controller: :calls, action: :retrieve_call_log},
          {controller: :calls, action: :retrieve_call_log_radius_text},
          {controller: :calls, action: :retrieve_call_details_pcap_text},
          {controller: :calls, action: :pcap_image},
          {controller: :calls, action: :download_pcap}
        ]
    end
  end

  def self.reports_calls_list_archived_calls(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :old_calls_stats}
        ]
    end
  end

  def self.reports_active_calls(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :calls, action: :active_call_soft_hangup},
          {controller: :stats, action: :active_calls},
          {controller: :stats, action: :active_calls_show},
          {controller: :stats, action: :terminator_active_calls},
          {controller: :stats, action: :active_calls_per_server},
          {controller: :stats, action: :active_calls_per_user_op}
        ]
    end
  end

  def self.reports_calls_dashboard(access_level = 0)
    case access_level
    when 0
      []
    when 1
      []
    when 2
      [{controller: :stats, action: :calls_dashboard}]
    end
  end

  def self.reports_hangup_cause(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :hangup_cause_codes_stats},
          {controller: :stats, action: :hangup_calls_to_csv}
        ]
    end
  end

  def self.reports_load_stats(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :load_stats}
        ]
    end
  end

  def self.reports_action_log(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :action_log},
          {controller: :stats, action: :action_log_mark_reviewed},
          {controller: :stats, action: :action_processed},
        ]
    end
  end

  def self.reports_search(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :search},
          {controller: :stats, action: :prefix_finder_find},
          {controller: :stats, action: :prefix_finder_find_country},
          {controller: :stats, action: :rate_finder_find},
          {controller: :stats, action: :ip_finder_find}
        ]
    end
  end

  def self.maintenance_settings(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :functions, action: :settings},
          {controller: :functions, action: :settings_change_logo},
          {controller: :functions, action: :settings_change_favicon},
          {controller: :functions, action: :settings_change}
        ]
    end
  end

  def self.maintenance_default_user(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :users, action: :default_user},
          {controller: :users, action: :default_user_update}
        ]
    end
  end

  def self.maintenance_default_device(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :devices, action: :default_device},
          {controller: :devices, action: :default_device_update}
        ]
    end
  end

  def self.maintenance_currencies(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :currencies, action: :currencies},
          {controller: :currencies, action: :currencies_change_status},
          {controller: :currencies, action: :currencies_change_update_status},
          {controller: :currencies, action: :edit},
          {controller: :currencies, action: :update},
          {controller: :currencies, action: :update_currencies_rates}
        ]
    end
  end

  def self.maintenance_emails(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :emails, action: :create},
          {controller: :emails, action: :destroy},
          {controller: :emails, action: :edit},
          {controller: :emails, action: :list},
          {controller: :emails, action: :list_users},
          {controller: :emails, action: :new},
          {controller: :emails, action: :send_emails},
          {controller: :emails, action: :show_emails},
          {controller: :emails, action: :update},
          {controller: :emails, action: :users_for_send_email}
        ]
    end
  end

  def self.maintenance_backups(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :backups, action: :backup_create},
          {controller: :backups, action: :backup_destroy},
          {controller: :backups, action: :backup_download},
          {controller: :backups, action: :backup_manager},
          {controller: :backups, action: :backup_new},
          {controller: :backups, action: :backup_restore}
        ]
    end
  end

  def self.maintenance_background_tasks(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :functions, action: :background_tasks},
          {controller: :functions, action: :task_delete},
          {controller: :functions, action: :task_restart}
        ]
    end
  end

  def self.maintenance_servers(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :servers, action: :edit},
          {controller: :servers, action: :destroy},
          {controller: :servers, action: :list},
          {controller: :servers, action: :server_add},
          {controller: :servers, action: :server_change_core},
          {controller: :servers, action: :server_change_db},
          {controller: :servers, action: :server_change_gui},
          {controller: :servers, action: :server_change_status},
          {controller: :servers, action: :server_update},
          {controller: :servers, action: :assign_to_all_connection_points},
          {controller: :servers, action: :unassign_to_all_connection_points},
          {controller: :stats, action: :server_load}
        ]
    end
  end

  def self.maintenance_number_pools(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :number_pools, action: :bad_numbers},
          {controller: :number_pools, action: :destroy_all_numbers},
          {controller: :number_pools, action: :number_add},
          {controller: :number_pools, action: :number_destroy},
          {controller: :number_pools, action: :number_import},
          {controller: :number_pools, action: :number_list},
          {controller: :number_pools, action: :pool_edit},
          {controller: :number_pools, action: :pool_create},
          {controller: :number_pools, action: :pool_destroy},
          {controller: :number_pools, action: :pool_list},
          {controller: :number_pools, action: :pool_new},
          {controller: :number_pools, action: :pool_update},
          {controller: :number_pools, action: :reset_all_number_counters}
        ]
    end
  end

  def self.maintenance_directions(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :directions, action: :list},
          {controller: :directions, action: :new},
          {controller: :directions, action: :create},
          {controller: :directions, action: :edit},
          {controller: :directions, action: :update},
          {controller: :directions, action: :destroy},
          {controller: :destination_groups, action: :bulk},
          {controller: :destinations, action: :list},
          {controller: :destinations, action: :edit},
          {controller: :destinations, action: :update},
          {controller: :destinations, action: :create},
          {controller: :destinations, action: :destroy},
          {controller: :destinations, action: :new}
        ]
    end
  end

  def self.maintenance_directions_groups(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :destination_groups, action: :list},
          {controller: :destination_groups, action: :bulk},
          {controller: :destination_groups, action: :destinations},
          {controller: :destination_groups, action: :dg_new_destinations},
          {controller: :destination_groups, action: :dg_destination_delete},
          {controller: :destination_groups, action: :dg_add_destinations},
          {controller: :destination_groups, action: :new},
          {controller: :destination_groups, action: :create},
          {controller: :destination_groups, action: :edit},
          {controller: :destination_groups, action: :update},
          {controller: :destination_groups, action: :destroy},
          {controller: :destination_groups, action: :list_json},
          {controller: :destination_groups, action: :bulk_rename_confirm},
          {controller: :destination_groups, action: :bulk_management_confirmation},
          {controller: :destination_groups, action: :bulk_rename},
          {controller: :destination_groups, action: :bulk_assign},
          {controller: :destination_groups, action: :bulk_management_merge_confirmation},
          {controller: :destination_groups, action: :bulk_management_merge},
          {controller: :destination_groups, action: :csv_upload},
          {controller: :destination_groups, action: :csv_file_upload},
          {controller: :destination_groups, action: :map_results},
          {controller: :destination_groups, action: :prefix_import},
          {controller: :destination_groups, action: :cancel_prefix_import}
        ]
    end
  end

  def self.security_blocked_ips(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :monitorings, action: :blocked_ips},
          {controller: :monitorings, action: :blocked_ip_unblock},
          {controller: :monitorings, action: :blocked_ip},
          {controller: :monitorings, action: :blocked_ip_block},
          {controller: :monitorings, action: :new_block_ip}
        ]
    end
  end

  def self.reports_destination_groups(access_level = 0)
    case access_level
      when 0
        []
      when 1
        []
      when 2
        [
          {controller: :stats, action: :country_stats},
          {controller: :stats, action: :country_stats_download_table_data}
        ]
    end
  end

  def self.call_tracing(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :call_tracing, action: :call_tracing},
      {controller: :call_tracing, action: :fake_call_log},
      {controller: :call_tracing, action: :retrieve_fake_call_log},
      {controller: :call_tracing, action: :retrace_fake_call},
      {controller: :call_tracing, action: :call_log},
      {controller: :call_tracing, action: :retrieve_call_log},
      {controller: :call_tracing, action: :retrace}
    ]
  end

  def self.reports_tp_deviations(access_level = 0)
    return [] if access_level < 2
    %i[list new create edit update destroy details].map do |action|
      {controller: :tp_deviations, action: action}
    end
  end

  def self.reports_call_per_hour(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :aggregates, action: :calls_per_hour},
      {controller: :aggregates, action: :calls_per_hour_data_expand}
    ]
  end

  def self.quick_stats(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :callc, action: :show_quick_stats},
      {controller: :callc, action: :quick_stats_technical_info},
      {controller: :callc, action: :quick_stats_active_calls}
    ]
  end

  def self.reports_aggreagte_templates(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :aggregate_templates, action: :index},
      {controller: :aggregate_templates, action: :edit},
      {controller: :aggregate_templates, action: :new},
      {controller: :aggregate_templates, action: :destroy},
      {controller: :aggregate_templates, action: :ajax_create_template},
      {controller: :aggregate_templates, action: :ajax_get_template},
      {controller: :aggregates, action: :ajax_get_templates_list},
      {controller: :aggregate_templates, action: :create},
      {controller: :aggregate_templates, action: :update}
    ]
  end

  def self.reports_aggreagte_auto_export(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :aggregate_export, action: :index},
      {controller: :aggregate_export, action: :edit},
      {controller: :aggregate_export, action: :new},
      {controller: :aggregate_export, action: :destroy},
      {controller: :aggregate_export, action: :create},
      {controller: :aggregate_export, action: :update}
    ]
  end

  def self.show_only_assigned_users(access_level = 0)
    return [] if access_level < 2
    [{functionality: :show_only_assigned_users}]
  end

  def self.reports_calls_list_hide_vendors_rate(access_level = 0)
    return [] if access_level < 2
    [{functionality: :reports_calls_list_hide_vendors_rate}]
  end

  def self.reports_calls_list_hide_vendors_price(access_level = 0)
    return [] if access_level < 2
    [{functionality: :reports_calls_list_hide_vendors_price}]
  end

  def self.users_connection_points_deny_tariff_change(access_level = 0)
    return [] if access_level < 2
    [{functionality: :users_connection_points_deny_tariff_change}]
  end

  def self.users_connection_points_deny_routing_group_change(access_level = 0)
    return [] if access_level < 2
    [{functionality: :users_connection_points_deny_routing_group_change}]
  end

  def self.reports_active_calls_hide_vendors_information(access_level = 0)
    return [] if access_level < 2
    [{functionality: :reports_active_calls_hide_vendors_information}]
  end

  def self.billing_tariffs_users_tariffs(access_level = 0)
    return [] if access_level < 1
    [{functionality: :billing_tariffs_users_tariffs, access_level: access_level}]
  end

  def self.billing_tariffs_rate_notifications(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_rate_notifications, action: :list},
      {controller: :tariff_rate_notifications, action: :new},
      {controller: :tariff_rate_notifications, action: :create},
      {controller: :tariff_rate_notification_jobs, action: :list},
      {controller: :tariff_rate_notification_jobs, action: :download_generated_data},
      {controller: :tariff_rate_notification_jobs, action: :destroy},
      {controller: :tariff_rate_notification_jobs, action: :agree},
      {controller: :tariff_rate_notification_jobs, action: :disagree},
      {controller: :tariff_rate_notification_templates, action: :list},
      {controller: :tariff_rate_notification_templates, action: :new},
      {controller: :tariff_rate_notification_templates, action: :create},
      {controller: :tariff_rate_notification_templates, action: :edit},
      {controller: :tariff_rate_notification_templates, action: :update},
      {controller: :tariff_rate_notification_templates, action: :destroy},
      {controller: :tariff_rate_notification_templates, action: :download_current_xlsx_template}
    ]
  end

  def self.billing_tariffs_vendors_tariffs(access_level = 0)
    return [] if access_level < 1
    [{functionality: :billing_tariffs_vendors_tariffs, access_level: access_level}]
  end

  def self.users_users_deny_balance_range_change(access_level = 0)
    return [] if access_level < 2
    [{functionality: :users_users_deny_balance_range_change, access_level: access_level}]
  end

  def self.users_users_kill_calls(access_level = 0)
    return [] if access_level < 2
    [{functionality: :users_users_kill_calls, access_level: access_level}]
  end

  def self.billing_tariffs_tariff_import_inbox(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_inbox, action: :inbox},
      {controller: :tariff_inbox, action: :delete_email},
      {controller: :tariff_inbox, action: :delete_emails},
      {controller: :tariff_inbox, action: :download_attachment},
      {controller: :tariff_inbox, action: :show_source},
      {controller: :tariff_inbox, action: :assign_import_settings}
    ]
  end

  def self.billing_tariffs_tariff_import_jobs(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_jobs, action: :list},
      {controller: :tariff_jobs, action: :destroy},
      {controller: :tariff_jobs, action: :delete_all_imported},
      {controller: :tariff_job_analysis, action: :list},
      {controller: :tariff_job_analysis, action: :confirm},
      {controller: :tariff_job_analysis, action: :schedule_confirm},
      {controller: :tariff_job_analysis, action: :cancel}
    ]
  end

  def self.billing_tariffs_tariff_import_import_rules(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_import_rules, action: :list},
      {controller: :tariff_import_rules, action: :new},
      {controller: :tariff_import_rules, action: :create},
      {controller: :tariff_import_rules, action: :edit},
      {controller: :tariff_import_rules, action: :update},
      {controller: :tariff_import_rules, action: :destroy},
      {controller: :tariff_import_rules, action: :change_status},
      {controller: :tariff_import_rules, action: :priority_update}
    ]
  end

  def self.billing_tariffs_tariff_import_rate_import_rules(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_rate_import_rules, action: :list},
      {controller: :tariff_rate_import_rules, action: :new},
      {controller: :tariff_rate_import_rules, action: :create},
      {controller: :tariff_rate_import_rules, action: :edit},
      {controller: :tariff_rate_import_rules, action: :update},
      {controller: :tariff_rate_import_rules, action: :destroy}
    ]
  end

  def self.billing_tariffs_tariff_import_templates(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_templates, action: :list},
      {controller: :tariff_templates, action: :new},
      {controller: :tariff_templates, action: :create},
      {controller: :tariff_templates, action: :edit},
      {controller: :tariff_templates, action: :update},
      {controller: :tariff_templates, action: :destroy}
    ]
  end

  def self.billing_tariffs_tariff_import_link_attachment_rules(access_level = 0)
    return [] if access_level < 2
    [
      {controller: :tariff_link_attachment_rules, action: :list},
      {controller: :tariff_link_attachment_rules, action: :new},
      {controller: :tariff_link_attachment_rules, action: :create},
      {controller: :tariff_link_attachment_rules, action: :edit},
      {controller: :tariff_link_attachment_rules, action: :update},
      {controller: :tariff_link_attachment_rules, action: :destroy},
      {controller: :tariff_link_attachment_rules, action: :priority_update},
      {controller: :tariff_link_attachment_rules, action: :get_priorities}
    ]
  end
end
