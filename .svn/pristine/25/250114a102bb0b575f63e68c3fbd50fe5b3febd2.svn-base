# Function Controller
class FunctionsController < ApplicationController
  include FunctionsHelper
  require 'yaml'
  require 'redis'

  layout :determine_layout
  before_filter :check_localization
  before_filter :authorize
  before_filter :admin_only, only: [
      :background_tasks, :task_delete, :task_restart, :get_mnp_prefixes, :create_mnp_prefix, :delete_mnp_prefix,
      :test_mnp_db_connection, :background_tasks_delete_all_done, :test_redis_connection, :get_lnp_prefixes,
      :create_lnp_prefix, :destroy_lnp_prefix
  ]
  before_filter :test_email_admin_only, only: [:send_test_email]
  before_filter :disable_xss_protection, only: [:settings]
  before_filter :check_if_request_ajax,
                only: [
                    :get_mnp_prefixes, :create_mnp_prefix, :delete_mnp_prefix, :test_mnp_db_connection,
                    :test_redis_connection, :destroy_lnp_prefix, :create_lnp_prefix, :get_lnp_prefixes
                ]
  before_action :find_user, only: %i(login_as_execute)

  $date_formats = [
    '%Y-%m-%d %H:%M:%S', '%Y/%m/%d %H:%M:%S', '%Y,%m,%d %H:%M:%S', '%Y.%m.%d %H:%M:%S', '%d-%m-%Y %H:%M:%S',
    '%d/%m/%Y %H:%M:%S', '%d,%m,%Y %H:%M:%S', '%d.%m.%Y %H:%M:%S', '%m-%d-%Y %H:%M:%S', '%m/%d/%Y %H:%M:%S',
    '%m,%d,%Y %H:%M:%S', '%m.%d.%Y %H:%M:%S'
  ]
  $decimal_formats = %w[. , ;]
  $time_formats = ['%H:%M:%S', '%M:%S']

  def index
    redirect_to(:root) && (return false)
  end

  #================= LOGIN AS ==================

  def login_as
    @page_title = _('Login_as')
    @page_icon = 'key.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Login_as'

    @users = User.select("*, #{SqlExport.nice_user_sql}").where("hidden = 0 AND owner_id = 0 AND id != #{current_user.id}").order('nice_user ASC')
  end

  def login_as_execute
    owner_id = manager? ? 0 : current_user.id
    if !(admin? || manager?) && @user.owner_id.to_i != owner_id || !User.check_responsability(params[:user])
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @login_ok = true

    store_url

    renew_session(@user)
    # Session is synced with the last password change
    session[:session_token] = @user.password_changed_at if Confline.get_value('logout_on_password_change').to_i == 1

    @user.mark_logged_in

    change_date_to_present
    session.delete(:calls_list)
    session.delete(:aggregate_list_options)
    session.delete(:summary_list_options)
    flash[:first_login] = true
    redirect_to(:root) && (return false)
  end

  def settings
    @page_title = _('Settings')
    @page_icon = 'cog.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Configuration_from_GUI'

    @countries = Direction.order('name ASC')
    @tariffs = Tariff.where("owner_id = '#{session[:user_id]}'").order('purpose ASC, name ASC')
    @currencies = Currency.get_active
    @servers = Server.order('id ASC')

    style(Confline.get_value('Usual_text_font_style').to_i)
    @style_one = @ar[2]
    @style_two = @ar[1]
    @style_three = @ar[0]
    style(Confline.get_value('Usual_text_highlighted_text_style').to_i)
    @style_four = @ar[2]
    @style_five = @ar[1]
    @style_six = @ar[0]
    style(Confline.get_value('Header_footer_font_style').to_i)
    @style_seven = @ar[2]
    @style_eight = @ar[1]
    @style_nine = @ar[0]

    @logo = Confline.get_value('Logo_Picture')

    @recaptcha_public_key = Confline.get_value('ReCAPTCHA_public_key')
    @recaptcha_private_key = Confline.get_value('ReCAPTCHA_private_key')

    @agreement = Confline.get('Registration_Agreement', session[:user_id])

    archive_at = Confline.get_value('Archive_at', 0)
    archive_till = Confline.get_value('Archive_till', 0)

    if archive_at.blank? || archive_at.to_i == -1
      @archive_at_hour = @archive_at_minute = nil
    else
      time_at = Time.parse(archive_at).in_time_zone(user_tz)
      @archive_at_hour = time_at.strftime('%H')
      @archive_at_minute = time_at.strftime('%M')
    end

    if archive_till.blank? || archive_till.to_i == -1
      @archive_till_hour = @archive_till_minute = nil
    else
      time_till = Time.parse(archive_till).in_time_zone(user_tz)
      @archive_till_hour = time_till.strftime('%H')
      @archive_till_minute = time_till.strftime('%M')
    end
    @mnp_prefixes = MnpPrefix.all
    @lnp_prefixes = LnpPrefix.all
  end

  def send_test_email
    @emails = Email.where(["owner_id= ? AND (callcenter='0' OR callcenter IS NULL)", session[:user_id]])

    if @emails.size.to_i == 0 && session[:usertype] == 'reseller'
      user = User.find(session[:user_id])
      user.create_reseller_emails
    end

    @num = EmailsController.send_test(session[:user_id])
    @num == _('Email_sent').to_s ? flash[:status] = @num : flash[:notice] = notice_with_info_help(@num + '.', 'http://wiki.ocean-tel.uk/index.php/Configuration_from_GUI#Emails')

    if ['admin', 'manager'].include?(session[:usertype])
      redirect_to action: 'settings'
    else
      redirect_to :root
    end
  end

  def settings_change
    if invalid_api_params? params[:allow_api], params[:api_secret_key]
      flash[:notice] = _('invalid_api_secret_key')
      redirect_to(action: 'settings') && (return false)
    end

    params[:email_from] = params[:email_from].to_s.downcase.strip
    if (params[:email_sending_enabled].to_i == 1 && params[:email_from].to_s.blank?) || (params[:email_from].to_s.present? and not params[:email_from].to_s =~ /^[_a-z0-9-]+(\.[_a-z0-9-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*(\.[a-z]{2,63})$/)
      flash[:notice] = _('Invalid_email_format_in_emails_from')
      redirect_to(action: 'settings') && (return false)
    end

    max_pages = Confline.get_value('Max_PDF_pages')
    max_pages = max_pages.blank? ? 100 : max_pages.to_i

    # ==== LOGO ====
    if params[:logo]
      @file = params[:logo]
      unless @file.empty?
        if @file.size < 102400
          @filename = sanitize_filename(@file.original_filename)
          @ext = @filename.split('.').last.downcase
          if @ext == 'jpg' || @ext == 'jpeg' || @ext == 'png' || @ext == 'gif'
            File.open(Actual_Dir + '/public/images/logo/' + @filename, 'wb') do |file|
              file.write(params[:logo].read)
            end
            update_confline('Logo_Picture', 'logo/' + @filename)
            user = User.find(session[:user_id])
            renew_session(user, {dont_change_date: true})
          else
            flash[:notice] = _('Not_a_picture')
            redirect_to(action: 'settings') && (return false)
          end
        else
          flash[:notice] = _('Logo_to_big_max_size_100kb')
          redirect_to(action: 'settings') && (return false)
        end
      else
        flash[:notice] = _('Zero_size_file')
        redirect_to(action: 'settings') && (return false)
      end
    end

    error = 0
    # Globals
    update_confline('Company', params[:company])
    update_confline('Company_Email', params[:company_email])
    update_confline('Version', params[:version])
    update_confline('Copyright_Title', params[:copyright_title])
    update_confline('Admin_Browser_Title', params[:admin_browser_title])
    Confline.set_value2('Frontpage_Text', params[:frontpage_text].to_s, session[:user_id])
    Confline.set_value2('Login_page_Text', params[:login_page_text].to_s, session[:user_id])
    # Registration

    update_confline('Registration_enabled', params[:registration_enabled])
    Confline.set_value('Hide_registration_link', params[:hide_registration_link])
    update_confline('Tariff_for_registered_users', params[:tariff_for_registered_users])
    update_confline('Default_Country_ID', params[:default_country_id])
    update_confline('Default_CID_Name', params[:default_cid_name])
    update_confline('Default_CID_Number', remove_zero_width_space(params[:default_cid_number]))
    update_confline('Send_Email_To_User_After_Registration', params[:send_email_to_user_after_registration])
    update_confline('Send_Email_To_Admin_After_Registration', params[:send_email_to_admin_after_registration])
    Confline.set_value('Default_Balance_for_new_user', params[:default_balance_for_new_user].to_d)
    params_recaptcha_private_key = params[:recaptcha_private_key].to_s
    params_recaptcha_public_key = params[:recaptcha_public_key].to_s
    params_enable_recaptcha = params[:enable_recaptcha].to_i

    if params_enable_recaptcha == 0 || (params_enable_recaptcha == 1 && params_recaptcha_public_key.present? && params_recaptcha_private_key.present?)
      Confline.set_value('reCAPTCHA_enabled', params_enable_recaptcha)
      Confline.set_value('ReCAPTCHA_public_key', params_recaptcha_public_key.strip)
      Confline.set_value('ReCAPTCHA_private_key', params_recaptcha_private_key.strip)
      Recaptcha.configure do |config|
        config.public_key = Confline.get_value('reCAPTCHA_public_key')
        config.private_key = Confline.get_value('reCAPTCHA_private_key')
      end
    end
    Confline.set_value('Allow_registration_username_passwords_in_devices', params[:allow_registration_username_passwords_in_devices].to_i)
    Confline.set_value('Registration_Enable_VAT_checking', params[:enable_vat_checking].to_i)
    Confline.set_value('Registration_allow_vat_blank', params[:allow_vat_blank].to_i)

    Confline.set_value('Invoice_user_billsec_show', params[:invoice_user_billsec_show].to_i)

    # Invoices
    if params[:invoice_number_start].include?('/')
      flash[:notice] = _('Number_Start_cannot_contain')
      error = 1
    else
      update_confline('Invoice_Number_Start', params[:invoice_number_start])
    end

    params[:invoice_number_length] = validate_range(params[:invoice_number_length], 1, 20, 5).to_i
    update_confline('Invoice_Number_Length', params[:invoice_number_length])
    update_confline('Invoice_Number_Type', params[:invoice_number_type])
    update_confline('convert_xlsx_to_pdf', params[:convert_xlsx_to_pdf].to_i, manager? ? 0 : session[:user_id])
    Confline.set_value('Invoice_email_notice_admin', params[:invoice_email_notice_admin].to_i)
    Confline.set_value('Invoice_email_notice_manager', params[:invoice_email_notice_manager].to_i)
    Confline.set_value('How_often_to_send_email_notice', params[:send_email_notice].to_i)
    Confline.set_value('Invoice_Group_By', params[:invoice_group_by].to_i)
    Confline.set_value('Invoice_Group_By_Destination', params[:invoice_group_by_destination].to_i)
    Confline.set_value('Show_Rates', params[:invoice_show_rates].to_i)
    Confline.set_value('Duration_Format', params[:duration_format].to_s, 0)
    Confline.set_value('Duration_Format_Minute_Precision', params[:duration_format_minute_precision].to_i, 0)
    Confline.set_value('Manual_Payment_Line', params[:manual_payment_line].to_s, 0)
    Confline.set_value('Do_not_generate_Invoices_for_blocked_Users', params[:do_not_generate_invoices_for_blocked_users].to_i)
    Confline.set_value('Do_not_include_currencies', params[:do_not_include_currencies].to_i)
    invoice_cells = M2Invoice.xlsx_template_cells
    cell_values = []
    invoice_cells.each { |name_of_cell| cell_values << params[name_of_cell.to_sym].to_s.upcase.strip }
    array_without_empty_values = cell_values.reject(&:empty?)

    if array_without_empty_values.uniq.length != array_without_empty_values.length
      flash[:notice] = _('duplicate_value_in_cell_address_field')
      error = 1
    else
      invoice_cells.each do |cell_name|
        param_of_cell = params[cell_name.to_sym]
        full_cell_name = 'Cell_m2_' + cell_name
        session_user_id = manager? ? 0 : session[:user_id]

        if param_of_cell.blank?
          update_confline(full_cell_name, '', session_user_id)
        elsif param_of_cell =~ /^([a-zA-Z]([0]*[1-9]+|[1-9]+\d+)+\s*)$/
          update_confline(full_cell_name, param_of_cell.to_s.upcase.strip, session_user_id)
        else
          flash[:notice] = _('value_does_not_match_cell_address_format')
          error = 1
        end
      end
    end
    copy_file('public/invoice_templates', 'default.xlsx')

    if params[:new_xlsx_template_apply_for_old_invoices].to_i == 1
      delete_generated_invoice_xlsx_files(correct_owner_id)
    end

    # Emails

    update_confline('Email_Sending_Enabled', params[:email_sending_enabled])
    update_confline('Email_Smtp_Server', params[:email_smtp_server].to_s.strip)
    # set default param in model
    # update_confline('Email_Domain', params[:email_domain])

    update_confline('Email_Batch_Size', params[:email_batch_size])
    update_confline('Email_from', params[:email_from].to_s.strip)
    update_confline('Email_port', params[:email_port].to_s.strip)
    update_confline('Email_Login', params[:email_login].to_s.strip)
    update_confline('Email_Password', params[:email_password].to_s.strip)

    # Realtime
    if params[:time].to_i < 15
      update_confline('Realtime_reload_time', '15')
    else
      update_confline('Realtime_reload_time', params[:time])
    end

    update_confline('Usual_text_font_color', params[:colorfield1])
    update_confline('Usual_text_font_size', params[:usual_text_font_size])
    @usual_text_font_style = params[:style_one].to_i + params[:style_two].to_i + params[:style_three].to_i
    update_confline('Usual_text_font_style', @usual_text_font_style.to_s)
    update_confline('Usual_text_highlighted_text_color', params[:colorfield2])
    @usual_text_highlighted_text_style = params[:style_four].to_i + params[:style_five].to_i + params[:style_six].to_i
    update_confline('Usual_text_highlighted_text_style', @usual_text_highlighted_text_style.to_s)
    update_confline('Usual_text_highlighted_text_size', params[:usual_text_highlighted_text_size])
    update_confline('Header_footer_font_color', params[:colorfield3])
    update_confline('Header_footer_font_size', params[:h_f_font_size])
    @h_f_font_style = params[:style_seven].to_i + params[:style_eight].to_i + params[:style_nine].to_i
    update_confline('Header_footer_font_style', @h_f_font_style.to_s)
    update_confline('Background_color', params[:colorfield4])
    update_confline('Row1_color', params[:colorfield5])
    update_confline('Row2_color', params[:colorfield6])
    update_confline('3_first_rows_color', params[:colorfield7])

    # Various

    server_free_space_limit = params[:server_free_space_limit]
    if is_number?(server_free_space_limit) && (0..100).include?(server_free_space_limit.to_i)
      update_confline('server_free_space_limit', server_free_space_limit)
    else
      update_confline('server_free_space_limit', 20)
    end
    Confline.set_value('admin_login_with_approved_ip_only', params[:admin_login_with_approved_ip_only].to_i)
    Confline.set_value('bad_login_ip_report_warning', params[:bad_login_ip_report_warning].to_i)
    Confline.set_value('call_tracing_server', params[:call_tracing_server].to_i)
    Confline.set_value('do_not_logout_on_session_ip_change', params[:do_not_logout_on_session_ip_change].to_i) if admin?

    delete_tariff_jobs_older_than = params[:delete_tariff_jobs_older_than]
    if is_number?(delete_tariff_jobs_older_than) && (delete_tariff_jobs_older_than.to_i >= 7)
      update_confline('Delete_Tariff_Jobs_older_than', delete_tariff_jobs_older_than)
    else
      flash[:notice] = _('Delete_Tariff_Jobs_older_than_value_must_be_equal_or_greater_than_7')
      error = 1
    end
    # /Various

    # Tax
    params[:total_tax] = 'TAX' if params[:total_tax].blank?
    params[:tax1name] = params[:total_tax].to_s if params[:tax1name].blank?

    Confline.set_value('Tax_1', params[:tax1name])
    Confline.set_value('Tax_2', params[:tax2name])
    Confline.set_value('Tax_3', params[:tax3name])
    Confline.set_value('Tax_4', params[:tax4name])
    Confline.set_value('Tax_1_Value', params[:tax1value].to_d)
    Confline.set_value('Tax_2_Value', params[:tax2value].to_d)
    Confline.set_value('Tax_3_Value', params[:tax3value].to_d)
    Confline.set_value('Tax_4_Value', params[:tax4value].to_d)
    Confline.set_value('Total_tax_name', params[:total_tax])
    Confline.set_value('Tax_compound', params[:compound_tax].to_i, session[:user_id])

    Confline.set_value2('Tax_1', '1') # for consistency.
    Confline.set_value2('Tax_2', params[:tax2active].to_i)
    Confline.set_value2('Tax_3', params[:tax3active].to_i)
    Confline.set_value2('Tax_4', params[:tax4active].to_i)
    # /Tax
    Confline.set_value('Agreement_Number_Length', params[:agreement_number_length])
    Confline.set_value('Nice_Number_Digits', params[:nice_number_digits])

    nice_currency_digits = params[:nice_currency_digits].to_i
    if nice_currency_digits < 1
      flash[:notice] = _('Currency_Amount_Number_Digits_must_be_greater_than_0')
      error = 1
    else
      Confline.set_value('Nice_Currency_Digits', nice_currency_digits)
    end

    if params[:items_per_page].to_i < 1
      flash[:notice] = _('Items_Per_Page_mus_be_greater_than_0')
      error = 1
    else
      Confline.set_value('Items_Per_Page', params[:items_per_page].to_i)
    end

    Confline.set_value('Date_format', params[:date_format])
    Confline.set_value('time_format', params[:time_format])
    Confline.set_value('Device_PIN_Length', params[:device_pin_length])
    Confline.set_value('Hide_non_completed_payments_for_user', params[:hide_non_completed_payments_for_user].to_i)
    Confline.set_value('Disallow_Email_Editing', params[:disallow_email_editing], corrected_user_id)
    Confline.set_value('Disallow_Details_Editing', params[:disallow_details_editing], corrected_user_id)
    Confline.set_value('System_time_zone_daylight_savings', params[:system_time_zone_daylight_savings].to_i)
    Confline.set_value('Show_Usernames_On_Pdf_Csv_Export_Files_In_Last_Calls', params[:show_usernames_on_pdf_csv_export_files_in_last_calls].to_i)
    Confline.set_value('Use_strong_passwords_for_users', params[:use_strong_passwords_for_users].to_i)
    Confline.set_value('Archive_only_answered_calls', params[:archive_only_answered_calls])
    Confline.set_value('Archive_Calls_to_CSV', params[:archive_calls_to_csv])
    Confline.set_value('Do_not_delete_Archived_Calls_from_calls_table', params[:do_not_delete_archived_calls_from_calls_table])
    Confline.set_value('Delete_Calls_instead_of_Archiving', params[:delete_calls_instead_of_archiving])
    Confline.set_value('invoices_show_username', params[:invoices_show_username].to_i)

    Confline.set_value('AD_Sounds_Folder', params[:ad_sound_folder])
    Confline.set_value('Logout_link', params[:logout_link])

    archive_at = if [params[:archive_at_hour], params[:archive_at_minute]].member?('-1')
                   '-1'
                 else
                   Time.zone.now.change(hour: params[:archive_at_hour], min: params[:archive_at_minute]).localtime.strftime('%H:%M')
                 end

    archive_till = if [params[:archive_till_hour], params[:archive_till_minute]].member?('-1')
                     '-1'
                   else
                     Time.zone.now.change(hour: params[:archive_till_hour], min: params[:archive_till_minute]).localtime.strftime('%H:%M')
                   end

    Confline.set_value('Archive_at', archive_at)
    Confline.set_value('Archive_till', archive_till)

    if ('0'..'3650').member? params[:archive_when]
      Confline.set_value('Move_to_old_calls_older_than', params[:archive_when].to_i)
    else
      flash[:notice] = _('Archive_when_invalid')
      error = 1
    end

    if ('0'..'3650').member? params[:delete_archived_calls_older_than]
      Confline.set_value('Delete_Archived_Calls_older_than', params[:delete_archived_calls_older_than].to_i)
    else
      flash[:notice] = _('Archive_when_invalid')
      error = 1
    end

    if ('0'..'3650').member? params[:delete_not_archived_not_answered_calls_older_than]
      Confline.set_value('Delete_not_Archived_not_Answered_Calls_older_than', params[:delete_not_archived_not_answered_calls_older_than].to_i)
    else
      flash[:notice] = _('Archive_when_invalid')
      error = 1
    end

    # With this setting users are logged out when their passwords change
    pswd_change_old = Confline.get_value('logout_on_password_change').to_i
    pswd_change_new = params[:logout_on_password_change] || 0
    if pswd_change_new != pswd_change_old
      Confline.set_value('logout_on_password_change', pswd_change_new)
      ActiveRecord::Base.connection.execute('UPDATE users SET password_changed_at = NULL')
    end

    # FUNCTIONALITY
    if params[:delete_not_actual_rates_after].to_d < 0
      flash[:notice] = _('delete_not_actual_rates_after_greater')
      error = 1
    elsif not is_number?(params[:delete_not_actual_rates_after].to_s)
      flash[:notice] = _('delete_not_actual_rates_after_integer')
      error = 1
    else
      Confline.set_value('delete_not_actual_rates_after', params[:delete_not_actual_rates_after].to_i)
    end

    # FUNCTIONALITY
    Confline.set_value('Show_Rates_Without_Tax', params[:show_rates_without_tax], session[:user_id])
    ## Check if decimal separator and CSV separator are not equal.
    if params[:csv_separator] != params[:csv_decimal]
      Confline.set_value('CSV_Separator', params[:csv_separator])
      Confline.set_value('CSV_Decimal', params[:csv_decimal])
    end
    Confline.set_value('Show_Full_Src', params[:show_full_src]) unless params[:XML_API_Extension] == 1

    Confline.set_value('Active_Calls_Maximum_Calls', params[:active_calls_max])
    Confline.set_value('Active_Calls_Refresh_Interval', ((params[:active_calls_interval].to_i < 3) ? 3 : params[:active_calls_interval].to_i))
    Confline.set_value('Show_Active_Calls_for_Users', params[:show_active_calls_for_users])
    Confline.set_value('Active_Calls_Show_Server', params[:active_calls_show_server])
    Confline.set_value('Show_logo_on_register_page', (params[:show_logo_on_register_page] ? params[:show_logo_on_register_page] : 0))
    Confline.set_value('Show_rates_for_users', params[:show_rates_for_users].to_i, session[:user_id])
    Confline.set_value('Hide_payment_options_for_postpaid_users', params[:hide_payment_options_for_postpaid_users].to_i, session[:user_id])
    Confline.set_value('Hide_HELP_banner', params[:hide_help_banner].to_i, session[:user_id])
    Confline.set_value('Hide_Iwantto', params[:hide_iwantto].to_i)
    Confline.set_value('Hide_Device_Passwords_For_Users', params[:hide_device_passwords_for_users].to_i, 0)
    Confline.set_value('Show_only_main_page', params[:show_only_main_page].to_i, 0)
    Confline.set_value('Show_forgot_password', params[:show_forgot_password].to_i, 0)
    Confline.set_value('Show_Calls_statistics_to_User_for_last', Application.nice_unsigned_integer(params[:show_calls_stats_to_user_for_last]), corrected_user_id)
    Confline.set_value('Show_device_and_cid_in_last_calls', params[:show_device_and_cid_in_last_calls], 0)

    Confline.set_value('Show_answer_time_last_calls', params[:show_answer_time_last_calls], 0)
    Confline.set_value('Show_end_time_last_calls', params[:show_end_time_last_calls], 0)
    Confline.set_value('Show_PDD_last_calls', params[:show_PDD_last_calls], 0)
    Confline.set_value('Show_terminated_by_last_calls', params[:show_terminated_by_last_calls], 0)
    Confline.set_value('Show_Duration_in_Last_Calls', params[:show_duration_in_last_calls].to_i, 0)
    Confline.set_value('Retrieve_PCAP_files_from_the_Proxy_Server', params[:retrieve_pcap_files_from_the_proxy_server].to_i, 0)
    Confline.set_value('GDPR_Activated', params[:gdpr_activated].to_i, 0) if admin?
    Confline.set_value('show_rates_in_active_calls', params[:show_rates_in_active_calls], 0)
    CdrExportTemplate.update_setting_changes if params[:show_device_and_cid_in_last_calls].to_i == 0
    Confline.set_value('Show_detailed_quick_stats', params[:detailed_quick_stats_active], 0)
    Confline.set_value('Cache_ES_Sync_Status_for_last', Application.nice_unsigned_integer(params[:cache_es_sync_status_for_last]), corrected_user_id)

    # ==== Calls Dashboard settings ==== #
    # Refresh period settings
    cd_refresh_period = params[:cd_refresh_interval].to_i

    if cd_refresh_period > 0
      Confline.set_value('Calls_Dashboard_refresh_interval', cd_refresh_period)
    else
      flash[:notice] = _('Calls_Dashboard_bad_interval')
      error = 1
    end

    # Color range settings
    bad_asr = params[:bad_asr].to_s.strip
    good_asr = params[:good_asr].to_s.strip

    bad_acd = params[:bad_acd].to_s.strip
    good_acd = params[:good_acd].to_s.strip

    bad_margin = params[:bad_margin].to_s.strip
    good_margin = params[:good_margin].to_s.strip
    cd_errors = 0

    # Color ranges must be integers and must not overlap
    range_checker = proc { |param| param.blank? || param =~ %r{^\-?[0-9]+$} }
    if [bad_asr, good_asr, bad_acd, good_acd, bad_margin, good_margin].all?(&range_checker)
      if bad_asr.blank? || good_asr.blank? || bad_asr.to_i <= good_asr.to_i
        Confline.set_value('CD_bad_ASR', bad_asr)
        Confline.set_value('CD_good_ASR', good_asr)
      else
        cd_errors += 1
      end
      if bad_acd.blank? || good_acd.blank? || bad_acd.to_i <= good_acd.to_i
        Confline.set_value('CD_bad_ACD', bad_acd)
        Confline.set_value('CD_good_ACD', good_acd)
      else
        cd_errors += 1
      end
      if bad_margin.blank? || good_margin.blank? || bad_margin.to_i <= good_margin.to_i
        Confline.set_value('CD_bad_Margin', bad_margin)
        Confline.set_value('CD_good_Margin', good_margin)
      else
        cd_errors += 1
      end
    else
      cd_errors += 1
    end

    if cd_errors > 0
      flash[:notice] = _('Calls_Dashboard_bad_color_range')
      error = 1
    end
    # ==== End of Calls Dashboard settings ==== #

    # Backups Confline.set_value
    # Confline.set_value('Backup_Folder', params[:backup_storage_directory])
    if params[:backup_number].to_i >= 3 and params[:backup_number].to_i <= 50
      Confline.set_value('Backup_number', params[:backup_number].to_i)
    else
      Confline.set_value('Backup_number', 3)
    end

    if params[:backup_disk_space].to_i >= 10 and params[:backup_disk_space].to_i <= 100
      Confline.set_value('Backup_disk_space', params[:backup_disk_space].to_i)
    else
      Confline.set_value('Backup_disk_space', 10)
    end

    if params[:archive_calls_to_csv] == '2'
      Confline.set_value('save_archived_calls_on_ftp', 1)
    else
      Confline.set_value('save_archived_calls_on_ftp', 0)
    end
    Confline.set_value('ftp_host', params[:ftp_host])
    Confline.set_value('ftp_port', params[:ftp_port])
    Confline.set_value('ftp_user', params[:ftp_user])
    Confline.set_value('ftp_pass', params[:ftp_pass])
    Confline.set_value('ftp_archived_calls_path', params[:ftp_archived_calls_path])
    Confline.set_value('ftp_backups_path', params[:ftp_backups_path])
    Confline.set_value('store_backups_on_ftp', params[:store_backups_on_ftp])

    if params[:store_backups_on_ftp].to_i == 1
      unless Backup.ftp_test_connection(params[:ftp_backups_path])
        Confline.set_value('store_backups_on_ftp', 0)
        flash[:notice] = _('Wrong_FTP_Credentials')
      end
    end

    if Confline.get_value('save_archived_calls_on_ftp').to_i == 1
      unless Backup.ftp_test_connection(params[:ftp_backups_path])
        Confline.set_value('save_archived_calls_on_ftp', 0)
        Confline.set_value('archive_calls_to_csv', 0)
        flash[:notice] = _('Wrong_FTP_Credentials')
      end
    end

    Confline.set_value('Backup_Exclude_Calls_Old', params[:exclude_archived_calls_table])
    Confline.set_value('Backup_shedule', params[:shedule])
    Confline.set_value('Backup_month', params[:backup_month])
    if ((params[:backup_month].to_i.odd? and (params[:backup_month].to_i > 8)) or (params[:backup_month].to_i.even? and (params[:backup_month].to_i < 7))) and params[:backup_month_day].to_i >= 29
      params[:backup_month_day] = 30 if params[:backup_month_day].to_i >= 30
      if params[:backup_month].to_i == 2
        params[:backup_month_day] = 28
      end
    end
    Confline.set_value('Backup_month_day', params[:backup_month_day])
    Confline.set_value('Backup_week_day', params[:backup_week_day])
    Confline.set_value('Backup_hour', params[:hour])

    # API settings
    Confline.set_value('Allow_API', params[:allow_api].to_i)
    unless params[:allow_api].to_i.zero?
      Confline.set_value('Allow_GET_API', params[:allow_get_api].to_i)
      Confline.set_value('API_Secret_Key', params[:api_secret_key].to_s.strip)
      Confline.set_value('XML_API_Extension', params[:xml_api_extension].to_i)
      Confline.set_value('API_Login_Redirect_to_Main', params[:api_login_redirect_to_main].to_i)
      Confline.set_value('API_Allow_payments_ower_API', params[:api_allow_payments].to_i)
      Confline.set_value('Devices_Check_Ballance', params[:devices_check_ballance])
      Confline.set_value('API_Disable_hash_checking', params[:api_disable_hash_checking].to_i)
    end
    # /API settings

    Confline.set_value('CSV_File_size', params[:csv_file_size].to_i)

    # terms and conditions
    cl = Confline.find_or_create_by(name: 'Registration_Agreement', owner_id: session[:user_id])
    if params[:use_terms_and_conditions]
      cl.update_attributes(value2: params[:terms_and_conditions], value: '1')
    else
      cl.update_attribute(:value, '0')
    end

    Confline.set_value('Change_ANSWER_to_FAILED_if_HGC_not_equal_to_16_for_Users', params[:change_if_hgc_not_equal_to_16_for_users].to_i)
    Confline.set_value('Global_Number_Decimal', params[:global_number_decimal].to_s)

    tb = Confline.get_value('Tell_Balance').to_i
    tt = Confline.get_value('Tell_Time').to_i
    Confline.set_value('Tell_Balance', params[:tell_balance].to_i)
    Confline.set_value('Tell_Time', params[:tell_time].to_i)

    sip_port = (params[:default_sip_device_port].to_i == 0) ? 5060 : params[:default_sip_device_port].to_i
    Confline.set_value('Default_SIP_device_port', sip_port, current_user.get_corrected_owner_id)

    # Server Load

    params[:gui_hdd_utilisation] = 100 if params[:gui_hdd_utilisation].to_i > 100
    params[:gui_hdd_utilisation] = 0 if params[:gui_hdd_utilisation].to_i < 0
    Confline.set_value('GUI_HDD_utilisation', params[:gui_hdd_utilisation].to_i)

    params[:gui_hdd_general_load] = 1000 if params[:gui_hdd_general_load].to_i > 1000
    params[:gui_hdd_general_load] = 0 if params[:gui_hdd_general_load].to_i < 0
    Confline.set_value('GUI_CPU_General_load', params[:gui_hdd_general_load].to_i)

    params[:gui_hdd_loadstats] = 50.0 if params[:gui_hdd_loadstats].to_d > 50.0
    params[:gui_hdd_loadstats] = 0.0 if params[:gui_hdd_loadstats].to_d < 0.0
    Confline.set_value('GUI_CPU_Loadstats', params[:gui_hdd_loadstats].to_d.round(1))

    params[:gui_hdd_ruby_process] = 1000 if params[:gui_hdd_ruby_process].to_i > 1000
    params[:gui_hdd_ruby_process] = 0 if params[:gui_hdd_ruby_process].to_i < 0
    Confline.set_value('GUI_CPU_Ruby_process', params[:gui_hdd_ruby_process].to_i)

    params[:gui_hdd_asterisk_process] = 1000 if params[:gui_hdd_asterisk_process].to_i > 1000
    params[:gui_hdd_asterisk_process] = 0 if params[:gui_hdd_asterisk_process].to_i < 0
    Confline.set_value('GUI_CPU_asterisk_process', params[:gui_hdd_asterisk_process].to_i)

    params[:gui_hdd_freeswitch_process] = 1000 if params[:gui_hdd_freeswitch_process].to_i > 1000
    params[:gui_hdd_freeswitch_process] = 0 if params[:gui_hdd_freeswitch_process].to_i < 0
    Confline.set_value('GUI_CPU_freeswitch_process', params[:gui_hdd_freeswitch_process].to_i)

    params[:db_hdd_utilisation] = 100 if params[:db_hdd_utilisation].to_i > 100
    params[:db_hdd_utilisation] = 0 if params[:db_hdd_utilisation].to_i < 0
    Confline.set_value('DB_HDD_utilisation', params[:db_hdd_utilisation].to_i)

    params[:db_hdd_general_load] = 1000 if params[:db_hdd_general_load].to_i > 1000
    params[:db_hdd_general_load] = 0 if params[:db_hdd_general_load].to_i < 0
    Confline.set_value('DB_CPU_General_load', params[:db_hdd_general_load].to_i)

    params[:db_hdd_loadstats] = 50.0 if params[:db_hdd_loadstats].to_d > 50.0
    params[:db_hdd_loadstats] = 0.0 if params[:db_hdd_loadstats].to_d < 0.0
    Confline.set_value('DB_CPU_Loadstats', params[:db_hdd_loadstats].to_d.round(1))

    params[:db_hdd_mysql_process] = 1000 if params[:db_hdd_mysql_process].to_i > 1000
    params[:db_hdd_mysql_process] = 0 if params[:db_hdd_mysql_process].to_i < 0
    Confline.set_value('DB_CPU_MySQL_process', params[:db_hdd_mysql_process].to_i)

    params[:db_hdd_asterisk_process] = 1000 if params[:db_hdd_asterisk_process].to_i > 1000
    params[:db_hdd_asterisk_process] = 0 if params[:db_hdd_asterisk_process].to_i < 0
    Confline.set_value('DB_CPU_asterisk_process', params[:db_hdd_asterisk_process].to_i)

    params[:db_hdd_freeswitch_process] = 1000 if params[:db_hdd_freeswitch_process].to_i > 1000
    params[:db_hdd_freeswitch_process] = 0 if params[:db_hdd_freeswitch_process].to_i < 0
    Confline.set_value('DB_CPU_freeswitch_process', params[:db_hdd_freeswitch_process].to_i)

    params[:delete_server_load_stats] = 0 if params[:delete_server_load_stats].to_i < 0
    Confline.set_value('Delete_Server_Load_stats_older_than', params[:delete_server_load_stats].to_i)
    Confline.set_value('tariff_currency_in_csv_export', params[:tariff_currency_in_csv_export].to_i)

    unless m4_functionality? then
      allow_dynamic_op_auth_with_reg_initial_value = Confline.get_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration').to_i
      allow_dynamic_origination_point_authentication_with_registration = params[:allow_dynamic_origination_point_authentication_with_registration].to_i
      Confline.set_value('Allow_Dynamic_Origination_Point_Authentication_with_Registration', allow_dynamic_origination_point_authentication_with_registration)
      if (allow_dynamic_op_auth_with_reg_initial_value == 1 && allow_dynamic_origination_point_authentication_with_registration == 0)
        ActiveRecord::Base.connection.execute('UPDATE devices SET dynamic = NULL')
        servers = Server.all
        servers.each do |server|
          begin
            server.fs_device_reload('')
          rescue StandardError, SystemExit
          end
        end
      end
    end
    # /Server Load

    # PRIVACY settings
    Confline.set_value('Hide_Destination_End', params[:hide_destination_ends_gui].to_i + params[:hide_destination_ends_csv].to_i + params[:hide_destination_ends_pdf].to_i)
    # /PRIVACY settings

    # Number Portability

    %w[
      Use_Number_Portability MNP_Server_IP MNP_Port MNP_Username MNP_Password MNP_DB_NAME MNP_Table_Name
      MNP_Search_Field MNP_Result_Field MNP_Supported_Prefixes
    ].each do |mnp_setting|
      if Confline.get_value(mnp_setting).to_s != params[mnp_setting.downcase.to_sym].to_s
        Confline.set_value('MNP_Settings_Changes_Present', 1)
        break
      end
    end

    %w[
      us_jurisdictional_routing_module_enabled LNP_Server_IP LNP_Port LNP_Username LNP_Password LNP_DB_NAME LNP_Table_Name
      LNP_Search_Field LNP_Result_Field LNP_Supported_Prefixes
    ].each do |lnp_setting|
      if Confline.get_value(lnp_setting).to_s != params[lnp_setting.downcase.to_sym].to_s
        Confline.set_value('LNP_Settings_Changes_Present', 1)
        break
      end
    end

    Confline.set_value('Use_Number_Portability', params[:use_number_portability].to_i)
    Confline.set_value('MNP_Server_IP', params[:mnp_server_ip].to_s)
    Confline.set_value('MNP_Port', params[:mnp_port].to_i)

    Confline.set_value('us_jurisdictional_routing_module_enabled', params[:us_jurisdictional_routing_module_enabled].to_i)
    Confline.set_value('LNP_Server_IP', params[:lnp_server_ip].to_s)
    Confline.set_value('LNP_Port', params[:lnp_port].to_i)

    %w[Username Password DB_NAME Table_Name Search_Field Result_Field].each do |param|
      mnp_param_value = params["mnp_#{param.downcase}".to_sym].to_s
      Confline.set_value("MNP_#{param}", mnp_param_value)

      lnp_param_value = params["lnp_#{param.downcase}".to_sym].to_s
      Confline.set_value("LNP_#{param}", lnp_param_value)
    end

    Confline.set_value('MNP_Supported_Prefixes', params[:mnp_supported_prefixes].to_i)
    Confline.set_value('LNP_Supported_Prefixes', params[:lnp_supported_prefixes].to_i)
    # /Number Portability



    # Redis
    Confline.set_value('Use_Redis', params[:use_redis].to_i)
    if params[:use_redis]
      Confline.set_value('Redis_IP', params[:redis_ip].to_s.strip)
      Confline.set_value('Redis_Port', params[:redis_port].to_i)
    end
    # /Redis

    # White Label
    if m4_functionality?
      Confline.set_value('white_label_footer', params[:white_label_footer].to_s)
    end
    # /White Label

    # Payments
    Confline.set_value('paypal_payments_activated', params[:paypal_payments_activated] ? 1 : 0)
    Confline.set_value('paypal_client_id', params[:paypal_client_id].to_s.strip)
    Confline.set_value('secret_paypal_key', params[:secret_paypal_key].to_s.strip)
    Confline.set_value('paypal_default_currency', params[:paypal_default_currency].to_s)

    error = paypal_addon_active? ? set_paypal_amount_options(params) : 0
    # /Payments

    # 2FA
    error = m4_functionality? ? set_two_fa_settings(params) : 0
    # /2FA
    user = User.where(id: session[:user_id]).first
    unless user
      flash[:notice] = _('User_not_found')
      redirect_to(:root) && (return false)
    end
    renew_session(user, {dont_change_date: true})
    if params[:enable_recaptcha].to_i == 1 and (params[:recaptcha_public_key].to_s.blank? or params[:recaptcha_private_key].to_s.blank?)
      flash[:notice] = _('reCAPTCHA_keys_cannot_be_empty')
      redirect_to(action: 'settings') && (return false)
    end
    flash[:status] = _('Settings_saved') if error.to_i == 0
    redirect_to(action: 'settings') && (return false)
  end

=begin rdoc
Sets default tax values for users

*Params*

<tt>u</tt> - 1 : set default taxes for users

*Flash*

<tt>notice</tt> - _('User_taxes_set_successfully') for users

*Redirects*

<tt>settings</tt> - after this action settings form is reopened.
=end

  def tax_change
    owner = correct_owner_id
    tax = {
        tax1_enabled: 1,
        tax2_enabled: Confline.get_value2('Tax_2', owner).to_i,
        tax3_enabled: Confline.get_value2('Tax_3', owner).to_i,
        tax4_enabled: Confline.get_value2('Tax_4', owner).to_i,
        tax1_name: Confline.get_value('Tax_1', owner),
        tax2_name: Confline.get_value('Tax_2', owner),
        tax3_name: Confline.get_value('Tax_3', owner),
        tax4_name: Confline.get_value('Tax_4', owner),
        total_tax_name: Confline.get_value('Total_tax_name', owner),
        tax1_value: Confline.get_value('Tax_1_Value', owner).to_d,
        tax2_value: Confline.get_value('Tax_2_Value', owner).to_d,
        tax3_value: Confline.get_value('Tax_3_Value', owner).to_d,
        tax4_value: Confline.get_value('Tax_4_Value', owner).to_d,
        compound_tax: Confline.get_value('Tax_compound', owner).to_i
    }

    tax[:total_tax_name] = 'TAX' if tax[:total_tax_name].blank?
    tax[:tax1_name] = tax[:total_tax_name].to_s if tax[:tax1_name].blank?

    case params[:u].to_i
      when 1
        users = User.includes(:tax).where(['owner_id = ?', owner]).all
        users.each { |user| user.assign_default_tax(tax, save: true)}
        Confline.set_default_object(Tax, owner, tax)
        flash[:status] = _('User_taxes_set_successfully')
      else
        dont_be_so_smart
    end

    if owner == 0
      redirect_to(action: 'settings') && (return false)
    else
      redirect_to(:root) && (return false)
    end
  end

  def style(stile)
    @ar = []
    @ar[0] = (stile >= 8) ? 8 : 0
    stile -= @ar[0]

    @ar[1] = (stile >= 6) ? 4 : 0
    stile -= @ar[1]

    @ar[2] = (stile >= 2) ? 2 : 0

    @ar
  end

  def update_confline(cline, value, id = 0)
    Confline.set_value(cline, value, id)
  end

  def update_confline2(cline, value, id = 0)
    Confline.set_value2(cline, value, id)
  end

  def translations
    @page_title = _('Translations')
    @page_icon = 'world.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Translations'
    @items = current_user.load_user_translations
  end

  def translations_sort
    params[:sortable_list].each_index do |index|
      item = UserTranslation.find(params[:sortable_list][index])
      item.update_attributes(position: index)
    end
    @items = current_user.load_user_translations
    render layout: false, action: :translations
  end

  def translations_change_status
    UserTranslation.translations_change_status(params[:id])
    @items = current_user.load_user_translations
    render layout: false, action: :translations
  end

  def translations_refresh
    flags_to_session
    redirect_to(action: 'translations') && (return false)
  end

  #============= INTEGRITY CHECK ===============

  def integrity_check
    @page_title = _('Integrity_check')
    @page_icon = 'lightning.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Integrity_Check'
    recheck_integrity_check
    @default_user_warning = false

    @destinations_without_dg = Destination.where('destinationgroup_id = 0').order('direction_code ASC')
    @actions = Action.joins(' JOIN users ON (actions.user_id = users.id) ').where("action = 'error' AND processed = '0' ")
    @devices = Device.where("LENGTH(secret) < 8 AND LENGTH(username) > 0 AND username NOT LIKE 'mor_server_%' AND user_id != -1")
    @users = User.where(["password = SHA1('') or password = SHA1(username)"])
    @default_users_erors = Confline.get_default_user_pospaid_errors
    if @default_users_erors and @default_users_erors.count.to_i > 0
      @default_user_warning = true
    end
    @users_postpaid_and_loss_calls = User.where('postpaid = 1 AND allow_loss_calls = 1')

    @insecure_devices = Device.where("insecure = 'port' ").all
    @server_space_exceeded = Server.where("hdd_free_space < #{server_free_space_limit} AND active = 1").all
    if @actions.size.to_i > 0
      @action = Action.joins(' JOIN users ON (actions.user_id = users.id) ').where("action = 'error' AND processed = '0' ").order('date ASC').first
      date = @action.date.to_time - 1.day
      session[:year_from] = date.year
      session[:month_from] = date.month
      session[:day_from] = date.day
      change_date
    end
  end

  def FunctionsController::integrity_recheck
    @destinations_without_dg = Destination.where(destinationgroup_id: 0).order('direction_code ASC').all
    return 1 unless @destinations_without_dg.empty?
    Confline.set_value('Integrity_Check', 0)
    return 0
  end

  # called from anywhere to check if everything is still ok/not_ok
  def FunctionsController::integrity_recheck_user(user_id = 0)
    @default_user_warning = false

    @default_user_warning = true if Confline.get_value('Default_User_allow_loss_calls', user_id).to_i == 1 and Confline.get_value('Default_User_postpaid', user_id).to_i == 1

    @users_postpaid_and_loss_calls = User.where(postpaid: 1, allow_loss_calls: 1).all

    return 1 if !@users_postpaid_and_loss_calls.empty? or @default_user_warning
    Confline.set_value('Integrity_Check', 0)
    return 0
  end

  ######### PERMISSIONS ##########################################################
  def permissions
    @page_title = _('Permissions')
    @page_icon = 'cog.png'
    @roles = Role.order(:name).all

    @rights = Right.includes([:role_rights]).order('saved DESC ,controller ASC , action ASC').all
    # @permissions = RoleRight.get_auth_list
    @roles_count = @roles.size
  end

  def permissions_save
    @roles = Role.order(:name).all
    @rights = Right.includes([:role_rights]).order('saved DESC ,controller ASC , action ASC').all

    Right.update_right_permissions(@rights)

    flash[:status] = _('Settings_saved')
    redirect_to action: 'permissions'
  end

  def role_new
    @page_title = _('New_Role')
    @page_icon = 'add.png'
    @role = Role.new
  end

  def role_create
    @role = Role.new(params[:role])
    if Role.where(name: @role.name).first
      flash[:notice] = _('Cannot_Create_Role_already_exists')
      redirect_to(action: 'permissions') && (return false)
    end

    if @role.save
      Right.update_role_rights(@role)
      flash[:status] = _('Role_Created')
      redirect_to action: 'role_new'
    else
      render :role_new
    end
  end

  def role_destroy
    @role = Role.find(params[:id])
    if User.where(usertype: @role.name).first
      flash[:notice] = _('Cannot_delete_role_users_exist')
      redirect_to(action: 'permissions') && (return false)
    end

    @role.destroy
    flash[:status] = _('Role_Destroyed')
    redirect_to(action: 'permissions') && (return false)
  end

  def right_new
    @page_title = _('New_Right')
    @page_icon = 'add.png'
    @right = Right.new
  end

  def right_create
    temp = params[:right]
    RoleRight.new_right(temp['controller'], temp['action'], temp['description'])
    flash[:status] = _('Right_Created')
    redirect_to action: 'right_new'
  end

  def right_destroy
    @right = Right.find(params[:id])
    @right.destroy
    flash[:status] = _('Right_Destroyed')
    redirect_to(action: 'permissions') && (return false)
  end

  def action_finder
    @controllers = Dir.new("#{Rails.root}/app/controllers").entries
  end

  def action_syncronise
    @roles = Role.order('name')
    @rights = Right.order('controller, action')
    @permissions = RoleRight.get_auth_list
    @roles_count = Role.count

    @controllers = Dir.new("#{Rails.root}/app/controllers").entries
    @controllers.each do |controller|
      if controller =~ /_controller/
        cont = controller.camelize.gsub('.rb', '')
        cont_short = cont.gsub('Controller', '').downcase
        (eval("#{cont}.new.methods") -
            ApplicationController.methods -
            Object.methods -
            ApplicationController.new.methods).sort.each { |met|
          RoleRight.new_right(cont_short, met.to_s, cont_short.to_s.capitalize + '_' + met.to_s)
        }
      end
    end

    redirect_to action: 'permissions'
  end

  def dump_permissions
    db_config = YAML.load_file(Actual_Dir + '/config/database.yml')
    `rm #{Actual_Dir.to_s}/doc/permissions.sql`
    `mysqldump --compact --add-drop-table -u #{db_config['development']['username']} -p#{db_config['development']['password']} mor roles rights role_rights >> #{Actual_Dir.to_s}/doc/permissions.sql`
    MorLog.my_debug('rm ' + Actual_Dir.to_s + '/doc/permissions.sql')
    MorLog.my_debug("mysqldump --compact --add-drop-table -u #{db_config['development']['username']} -p#{db_config['development']['password']} mor roles rights role_rights >> " + Actual_Dir.to_s + '/doc/permissions.sql')
    redirect_to action: 'permissions'
  end

  ######### /PERMISSIONS #########################################################
  ######### Get Not translated words #############################################

  def get_not_translated
    language = 'en'
    language = params[:language] if params[:language]
    lang = []
    @files = {}
    @new_lang = []
    File.read("#{Rails.root}/lang/#{language}.rb").scan(/l.store\s?[\'\"][^\'\"]+[\'\"]/) do |st|
      st.scan(/[\'\"][^\'\"]+[\'\"]/) do |st_item|
        lang << st_item.gsub(/[\'\"]/, '')
      end
    end

    @files_list = Dir.glob("#{Rails.root}/app/controllers/*.rb").collect
    @files_list += Dir.glob("#{Rails.root}/app/views/**/*.rhtml").collect
    @files_list += Dir.glob("#{Rails.root}/app/models/*.rb").collect
    @files_list += Dir.glob("#{Rails.root}/app/helpers/*.rb").collect
    @files_list += Dir.glob("#{Rails.root}/lib/**/*.rb").collect
    for file in @files_list
      File.read(file).scan(/[^\w\d]\_\([\'\"][^\'\"]+[\'\"]\)/) do |st|
        st = st.gsub(/.?\_\(/, '').gsub(/[\s\'\"\)\(]/, '')
        @new_lang << st
        @files[st] = file
      end
    end

    @new_lang -= lang
    @new_lang = @new_lang.uniq.flatten
  end

  ######### /Get Not translated words #############################################


  def test_text
    @text = params[:text]
  end

  def test_file_upload
    @page_title = 'Test file upload'
    @page_icon = 'lightning.png'

    @step = 1
    @step = params[:step].to_i if params[:step]

    @sep, @dec = Application.nice_action_session_csv(params, session, correct_owner_id)
    store_location

    if @step == 2
      session[:imp_user_include] = (params[:include].to_i == 1) ? 1 : 0
      if params[:file] or session[:file]
        if params[:file]
          if params[:file] == ''
            flash[:notice] = _('Please_select_file')
            redirect_to(action: 'import_user_data_users', step: '1') && (return false)
          else
            @file = params[:file]
            if get_file_ext(@file.original_filename, 'csv') == false
              redirect_to(action: 'import_user_data_users', step: '1') && (return false)
            end
            session[:file] = @file.read
          end
        else
          @file = session[:file]
        end
        session[:file_size] = @file.size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to(action: 'import_user_data_users', step: '1') && (return false)
        end

        @file = session[:file]
        check_csv_file_seperators(@file)
        arr = @file.split("\n")
        @fl = arr[0].split(@sep)
        flash[:status] = _('File_uploaded')
      end
    end

    if @step == 3
      `rm -rf /tmp/mor/*`
      @step = 1
      flash[:status] = _('Files_deleted')
    end
  end

  def check_separator
    if session[:file].blank?
      flash[:notice] = _('Please_select_file')
      redirect_back_or_default('/callc/main') and return false
    else
      file = session[:file].force_encoding('UTF-8')
      sep = (params[:custom].to_i > 0) ? (params[:sepn].presence || ';') : params[:sepn2]
      arr = file.split("\n")
      @fl = []
      5.times { |num| @fl[num] = arr[num].to_s.split(sep.to_s) }
      if @fl[0].size.to_i < params[:min_collum_size].to_i
        @notice = _('Not_enough_columns_check_csv_separators')
      end
      render layout: false
    end
  end

  def generate_hash
    @page_title = _('Generate_hash')
    if admin?
      @api_link = params[:link].to_s
      if @api_link.present?
        @query_values = {}
        begin
          CGI::parse(URI.parse(@api_link).query).each { |key, value| @query_values[key.to_sym] = value[0] }
          flash[:notice] = nil
        rescue
          flash[:notice] = _('failed_to_parse_uri') + ' ' + @api_link
        end
        api_action = @query_values.present? ? @query_values[:api_path].to_s.split('/').last : ''
        dummy, ret, @hash_param_order = MorApi.hash_checking(@query_values, dummy, api_action)
        if ret[:key] == ''
          flash[:notice] = _('api_must_have_secret_key')
        else
          @api_secret_key = ret[:key]
          @system_hash = ret[:system_hash]
        end
      end
    else
      dont_be_so_smart
      redirect_to :root
    end
  end

  def ccl_settings
    unless ccl_active?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end

    @page_title = _('CCL_Settings')
    @page_icon = 'cog.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/'

    unless admin?
      redirect_to(action: :main) && (return false)
    end

    @servers = Server.where(server_type: 'asterisk')
  end

  def ccl_settings_update
    unless ccl_active?
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    if params[:indirect].to_i == 1
      if params[:s_id].present?
        Confline.set_value('Default_asterisk_server', params[:s_id], current_user.get_corrected_owner_id)
        flash[:status] = _('Settings_saved')
        redirect_to action: :ccl_settings
      else
        flash[:notice] = _('Update_failed')
        redirect_to(action: :ccl_settings) && (return false)
      end
    else
      redirect_to action: :main and return false
    end
  end

  def background_tasks
    @page_title	= _('Background_tasks')
    @page_icon	= 'cog.png'
    @help_link	= 'http://wiki.ocean-tel.uk/index.php/Background_Tasks'

    clean_params = params.dup.symbolize_keys.reject { |key, _| [:controller, :action].member? key }
    @options = {}.merge(clean_params)
    @options[:page]	= 1	if @options[:page].blank?
    @options[:order_by]	= 'created_at' if @options[:order_by].blank? # #9683 "CASE status when 'IN PROGRESS' then 1 END"
    @options[:order_desc] = 1 if @options[:order_desc].blank?

    order_by = @options[:order_by] + ' ' + ['ASC', 'DESC'][@options[:order_desc].to_i]

    # page params
    all_tasks_count = BackgroundTask.count
    fpage, @total_pages, @options = Application.pages_validator(session, @options, all_tasks_count)
    @tasks = BackgroundTask.order(order_by).limit("#{fpage}, #{session[:items_per_page].to_i}").all

    @show_delete  = Proc.new { |task| ['DONE', 'WAITING'].member? task.status }
    @show_restart = Proc.new { |task| ['DONE', 'FAILED'].member? task.status }
    @nice_task    = Proc.new do |task|
      case task.task_id
        when 1 then _('Rerating')
        when 2 then _('Archive_Old_Calls')
        when 3 then _('tariff_generation')
        when 4 then _('Generating_invoice')
        when 5 then _('Recalculating_invoice')
        when 7 then _('CDR_Export')
        when 8 then _('CDR_Dispute')
        else _('Unknown')
      end
    end
  end

  def task_delete
    @task = BackgroundTask.find(params[:id])
    @task.destroy

    new_params	= params.dup.symbolize_keys.reject { |key, _| [:id, :controller, :action].member? key }

    flash[:status] = _('task_deleted')
    redirect_to action: 'background_tasks', params: new_params
  end

  def task_restart
    task = BackgroundTask.find(params[:id])

    if task
      task_updated = task.update_attributes(status: 'WAITING', percent_completed: 0, expected_to_finish_at: nil, finished_at: nil)
      new_params = params.dup.symbolize_keys.reject { |key, _| [:id, :controller, :action].member? key }

      if task_updated
        flash[:status] = _('task_restarted')
        system('/usr/local/m2/m2_invoices generate &') if task.task_id.to_i == 4
      else
        flash[:notice] = _('task_not_restarted')
      end
    else
      flash[:notice] = _('task_not_restarted')
    end

    redirect_to action: 'background_tasks', params: new_params
  end

  def background_tasks_delete_all_done
    if BackgroundTask.delete_all_done > 0
      flash[:status] = _('Background_Tasks_with_status_Done_successfully_deleted')
    else
      flash[:status] = _('None_Done_Background_Tasks_are_present_to_delete')
    end

    new_params = params.dup.symbolize_keys.reject { |key, _| [:id, :controller, :action].member? key }

    redirect_to action: :background_tasks, params: new_params
  end

  def get_mnp_prefixes(prefix_table = MnpPrefix)
    prefixes = prefix_table.all

    respond_to do |format|
      format.json { render(json: prefixes) }
    end
  end

  def create_mnp_prefix(prefix_table = MnpPrefix, functionality = 'MNP')
    mnp_prefix = prefix_table.new(prefix: params[:prefix])

    response = {status: 0}
    if mnp_prefix.save
      Confline.set_value("#{functionality}_Settings_Changes_Present", 1)
      response[:msg] = _("#{functionality}_Prefix_succesfully_created")
    else
      response[:msg] = _("#{functionality}_prefix_was_not_created")
      response[:errors] = mnp_prefix.errors
      response[:status] = 1
    end

    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  def destroy_mnp_prefix(prefix_table = MnpPrefix, functionality = 'MNP')
    prefix = prefix_table.where(id: params[:id].try(:to_i)).first

    response = {status: 0}
    if prefix && prefix.destroy
      Confline.set_value("#{functionality}_Settings_Changes_Present", 1)
      response[:msg] = _("#{functionality}_Prefix_was_succesfully_deleted")
    else
      response[:msg] = prefix.blank? ? _("#{functionality}_Prefix_was_not_found") : _("#{functionality}__Prefix_was_not_deleted")
      response[:status] = 1
    end

    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  def get_lnp_prefixes
    get_mnp_prefixes(LnpPrefix)
  end

  def create_lnp_prefix
    create_mnp_prefix(LnpPrefix, 'LNP')
  end

  def destroy_lnp_prefix
    destroy_mnp_prefix(LnpPrefix, 'LNP')
  end

  def test_mnp_db_connection
    response = 'ok'
    begin
      client = Mysql2::Client.new(host: params[:host], port: params[:port], username: params[:username], password: params[:mnp_password], database: params[:db_name])
      query = "SELECT #{ActiveRecord::Base::sanitize("#{params[:search_field]}")[1..-2]},
                      #{ActiveRecord::Base::sanitize("#{params[:result_field]}")[1..-2]}
               FROM  #{ActiveRecord::Base::sanitize("#{params[:table_name]}")[1..-2]}
               LIMIT 1"
      client.query(query)
    rescue Mysql2::Error => error
      response = "Mysql2::Error: #{error.error_number}"
    end

    response = {msg: response, color: response == 'ok' ? '#c9efb9' : '#FFD4D4'}
    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  def test_redis_connection
    response = 'ok'

    redis_ip = params[:redis_ip].to_s.strip
    redis_port = params[:redis_port].to_i

    begin
      redis_connection = Redis.new(Confline.redis_connection_hash(redis_ip, redis_port))
      redis_connection.ping
      redis_connection.try(:disconnect!)
    rescue => error
      redis_connection.try(:disconnect!)
      response = error.to_s
    end

    response = {msg: response, color: response == 'ok' ? '#c9efb9' : '#FFD4D4'}
    respond_to do |format|
      format.json { render(json: response) }
    end
  end

  def settings_change_logo
    file = params[:file].try(:[], 0)

    render(json: {msg: 'Bad Request'}) and (return false) if file.blank? || !file.is_a?(ActionDispatch::Http::UploadedFile)
    render(json: {msg: _('Zero_size_file')}) and (return false) if file.size <= 0
    render(json: {msg: _('Logo_to_big_max_size_100kb')}) and (return false) if file.size > 102400
    render(json: {msg: 'Supported types: PNG, JPG'}) and (return false) unless ['image/png', 'image/jpg', 'image/jpeg'].include?(file.content_type.to_s.downcase)

    file_full_path = "#{Actual_Dir}/public/white_label/white_label_logo"
    File.open(file_full_path, 'wb') { |logo_file| logo_file.write(file.read) }

    if File.exist?(file_full_path)
      Confline.set_value('White_Label_Logo_Present', 1, 0)
    else
      render(json: {msg: 'Image received but could not be saved to File System'}) and (return false)
    end

    render(json: {msg: 'ok'})
  end

  def settings_change_favicon
    file = params[:file].try(:[], 0)

    render(json: {msg: 'Bad Request'}) and (return false) if file.blank? || !file.is_a?(ActionDispatch::Http::UploadedFile)
    render(json: {msg: _('Zero_size_file')}) and (return false) if file.size <= 0
    render(json: {msg: _('Logo_to_big_max_size_100kb')}) and (return false) if file.size > 102400
    render(json: {msg: 'Supported type: ico'}) and (return false) unless ['image/x-icon', 'image/vnd.microsoft.icon'].include?(file.content_type.to_s.downcase)

    file_full_path = "#{Actual_Dir}/public/white_label/favicon_white_label.ico"
    File.open(file_full_path, 'wb') { |logo_file| logo_file.write(file.read) }

    if File.exist?(file_full_path)
      Confline.set_value('White_Label_Favicon_Present', 1, 0)
    else
      render(json: {msg: 'Favicon received but could not be saved to File System'}) and (return false)
    end

    render(json: {msg: 'ok'})
  end

  #================= PRIVATE ==================

  private

  def find_user
    @user = User.find_by(id: params[:user])
    return if @user.present?

    flash[:notice] = _('User_was_not_found')
    redirect_to(action: :index) && (return false)
  end

=begin rdoc
  if user wants to enable api key MUST enter at least 6 symbol key. if he disables api
  he may set valid api(at least 6 symbols) or not set at all

  *params*
  <tt>allow</tt> - true or false depending on what user wants
  <tt>key</tt> - secret api key
  *return*
  true if invalid or false if valid
=end
  def invalid_api_params?(allow_api, key)
    if allow_api
      key.to_s.length < 6
    else
      (1...6).include?(key.to_s.length)
    end
  end

  def validate_range(value, min, max, min_def = nil, max_def = nil)
    min_def ||= min.to_d
    max_def ||= max.to_d
    value = min_def.to_d if value.to_d < min.to_d
    value = max_def.to_d if value.to_d > max.to_d

    value
  end

  def direction_by_dst(dst)
    sql = 'SELECT directions.name AS direction_name, destinationgroups.name AS destinationgroup_name ' +
          'FROM directions JOIN destinations ON directions.code = destinations.direction_code ' +
          'LEFT JOIN destinationgroups ON destinations.destinationgroup_id = destinationgroups.id ' +
          "WHERE  destinations.prefix=SUBSTRING('#{dst}', 1, LENGTH(destinations.prefix)) " +
          'ORDER BY LENGTH(destinations.prefix) DESC LIMIT 1'
    res = ActiveRecord::Base.connection.select_all(sql)
    array = [_('Unknown'), _('Unknown')]

    if res and res[0]
      array[0] = res[0]['direction_name'] if res[0]['direction_name'].present?
      array[1] = res[0]['destinationgroup_name'] if res[0]['destinationgroup_name'].present?
    end

    array
  end

  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name)
    # replace all none alphanumeric, underscore or perioids with underscore
    just_filename.gsub(/[^\w\.\_]/, '_')
  end

  def set_valid_page_limit(field, limit, user)
    # required parameters:
    # field - expected values "Prepaid_Invoice_page_limit", "Invoice_page_limit".
    # limit - page limit. gots to be integer at least as smal as default page limit. if to small or smth else was passed set to default page limit
    # user - user id, gots to be integer. 0 for admin, 1 or more for others. theres no way to pretend that user id might be default in case it isn't valid
    default_page_limit = 1
    limit = (limit.to_i < default_page_limit) ? default_page_limit : limit.to_i
    Confline.set_value(field, limit, user)
  end

  def admin_only
    unless admin? || manager?
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :root and return false
    end
  end

  def test_email_admin_only
    unless admin?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end

  def check_pbx_addon
    unless pbx_active?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end

  def disable_xss_protection
    # Disabling this is probably not a good idea,
    # but the header causes Chrome to choke when being
    # redirected back after a submit and the page contains an iframe.
    response.headers['X-XSS-Protection'] = '0'
  end

  def copy_file(directory, name = params[:file].original_filename)
    if params[:file].present?
      path = File.join(directory, name)
      File.open(path, 'wb') { |file| file.write(params[:file].read) }
    end
  end

  def delete_generated_invoice_xlsx_files(user_id)
    numbers = M2Invoice.invoice_numbers_by_owner_id(user_id).map { |number| "/tmp/m2/invoices/#{number}.{xlsx,pdf}" }
    numbers.in_groups_of(20, false) do |numbers_group|
      `rm -rf #{numbers_group.join(' ')}`
    end
  end

  def check_if_request_ajax
    unless request.xhr?
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to(:root) && (return false)
    end
  end


  def set_paypal_amount_options(params)
    # min <= default <= max
    errors = []
    min_amount = params[:paypal_minimal_amount].to_i
    default_amount = params[:paypal_default_amount].to_i
    max_amount = params[:paypal_maximum_amount].present? ? params[:paypal_maximum_amount].to_i : ''

    if min_amount <= 0
      errors << _('Minimal_amount_must_be_greater_than_zero')
    end

    if default_amount < min_amount
      errors << _('Default_amount_must_be_greater_or_equal_than_Minimal_amount')
    end

    if max_amount.present? && default_amount > max_amount
      errors << _('Default_amount_must_be_less_or_equal_than_Maximum_amount')
    end

    if max_amount.present? && max_amount < min_amount
      errors << _('Maximum_amount_must_be_greater_or_equal_than_Minimal_amount')
    end

    if errors.blank?
      Confline.set_value('paypal_default_amount', default_amount)
      Confline.set_value('paypal_minimal_amount', min_amount)
      Confline.set_value('paypal_maximum_amount', max_amount)
    else
      flash_array_errors_for(_('Settings_were_not_updated'), errors)
    end
    errors.blank? ? 0 : 1
  end

  def set_two_fa_settings(params)
    Confline.set_value('2FA_Enabled', params[:two_fa_enabled].to_i)
    errors = []
    return 0 unless two_fa_enabled?

    # validate numbers
    two_fa_code_length = params[:two_fa_code_length].to_i
    two_fa_attemps_allowed = params[:two_fa_attemps_allowed].to_i
    two_fa_time_allowed = params[:two_fa_time_allowed].to_i

    errors << _('Code_length_must_be_number_between_2_and_20') if two_fa_code_length < 2 || two_fa_code_length > 20
    errors << _('Code_Enter_Attempts_Allowed_must_be_number_between_1_and_10') if two_fa_attemps_allowed < 1 || two_fa_attemps_allowed > 10
    errors << _('Code_Enter_Time_Allowed_must_be_number_between_2_and_300') if two_fa_time_allowed < 2 || two_fa_time_allowed > 300

    # validate email
    if params[:two_fa_send_notification_email_on_login].to_i == 1
      email_blank = params[:two_fa_notification_email_address].to_s.blank?
      errors << _('Email_can_not_be_empty') if email_blank
      errors << _('invalid_email') unless Email.address_validation(params[:two_fa_notification_email_address].to_s, true) && !email_blank
    end

    if errors.present?
      flash_array_errors_for(_('Settings_were_not_updated'), errors)
      return 1
    end

    # update settings
    Confline.set_two_fa_settings(params)
    0
  end
end
