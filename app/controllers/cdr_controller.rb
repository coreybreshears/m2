# M2 Cdr functionality
class CdrController < ApplicationController
  layout :determine_layout

  before_filter :check_localization
  before_filter :authorize
  before_filter :access_denied,
                unless: -> { admin? },
                only: [
                  :export_templates, :export_template_new, :export_template_create, :export_template_edit,
                  :export_template_update, :export_template_destroy,
                  :automatic_export_list, :automatic_export_new, :automatic_export_create, :automatic_export_edit,
                  :automatic_export_update, :automatic_export_destroy, :automatic_export_change_status,
                  :import_template_destroy, :import_templates, :import_template_new, :import_template_create,
                  :import_template_edit, :import_template_update
                ]
  before_filter :check_post_method, only: [
    :export_template_create, :export_template_update, :export_template_destroy,
    :automatic_export_create, :automatic_export_update, :automatic_export_destroy,
    :automatic_export_change_status,
    :import_template_create, :import_template_destroy, :export_template_update
  ]

  before_filter :cdr_import_for_dispute_checker, only: [:import_csv]

  # Import csv filters
  before_filter :set_import_csv_page_attributes, only: [:import_csv]
  before_filter :check_if_file_is_uploaded, only: [:import_csv], if: -> { get_step == 1 }
  before_filter :check_if_file_is_selected, only: [:import_csv], if: -> { get_step == 1 }
  before_filter :check_if_file_is_a_file, only: [:import_csv], if: -> { get_step == 1 }
  before_filter :check_if_file_is_csv, only: [:import_csv], if: -> { get_step == 1 }
  before_filter :check_if_file_is_in_session, only: [:import_csv], if: -> { get_step == 2 }
  before_filter :check_if_file_is_uploaded_into_db, only: [:import_csv], if: -> { get_step > 2 }
  before_filter :check_if_zero_file, only: [:import_csv], if: -> { get_step > 2 }
  before_filter :check_calldate_and_billsec, only: [:import_csv], if: -> { get_step == 3 }
  before_filter :check_if_colums_selected, only: [:import_csv], if: -> { get_step > 3 }
  before_filter :check_template_name, only: [:import_csv], if: -> { get_step == 3 }
  before_filter :check_providers, only: [:import_csv], if: -> { get_step == 4 }
  before_filter :check_params_provider, only: [:import_csv], if: -> { get_step == 5 }
  before_filter :set_cdr_import_csv2_session, only: [:import_csv], if: -> { get_step == 5 }
  before_filter :check_user_and_device, only: [:import_csv], if: -> { get_step == 5 }
  before_filter :check_clid_column, only: [:import_csv], if: -> { get_step == 5 }
  before_filter :check_create_caller_id, only: [:import_csv], if: -> { get_step == 7 }

  before_filter :check_if_table_is_in_db, only: [:fix_bad_cdr]
  before_filter :find_cdrs_for_cdr_fix, only: [:fix_bad_cdr]
  before_filter :check_if_cli_is_number, only: [:fix_bad_cdr]

  before_filter :check_rerating_time, only: [:rerating], if: -> { get_rerating_sep == 2 }
  before_filter :find_export_template, only: [:export_template_edit, :export_template_update, :export_template_destroy]
  before_filter :find_automatic_cdr_export, only: [
    :automatic_export_edit, :automatic_export_update, :automatic_export_destroy,
    :automatic_export_change_status
  ]
  before_filter :build_automatic_cdr_export, only: [
    :automatic_export_new, :automatic_export_create
  ]

  before_filter :find_import_template, only: [:import_template_edit, :import_template_update, :import_template_destroy]

  def index
    redirect_to :root
  end

  def import_csv
    case @step
      when 0 then
        import_csv_step_0
      when 1 then
        import_csv_step_1
      when 2 then
        import_csv_step_2
      when 3 then
        import_csv_step_3
      when 4 then
        import_csv_step_4
      when 5 then
        import_csv_step_5
      when 6 then
        import_csv_step_6
      when 7 then
        import_csv_step_7
      when 8 then
        import_csv_step_8
      when 9 then
        import_csv_step_9
    end
  end

  def cli_add
    @dev = Device.where(id: params[:device_id].to_i).first
    @cli = Callerid.where(id: params[:id].to_i).first

    if @dev && @cli
      @cli.device = @dev
      @cli.added_at = Time.now
      @cli.save
    else
      @error = _('Device_or_Cli_not_found')
      @users = User.select("users.*, #{SqlExport.nice_user_sql}")
                   .joins('JOIN devices ON (users.id = devices.user_id)')
                   .where("hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}")
                   .order('nice_user ASC').group('users.id').all
    end
    render(layout: false) && (return false)
  end

  def fix_bad_cdr
    MorLog.my_debug update_bad_cdrs_sql
    ActiveRecord::Base.connection.execute(update_bad_cdrs_sql)

    if Call.where(calldate: params[:calldate], billsec: params[:billsec], dst: params[:dst]).first
      @error = _('CDR_exist_in_db_match_call_date_dst_src')
    else
      id = params[:id].to_i
      sql = "SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 0 and id = #{id}"
      @cdr = ActiveRecord::Base.connection.select_all(sql)
    end
    render(layout: false)
  end

  def not_import_bad_cdr
    @cdr = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 and id = #{params[:id].to_i} LIMIT 1")

    if @cdr
      ActiveRecord::Base.connection.execute("UPDATE #{session[:temp_cdr_import_csv]} SET do_not_import = 1 WHERE f_error = 1 and id = #{params[:id].to_i}")
      @cdr = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE do_not_import = 1 and id = #{params[:id].to_i}")
    else
      @error = _('CDR_not_found')
    end
    render(layout: false) && (return false)
  end

  def bad_rows_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    params_name = params[:name]

    if ActiveRecord::Base.connection.tables.include?(params_name)
      @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{params_name} WHERE f_error = 1")
    end
    session[:company] = Confline.get_value('Company', 0)
    render(layout: 'layouts/mor_min')
  end

  def rerating
    @step = get_rerating_sep
    @step_name = [nil, _('Select_details'), _('Confirm'), _('Status')][@step]

    @page_title = _('CDR_Rerating') + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + _('Step') + ': ' + @step.to_s + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + @step_name
    @page_icon = 'coins.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/CDR_Rerating'

    rerating_step_1 if @step == 1
    rerating_step_2 if @step == 2
    rerating_step_3 if @step == 3
  end

  def export_templates
    @templates = CdrExportTemplate.all
  end

  def export_template_new
    @template = CdrExportTemplate.new
  end

  def export_template_create
    @page_title = _('New_CDR_Export_Template')

    @template = CdrExportTemplate.new(name: params[:template][:name].strip, columns: params[:columns].values.join(';'))

    if @template.save
      flash[:status] = _('CDR_Export_Template_successfully_created')
      redirect_to action: :export_templates
    else
      flash_errors_for(_('CDR_Export_Template_was_not_created'), @template)
      render :export_template_new
    end
  end

  def export_template_edit
  end

  def export_template_update
    if @template.update_attributes(name: params[:template][:name].strip, columns: params[:columns].values.join(';'))
      flash[:status] = _('CDR_Export_Template_successfully_updated')
      redirect_to action: :export_templates
    else
      flash_errors_for(_('CDR_Export_Template_was_not_updated'), @template)
      render :export_template_edit
    end
  end

  def export_template_destroy
    if @template.destroy
      flash[:status] = _('CDR_Export_Template_successfully_deleted')
    else
      flash_errors_for(_('CDR_Export_Template_was_not_deleted'), @template)
    end
    redirect_to action: :export_templates
  end

  def automatic_export_list
    @automatic_cdr_exports = AutomaticCdrExport.where(user_id: current_user_id)
  end

  def automatic_export_new
  end

  def automatic_export_create
    @automatic_cdr_export.update_from_params(params)

    if @automatic_cdr_export.save
      flash[:status] = _('Automatic_CDR_Export_successfully_created')
      redirect_to action: :automatic_export_list
    else
      flash_errors_for(_('Automatic_CDR_Export_was_not_created'), @automatic_cdr_export)
      render :automatic_export_new
    end
  end

  def automatic_export_edit
  end

  def automatic_export_update
    @automatic_cdr_export.update_from_params(params)

    if @automatic_cdr_export.save
      flash[:status] = _('Automatic_CDR_Export_successfully_updated')
      redirect_to action: :automatic_export_list
    else
      flash_errors_for(_('Automatic_CDR_Export_was_not_updated'), @automatic_cdr_export)
      render :automatic_export_edit
    end
  end

  def automatic_export_destroy
    if @automatic_cdr_export.destroy
      flash[:status] = _('Automatic_CDR_Export_successfully_deleted')
    else
      dont_be_so_smart
    end
    redirect_to action: :automatic_export_list
  end

  def automatic_export_change_status
    flash[:status] = (@automatic_cdr_export.change_active_status == 1) ? _('Automatic_CDR_Export_enabled') : _('Automatic_CDR_Export_disabled')
    redirect_to action: :automatic_export_list
  end

  def import_templates
    @templates = CdrImportTemplate.all
  end

  def import_template_new
    @template = CdrImportTemplate.new
  end

  def import_template_create
    @page_title = _('New_CDR_Export_Template')

    template_param = params[:template]
    @template = CdrImportTemplate.new(name: template_param[:name].strip,
                                      column_seperator: template_param[:column_seperator],
                                      decimal_seperator: template_param[:decimal_seperator],
                                      date_format: params[:date_format],
                                      skip_n_first_lines: template_param[:skip_n_first_lines],
                                      start_time_col: template_param[:start_time_col],
                                      billsec_col: template_param[:billsec_col],
                                      dst_col: template_param[:dst_col],
                                      answer_time_col: template_param[:answer_time_col],
                                      end_time_col: template_param[:end_time_col],
                                      clid_col: nil, # template_param[:clid_col],
                                      src_name_col: nil, # template_param[:src_name_col],
                                      src_number_col: template_param[:src_number_col],
                                      duration_col: template_param[:duration_col],
                                      disposition_col: template_param[:disposition_col],
                                      accountcode_col: template_param[:accountcode_col],
                                      provider_id_col: template_param[:provider_id_col],
                                      cost_col: template_param[:cost_col],
                                      hangupcause_col: template_param[:hangupcause_col]
                                     )
    import_template_create_save(@template)
  end

  def import_template_create_save(template)
    if template.save
      flash[:status] = _('CDR_Import_Template_successfully_created')
      redirect_to action: :import_templates
    else
      flash_errors_for(_('CDR_Import_Template_was_not_created'), template)
      render :import_template_new
    end
  end

  def import_template_destroy
    if @template.destroy
      flash[:status] = _('CDR_Import_Template_successfully_deleted')
    else
      flash_errors_for(_('CDR_Import_Template_was_not_deleted'), @template)
    end
    redirect_to action: :import_templates
  end

  def import_template_edit
  end

  def import_template_update
    template_param = params[:template]
    @template.update_attributes(name: template_param[:name].strip,
                                column_seperator: template_param[:column_seperator],
                                decimal_seperator: template_param[:decimal_seperator],
                                date_format: params[:date_format],
                                skip_n_first_lines: template_param[:skip_n_first_lines],
                                start_time_col: template_param[:start_time_col],
                                billsec_col: template_param[:billsec_col],
                                dst_col: template_param[:dst_col],
                                answer_time_col: template_param[:answer_time_col],
                                end_time_col: template_param[:end_time_col],
                                clid_col: nil, # template_param[:clid_col],
                                src_name_col: nil, # template_param[:src_name_col],
                                src_number_col: template_param[:src_number_col],
                                duration_col: template_param[:duration_col],
                                disposition_col: template_param[:disposition_col],
                                accountcode_col: template_param[:accountcode_col],
                                provider_id_col: template_param[:provider_id_col],
                                cost_col: template_param[:cost_col],
                                hangupcause_col: template_param[:hangupcause_col]
                               )

    import_template_update_save(@template)
  end

  def import_template_update_save(template)
    if template.save
      template.save
      flash[:status] = _('CDR_Import_Template_successfully_updated')
      redirect_to action: :import_templates
    else
      flash_errors_for(_('CDR_Import_Template_was_not_updated'), template)
      render :import_template_edit
    end
  end

  private

  def cdr_import_for_dispute_checker
    return if params[:step].blank?
    flash[:dispute_id_cdr_import] = dispute_id_cdr_import = flash[:dispute_id_cdr_import].to_i

    if dispute_id_cdr_import > 0 && DisputedCdr.where(dispute_id: dispute_id_cdr_import).first.present?
      flash[:notice] = _('CDR_Import_cannot_be_imported_more_than_once_for_same_CDR_Dispute')
      redirect_to(controller: :cdr_disputes, action: :list) && (return false)
    end
  end

  def find_export_template
    @template = CdrExportTemplate.where(id: params[:id]).first
    return if @template
    flash[:notice] = _('CDR_Export_Template_was_not_found')
    redirect_to(action: :export_templates) && (return false)
  end

  def find_import_template
    @template = CdrImportTemplate.where(id: params[:id]).first
    return if @template
    flash[:notice] = _('CDR_Import_Template_was_not_found')
    redirect_to(action: :import_templates) && (return false)
  end

  def find_automatic_cdr_export
    @automatic_cdr_export = AutomaticCdrExport.where(id: params[:id], user_id: current_user_id).first
    return if @automatic_cdr_export
    flash[:notice] = _('Automatic_CDR_Export_was_not_found')
    redirect_to(action: :automatic_export_list) && (return false)
  end

  def build_automatic_cdr_export
    @automatic_cdr_export = AutomaticCdrExport.build_new(current_user)
  end

  def return_correct_select_value(param)
    param ? param.to_i : -1
  end

  def rerating_step_1
    @number_of_users = User.count
    @tariffs = Tariff.all.order(:name)
  end

  def rerating_step_2
    commit_type = params[:commit]
    @user_id = (params[:all_users].to_i == 1) ? -1 : params[:s_user_id]
    if commit_type == _('Rerate')
      try_to_rerate_in_background
    else
      set_rerating_2_session

      users = (@user_id == -1) ? User.all : [User.where(id: @user_id).first].compact
      if users.blank?
        flash[:notice] = _('User_not_found')
        redirect_to(action: :rerating, s_user: params[:s_user], s_user_id: @user_id) && (return false)
      end

      callculate_stats_for_rerating_2(users)
      flash[:notice] = _('No_calls_to_rerate') if @total_calls == 0
    end
  end

  def rerating_step_3
    @user_id = params[:s_user_id]
    users = []

    if @user_id == -1
      users = User.includes(:tariff).all
    else
      user = User.includes(:tariff).where('users.id = ?', @user_id).first
      users << user if user
    end

    if users.blank?
      flash[:notice] = _('User_not_found')
      redirect_to(action: :rerating, s_user: params[:s_user], s_user_id: @user_id) && (return false)
    end

    @old_billsec = params[:billsec].to_i
    @old_provider_price = 0.to_d
    @old_reseller_price = 0.to_d
    @old_user_price = 0.to_d

    test_tariff_id = session[:rerating_testing_tariff_id].to_i

    @billsec = 0
    @provider_price = 0
    @reseller_price = 0
    @user_price = 0
    @total_calls = 0
    @total_users = 0

    for @user in users
      next unless @user
      @calls = @user.calls('answered', session_from_datetime, session_till_datetime)

      if @calls.present?
        @total_calls += @calls.size
        @total_users += 1
      end

      one_user_price = 0
      one_old_user_price = 0
      one_old_provider_price = 0

      @calls.each do |call|
        grace_time = Device.where(id: call.src_device_id).first.try(:grace_time).to_i
        grace = ((call.billsec.to_i > grace_time) ? false : true)

        one_old_user_price += call.user_price.to_d
        one_old_provider_price += call.provider_price.to_d

        call = call.count_cdr2call_details(nil, @user, test_tariff_id) if call.user_id && !grace
        call.user_price = 0.to_d and call.user_rate = 0.to_d if grace

        one_user_price += call.user_price.to_d

        @billsec += call.billsec
        @provider_price += call.provider_price.to_d
      end

      @user_price += one_user_price

      @old_provider_price += one_old_provider_price.to_d
      @old_user_price += one_old_user_price.to_d

      @user.balance = @user.balance - (one_user_price - one_old_user_price)
    end

    flash[:status] = _('Rerating_completed')
  end

  def try_to_rerate_in_background
    BackgroundTask.create(
      task_id: 1,
      owner_id: current_user_id,
      created_at: Time.zone.now,
      status: 'WAITING',
      user_id: params[:s_user_id].to_i,
      data1: session_from_datetime,
      data2: session_till_datetime,
      data3: params[:rerate_as].to_i
    )
    flash[:status] = _('bg_task_for_rerating_successfully_created')
    if manager? && !authorize_manager_permissions(controller: :functions, action: :background_tasks, no_redirect_return: 1)
      redirect_to controller: 'cdr', action: 'rerating'
    else
      redirect_to controller: 'functions', action: 'background_tasks'
    end
  end

  def set_rerating_2_session
    session[:rerating_user_id], session[:rerating_testing_tariff_id] = [params[:s_user_id].to_i, params[:test_tariff_id].to_i]
  end

  def check_rerating_time
    change_date

    if Time.parse(session_from_datetime) > Time.parse(session_till_datetime)
      test_tariff_id = params[:test_tariff_id]
      session[:rerating_testing_tariff_id] = test_tariff_id.to_i if test_tariff_id.present?
      params_user_id = params[:s_user_id]
      session[:rerating_user_id] = params_user_id.to_i if params_user_id.present?
      flash[:notice] = _('Date_from_greater_thant_date_till')
      redirect_to(action: :rerating)
      return false
    end
  end

  def callculate_stats_for_rerating_2(users)
    @calls_stats = 0
    @billsec = 0
    @provider_price = 0
    @reseller_price = 0
    @user_price = 0
    @total_calls = 0
    @users_with_calls = 0

    for @user in users
      @calls_stats = @user.calls_total_stats('answered', session_from_datetime, session_till_datetime)
      total_calls = @calls_stats['total_calls'].to_i
      @billsec += @calls_stats['total_billsec'].to_d
      @provider_price += @calls_stats['total_provider_price'].to_d
      @reseller_price += @calls_stats['total_reseller_price'].to_d
      @user_price += @calls_stats['total_user_price'].to_d
      @total_calls += total_calls
      @users_with_calls += 1 if total_calls > 0
    end
  end

  # ======== CSV IMPORT =================

  def import_csv_step_0
    @cdr_import_templates = CdrImportTemplate.all
    my_debug_time '**********import CDR ************************'
    my_debug_time 'step 0'
    nullify = %i[cdr_import_csv temp_cdr_import_csv import_csv_cdr_import_csv_options cdrs_import]
    nullify.each { |key| session[key] = nil }
    session[:file_lines] = 0
  end

  def import_csv_step_1
    nullify = %i[temp_cdr_import_csv cdr_import_csv cdrs_import]
    nullify.each { |key| session[key] = nil }

    @file = params[:file]
    @file.rewind
    encoding_params = {invalid: :replace, undef: :replace, replace: '?'}
    file = @file.read.force_encoding('UTF-8').encode('UTF-8', encoding_params)
    session[:cdr_file_size] = file.size
    session[:temp_cdr_import_csv] = CsvImportDb.save_file('_crd_', file)
    flash[:status] = _('File_downloaded')
    cdr_import_id = params[:cdr_import_id]
    if cdr_import_id && cdr_import_id.to_i > 0
      # Using CDR template
      import_csv_with_template
    else
      redirect_to(action: :import_csv, step: 2) && (return false)
    end
  end

  def import_csv_with_template
    template = CdrImportTemplate.where(id: params[:cdr_import_id].to_i).first
    path = "/tmp/#{session[:temp_cdr_import_csv]}.csv"
    @fl = CsvImportDb.head_of_file(path, 1).join('').to_s.split(template.column_seperator)
    file = CsvImportDb.head_of_file(path, 20).join
    save_file_in_session(file, template, @fl)
    @options = template.import_options(session[:cdr_import_csv])
    @options[:file] = file
    @options[:file_lines] = session[:file_lines]
    session[:cdr_import_csv2] = @options
    redirect_csv_template(template)
  end

  def save_file_in_session(file, template, fl)
    colums = default_colums
    temp_cdr_import_csv = session[:temp_cdr_import_csv]
    colums[:lines_to_skip] = template.skip_n_first_lines.to_i
    session[:file] = file
    session[:cdr_import_csv] = CsvImportDb.load_csv_into_db(
      temp_cdr_import_csv, template.column_seperator,
      template.decimal_seperator, fl, nil, colums
    )
    file_lines_sql = "SELECT COUNT(*) FROM #{temp_cdr_import_csv}"
    session[:file_lines] = ActiveRecord::Base.connection.select_value(file_lines_sql)
  end

  def redirect_csv_template(template)
    redirect_to(action: 'import_csv', step: 3, calldate_id: template.start_time_col,
                billsec_id: template.billsec_col, dst_id: template.dst_col,
                create_from_template: true)
    flash[:status] = _('Columns_assigned')
  end

  def import_csv_step_2
    temp_cdr_import_csv = session[:temp_cdr_import_csv]
    path = "/tmp/#{temp_cdr_import_csv}.csv"
    file = CsvImportDb.head_of_file(path, 20).join
    session[:file] = file
    if check_csv_file_seperators(file, 2, 2, line: 0)

      @fl = CsvImportDb.head_of_file(path, 1).join('').to_s.split(@sep)
      begin
        session[:cdr_import_csv] = CsvImportDb.load_csv_into_db(
          temp_cdr_import_csv, @sep, @dec, @fl, nil, default_colums
        )
        file_lines_sql = "SELECT COUNT(*) FROM #{temp_cdr_import_csv}"
        session[:file_lines] = ActiveRecord::Base.connection.select_value(file_lines_sql)
      rescue => exc
        exception_in_csv_import_step_2
        redirect_to(action: 'import_csv', step: 2) && (return false)
      end
      flash[:status] = _('File_uploaded') unless flash[:notice]
    end
  end

  def import_csv_step_3
    file_lines_sql = "SELECT COUNT(*) FROM #{session[:temp_cdr_import_csv]}"
    file_lines = ActiveRecord::Base.connection.select_value(file_lines_sql)
    unless params[:create_from_template]
      save_template = params[:save_template]
      date_format = Confline.get_value('Date_format', correct_owner_id).to_s
      @options = {
        imp_calldate: return_correct_select_value(params[:calldate_id]),
        imp_date: -1,
        imp_time: -1,
        imp_clid: return_correct_select_value(params[:clid_id]),
        imp_src_name: return_correct_select_value(params[:src_name_id]),
        imp_src_number: return_correct_select_value(params[:src_number_id]),
        imp_dst: return_correct_select_value(params[:dst_id]),
        imp_duration: return_correct_select_value(params[:duration_id]),
        imp_billsec: return_correct_select_value(params[:billsec_id]),
        imp_disposition: return_correct_select_value(params[:disposition_id]),
        imp_accountcode: return_correct_select_value(params[:accountcode_id]),
        imp_provider_id: return_correct_select_value(params[:provider_id]),
        sep: @sep,
        dec: @dec,
        file: session[:file],
        file_lines: file_lines,
        template_name: params[:template_name],
        save_template: save_template,
        date_format: date_format.presence || '%Y-%m-%d %H:%M:%S',
        imp_hangup_cause: return_correct_select_value(params[:hangupcause])
      }
      create_template_from_import(@options) if save_template.present?
      session[:cdr_import_csv2] = @options
    else
      cdr_import_session = session[:cdr_import_csv2]
      @sep = cdr_import_session[:sep]
      @dec = cdr_import_session[:dec]
    end
    flash[:status] = _('Columns_assigned')
  end

  def create_template_from_import(options)
    CdrImportTemplate.create(name: options[:template_name].strip,
                             column_seperator: options[:sep],
                             decimal_seperator: options[:dec],
                             date_format: Confline.get_value('Date_format', correct_owner_id).to_s,
                             start_time_col: options[:imp_calldate],
                             billsec_col: options[:imp_billsec],
                             dst_col: options[:imp_dst],
                             clid_col: nil, # options[:imp_clid],
                             src_name_col: nil, # options[:imp_src_name],
                             src_number_col: options[:imp_src_number],
                             duration_col: options[:imp_duration],
                             disposition_col: options[:imp_disposition],
                             accountcode_col: options[:imp_accountcode],
                             provider_id_col: options[:imp_provider_id],
                             hangupcause_col: options[:imp_hangup_cause]
                            )
  end

  def import_csv_step_4
    dispute_id_cdr_import = flash[:dispute_id_cdr_import].to_i
    if dispute_id_cdr_import > 0
      DisputedCdr.import_from_temp_csv_cdr_table(dispute_id_cdr_import, session[:temp_cdr_import_csv], session[:cdr_import_csv2])
      flash[:status] = _('CDR_Import_for_Dispute_status').gsub('|:Web_Dir:|', Web_Dir)
      redirect_to(controller: :cdr_disputes, action: :list) && (return false)
    else
      @users = User.select("users.*, #{SqlExport.nice_user_sql}")
                   .joins('LEFT JOIN devices ON (users.id = devices.user_id)')
                   .where("hidden = 0 AND usertype != 'manager' AND owner_id = #{correct_owner_id}")
                   .order('nice_user ASC').group('users.id').all
    end
  end

  # check how many destinations and should we create new ones?
  def import_csv_step_5
    my_debug_time 'step 5'
    @new_step = 6
    (session[:cdr_import_csv2][:import_type].to_i == 0) ? import_by_user : import_by_callerid
  end

  # fix bad cdrs
  def import_csv_step_6
    my_debug_time 'step 6'
    @cdr_analize = session[:cdr_analize]
    @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
    @options = session[:cdrs_import] || {}
    # search
    @options[:page] = params[:page].try(:to_i) || @options[:page] || 1
    @options[:hide] = params[:hide_error].try(:to_i) || @options[:hide] || 0

    cond = (@options[:hide].to_i > 0) ? ' AND nice_error != 2' : ''
    temp_cdr_import_session = session[:temp_cdr_import_csv]
    number_sql = "SELECT COUNT(*) FROM #{temp_cdr_import_session} WHERE f_error = 1 #{cond}"
    bad_cdrs_number = ActiveRecord::Base.connection.select_value(number_sql).to_d
    fpage, @total_pages, @options = Application.pages_validator(session, @options, bad_cdrs_number)

    all_sql = "SELECT *
               FROM #{temp_cdr_import_session}
               WHERE f_error = 1 #{cond}
               LIMIT #{fpage}, #{session[:items_per_page]}"
    @import_cdrs = ActiveRecord::Base.connection.select_all(all_sql)
    @next_step = (session[:cdr_import_csv2][:create_callerid].to_i == 0) ? 9 : 7
    @providers = Device.termination_points.all
  end

  def import_csv_step_7
    my_debug_time 'step 7'
    temp_cdr_import_session = session[:temp_cdr_import_csv]
    cdr_import_csv2 = session[:cdr_import_csv2]
    @cdr_analize = Call.analize_cdr_import(temp_cdr_import_session, cdr_import_csv2)
    @cdr_analize[:file_lines] = cdr_import_csv2[:file_lines]
    cclid = Callerid.create_from_csv(temp_cdr_import_session, cdr_import_csv2)
    flash[:status] = _('Create_clis') + ": #{cclid.to_i}"
  end

  # assigne clis
  def import_csv_step_8
    my_debug_time 'step 8'
    session[:cdr_import_csv2][:step] = 8
    @options = session[:cdrs_import2].presence || {}
    # search
    @options[:page] = params[:page] ? params[:page].to_i : (1 unless @options[:page])

    @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
    @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]

    fpage, @total_pages, @options = Application.pages_validator(session, @options, Callerid.where(device_id: -1).all.size.to_d, params[:page])
    @clis = Callerid.where(device_id: -1).offset(fpage).limit(session[:items_per_page]).all

    @users = User.select("users.*, #{SqlExport.nice_user_sql}").joins('JOIN devices ON (users.id = devices.user_id)').where("hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}").order('nice_user ASC').group('users.id')
  end

  # create cdrs with user and device
  def import_csv_step_9
    my_debug_time 'step 9'
    start_time = Time.now
    @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
    @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
    begin
      @total_cdrs, @errors = Call.insert_cdrs_from_csv(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
      flash[:status] = _('Import_completed')
      session[:temp_cdr_import_csv] = nil
      @run_time = Time.now - start_time
      MorLog.my_debug Time.now - start_time
    rescue => exception
      flash[:notice] = _('Error')
      MorLog.log_exception(exception, Time.now, 'CDR', 'csv_import')
    end
  end

  def set_import_csv_page_attributes
    @step = get_step
    @step_name = step_names[@step]

    @page_title = _('Import_CSV') + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + _('Step') + ': ' +
        @step.to_s + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + @step_name.to_s
    @page_icon = 'excel.png'

    @sep, @dec = Application.nice_action_session_csv(params, session, correct_owner_id)
  end

  def check_if_file_is_uploaded
    my_debug_time 'step 1'
    return if params[:file]
    session[:temp_cdr_import_csv] = nil
    flash[:notice] = _('Please_upload_file')
    redirect_to(action: :import_csv, step: 0) && (return false)
  end

  def check_if_file_is_selected
    return if params[:file].present?
    session[:temp_cdr_import_csv] = nil
    flash[:notice] = _('Please_select_file')
    redirect_to(action: :import_csv, step: 0) && (return false)
  end

  def check_if_file_is_a_file
    file = params[:file]
    if !file.respond_to?(:original_filename) || !file.respond_to?(:read) || !file.respond_to?(:rewind)
      flash[:notice] = _('Please_select_file')
      redirect_to(action: :import_csv, step: 0) && (return false)
    end
  end

  def check_if_file_is_csv
    file = params[:file]
    return if get_file_ext(file.original_filename, 'csv')
    file.original_filename
    flash[:notice] = _('Please_select_CSV_file')
    redirect_to(action: :import_csv, step: 0) && (return false)
  end

  def check_if_file_is_in_session
    temp_cdr_import_csv = session[:temp_cdr_import_csv]
    my_debug_time 'step 2'
    my_debug_time "use : #{temp_cdr_import_csv}"
    return if temp_cdr_import_csv
    session[:cdr_import_csv] = nil
    flash[:notice] = _('Please_upload_file')
    redirect_to(action: :import_csv, step: 1) && (return false)
  end

  def exception_in_csv_import_step_2
    MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
    temp_cdr_import_csv = session[:temp_cdr_import_csv]
    session[:import_csv_cdr_import_csv_options] = {sep: @sep, dec: @dec}
    session[:file] = File.open("/tmp/#{temp_cdr_import_csv}.csv", 'rb').read
    CsvImportDb.clean_after_import(temp_cdr_import_csv)
    session[:temp_cdr_import_csv] = nil
  end

  def default_colums
    {
      colums: [
        {name: 'f_error', type: 'INT(4)', default: 0},
        {name: 'nice_error', type: 'INT(4)', default: 0},
        {name: 'do_not_import', type: 'INT(4)', default: 0},
        {name: 'changed', type: 'INT(4)', default: 0},
        {name: 'not_found_in_db', type: 'INT(4)', default: 0},
        {name: 'id', type: 'INT(11)', inscrement: ' NOT NULL auto_increment '}
      ]
    }
  end

  def check_if_file_is_uploaded_into_db
    return if ActiveRecord::Base.connection.tables.include?(session[:temp_cdr_import_csv])
    flash[:notice] = _('Please_upload_file')
    redirect_to(action: :import_csv, step: 0) && (return false)
  end

  def check_if_zero_file
    return if session[:cdr_import_csv]
    flash[:notice] = _('Zero_file')
    redirect_to(controller: 'tariffs', action: 'list') && (return false)
  end

  def check_calldate_and_billsec
    my_debug_time 'step 3'
    calldate_id = params[:calldate_id]
    billsec_id = params[:billsec_id]
    dst_id = params[:dst_id]
    calldate_valid = calldate_id && (calldate_id.to_i >= 0)
    billsec_valid = billsec_id && (billsec_id.to_i >= 0)
    dst_valid = dst_id && (dst_id.to_i >= 0)
    unless calldate_valid && billsec_valid && dst_valid
      flash[:notice] = _('Please_Select_Columns')
      redirect_to(action: :import_csv, step: 2) && (return false)
    end
  end

  def step_names
    [
      _('Import_CDR'), _('File_upload'), _('Column_assignment'), _('Column_confirmation'),
      _('Select_details'), _('Analysis'), _('Fix_clis'), _('Create_clis'), _('Assign_clis'),
      _('Import_CDR')
    ]
  end

  def get_step
    unless @step
      @step = params[:step].try(:to_i) || 0
      @step = 0 if (@step > step_names.size) || (@step < 0)
    end
    @step
  end

  def get_rerating_sep
    @sep ||= params[:step].try(:to_i) || 1
  end

  def check_if_colums_selected
    cdr_import_session = session[:cdr_import_csv2]
    return if cdr_import_session && cdr_import_session[:imp_calldate] &&
              cdr_import_session[:imp_billsec]
    flash[:notice] = _('Please_Select_Columns')
    redirect_to(action: :import_csv, step: '2') && (return false)
  end

  def check_template_name
    my_debug_time 'step 3'
    if params[:save_template]
      template_name = params[:template_name]
      if template_name.blank?
        flash[:notice] = _('Name_cannot_be_blank')
        redirect_to(action: :import_csv, step: 2) && (return false)
      elsif CdrImportTemplate.where(name: template_name).any?
        flash[:notice] = _('Name_must_be_unique')
        redirect_to(action: :import_csv, step: 2) && (return false)
      end
    end
  end

  def check_providers
    my_debug_time 'step 4'
    @providers = Device.termination_points.order(:description).all
    if !@providers or @providers.size.to_i < 1
      flash[:notice] = _('No_Providers')
      redirect_to(action: :import_csv, step: 0) && (return false)
    end
  end

  def check_params_provider
    imp_provider_id = session[:cdr_import_csv2][:imp_provider_id]
    params[:provider] = imp_provider_id if imp_provider_id.to_i > -1
    return if params[:provider]
    flash[:notice] = _('Please_select_Provider')
    redirect_to(action: :import_csv, step: 4) && (return false)
  end

  def set_cdr_import_csv2_session
    session[:cdr_import_csv2].merge!(
      import_type: params[:import_type].to_i,
      import_provider: params[:provider].to_i
    )
    if session[:cdr_import_csv2][:import_type].to_i == 0
      # import by user
      session[:cdr_import_csv2].merge!(
        import_user: params[:user].to_i,
        import_device: params[:device_id].to_i
      )
    else
      # import by CallerID
      session[:cdr_import_csv2][:create_callerid] = params[:create_callerid].to_i
    end
  end

  def check_user_and_device
    user = User.where(id: params[:user]).first
    device = Device.where(id: params[:device_id]).first
    importing_by_user = session[:cdr_import_csv2][:import_type].to_i == 0
    if importing_by_user && (!user || !device)
      flash[:notice] = _('User_and_Device_is_bad')
      redirect_to(action: :import_csv, step: 4) && (return false)
    end
  end

  def check_clid_column
    cdr_import_csv2 = session[:cdr_import_csv2]
    importing_by_callerid = cdr_import_csv2[:import_type].to_i != 0
    if cdr_import_csv2[:imp_clid].to_i == -1 && importing_by_callerid
      flash[:notice] = _('Please_select_CLID_column')
      redirect_to(action: :import_csv, step: 2) && (return false)
    end
  end

  def import_by_user
    cdr_import_csv2 = session[:cdr_import_csv2]
    @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], cdr_import_csv2)
    @new_step = 9
    @cdr_analize[:file_lines] = cdr_import_csv2[:file_lines]
    session[:cdr_analize] = @cdr_analize
  end

  def import_by_callerid
    @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
    @new_step = 9 if @cdr_analize[:bad_clis].to_i == 0 and @cdr_analize[:new_clis_to_create].to_i == 0
    flash[:status] = _('Analysis_completed')
    @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
    session[:cdr_analize] = @cdr_analize
  end

  def check_create_caller_id
    return if session[:cdr_import_csv2][:create_callerid].to_i == 1
    dont_be_so_smart
    redirect_to(action: :import_csv, step: 6) && (return false)
  end

  def check_if_table_is_in_db
    return if ActiveRecord::Base.connection.tables.include?(session[:temp_cdr_import_csv])
    @error = _('CDR_not_found')
    redirect_to(layout: false) && (return false)
  end

  def find_cdrs_for_cdr_fix
    sql = "SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 and id = #{params[:id].to_i}"
    MorLog.my_debug sql
    @cdr = ActiveRecord::Base.connection.select_all(sql)

    return if @cdr && @cdr.present?
    @error = _('CDR_not_found')
    render(layout: false) && (return false)
  end

  def check_if_cli_is_number
    return if params[:cli].to_s.match(/^[0-9]+$/)
    @error = _('CLI_is_not_number')
    render(layout: false) && (return false)
  end

  def update_bad_cdrs_sql
    id = params[:id].to_i
    cli = params[:cli]
    calldate = params[:calldate]
    dst = params[:dst]
    billsec = params[:billsec]
    source_number = params[:src_number]
    provider_id = params[:provider_id].to_i

    cdr_import_csv2 = session[:cdr_import_csv2]

    if cdr_import_csv2[:imp_provider_id].to_i > -1 and provider_id > 0
      imp_providers = ", col_#{cdr_import_csv2[:imp_provider_id]} = '#{provider_id}'"
    end

    "UPDATE #{session[:temp_cdr_import_csv]}
    SET col_#{cdr_import_csv2[:imp_clid]} = '#{cli}',
        col_#{cdr_import_csv2[:imp_calldate]} = '#{calldate}',
        col_#{cdr_import_csv2[:imp_billsec]} = '#{billsec}',
        col_#{cdr_import_csv2[:imp_dst]} = '#{dst}',
        f_error = 0,
        changed = 1
        #{imp_providers}
    WHERE f_error = 1 and id = #{id}"
  end
end
