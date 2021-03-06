# Destination Groups management
class DestinationGroupsController < ApplicationController
  layout :determine_layout
  before_filter :check_post_method, only: [:destroy, :create, :update, :dg_add_destinations, :dg_destination_delete, :csv_file_upload]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, only: [:dg_destination_delete, :dg_destination_stats]
  before_filter :save_params,
                only: [
                    :bulk_management_confirmation, :bulk_rename_confirm, :bulk, :list,
                    :bulk_management_merge_confirmation, :bulk_management_merge
                ]
  before_filter :find_destination_group,
                only: [
                    :bulk_management_confirmation, :bulk_assign, :edit, :update, :destroy, :destinations,
                    :dg_new_destinations, :dg_add_destinations, :dg_list_user_destinations, :stats
                ]
  before_filter :strip_params, only: [:create, :update]
  before_filter :authorize_import, only: [:csv_upload, :csv_file_upload, :map_results, :prefix_import, :cancel_prefix_import]
  before_filter :validate_upload, only: [:csv_file_upload]
  before_filter :search_options_for_invalid_lines, only: [:invalid_lines]

  def list
    @page_title = _('Destination_groups')
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Destinations_Groups'

    @st = 'A'
    @st = params[:st].upcase if params[:st]
    @destinationgroups = Destinationgroup.where("name like ?", @st+'%').order('name ASC')
    store_location
  end

  def list_json
    render json: Destinationgroup.get_destination_groups.to_json
  end

  def new
    @page_title = _('New_destination_group')
    @dg = Destinationgroup.new
  end

  def create
    @dg = Destinationgroup.new(params[:dg])
    if @dg.save
      flash[:status] = _('Destination_group_was_successfully_created')
      redirect_to action: :list, st: @dg.name[0, 1]
    else
      flash[:notice] = _('Destination_group_was_not_created')
      redirect_to action: :new
    end
  end

  def edit
    @page_title = _('Edit_destination_group')
  end

  def update
    if @dg.update_attributes(params[:dg])
      flash[:status] = _('Destination_group_was_successfully_updated')
      redirect_to action: :list, st: @dg.name[0, 1]
    else
      flash[:notice] = _('Destination_group_was_not_updated')
      redirect_to action: :new
    end
  end

  def destroy
    dg_id = @dg.id
    dg_first_letter = @dg.name[0, 1]
    message = ": #{@dg.name}"
    if @dg.rates.size > 0
      flash[:notice] = _('Cant_delete_destination_group_rates_exist') + message
      redirect_to(action: :list, st: dg_first_letter) && (return false)
    end

    if Alert.where(check_type: 'destination_group', check_data: dg_id).first
      flash[:notice] = _('Cant_delete_destination_group_alerts_exist')
      redirect_to(action: :list, st: dg_first_letter) && (return false)
    end

    sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE destinationgroup_id = '#{dg_id}'"
    res = ActiveRecord::Base.connection.update(sql)

    @dg.destroy
    flash[:status] = _('Destination_group_deleted') + message
    redirect_to action: :list, st: dg_first_letter
  end

  def destinations
    @page_title = _('Destinations')
    @destinations = @destgroup.destinations.includes(:direction)
  end

  def dg_new_destinations

    @free_dest_size = Destination.where('destinationgroup_id < ?', 1).all.size

    @page_title = _('New_destinations')

    @st = params[:st].blank? ? "A" : params[:st].upcase

    @free_destinations = @destgroup.free_destinations_by_st(@st)
    fpage, @total_pages, options = Application.pages_validator(session, {}, @free_destinations.size, params[:page])
    @destinations = []
    @page = options[:page]
    iend = ((session[:items_per_page] * @page) - 1)
    iend = (@free_destinations.size - 1) if iend > (@free_destinations.size - 1)
    for nr in (fpage..iend)
      @destinations << @free_destinations[nr]
    end

    dg_id = @destgroup.id
    @letter_select_header_id = dg_id
    @page_select_header_id = dg_id
  end


  def dg_add_destinations
    st_params = params[:st]
    @st = st_params.upcase if st_params

    @free_destinations = @destgroup.free_destinations_by_st(@st)
    destgroup_id = @destgroup.id
    #my_debug @free_destinations.size

    @free_destinations.each do |fd|
      if params[fd.prefix.intern] == '1'
        sql = "UPDATE destinations SET destinationgroup_id = '#{destgroup_id}' WHERE id = '#{fd.id}'"
        #  INSERT INTO destgroups (destinationgroup_id, prefix) VALUES ('#{destgroup_id}', '#{fd.prefix.to_s}')"
        res = ActiveRecord::Base.connection.update(sql)
      end
    end

    flash[:status] = _('Destinations_added')
    redirect_to(action: :destinations, id: destgroup_id)
  end


  def dg_destination_delete
    @destgroup = Destinationgroup.where(id: params[:dg_id]).first
    unless @destgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE id = '#{@destination.id}' "
    res = ActiveRecord::Base.connection.update(sql)
    Confline.set_value('dg_group_was_changed_today', 1)
    flash[:status] = _('Destination_deleted')
    redirect_to action: :destinations, id: @destgroup.id
  end

  #for final user

  def dg_list_user_destinations
    @page_title = _('Destinations')
    @destinations = @destgroup.destinations
    render(layout: 'layouts/mor_min')
  end


  def dest_mass_update
    @page_title = _('Destination_mass_update')
    @page_icon = 'application_edit.png'

    perams_prefix = params[:prefix_s]
    params_name_s = params[:name_s]
    params_name = params[:name]
    @prefix_s = perams_prefix.blank? ? '%' : perams_prefix
    @name_s = params_name_s.blank? ? '%' : params_name_s
    @name = params_name.blank? ? '' : params_name

    if @name != ''
      @prefix_s = session[:prefix_s]
      @name_s = session[:name_s]

      @destinations = Destination.where("prefix LIKE '" + @prefix_s + "' and name LIKE '" + @name_s + "'")
      @destinations.each do |destination|
        if @name != ''
          destination.update_attributes(name: @name)
        end
      end
      flash[:status] = _('Destinations_updated')
    end

    @destinations = Destination.where("prefix LIKE '" + @prefix_s + "' and name LIKE '" + @name_s + "'")

    session[:prefix_s] = @prefix_s
    session[:name_s] = @name_s
  end

  def bulk_management_confirmation
    @page_title, @page_icon = [_('Bulk_management'), 'edit.png']
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Destinations_Groups'

    @saved[:prefix_2] = params[:prefix].to_s if @saved and params[:prefix]

    begin
      @destinations = Destination.dst_by_prefix(params[:prefix])

      if @destinations.blank?
        flash[:notice] = _('Invalid_prefix')
        redirect_to action: :bulk, params: params
      end
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to action: :bulk, params: params
    end

    @prefix = params[:prefix]
  end

  def bulk_assign
    params_prefix = params[:prefix]
    begin
      @destinations = Destination.dst_by_prefix(params_prefix)
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to action: :bulk, params: params
    end
    @prefix = params_prefix
    @destinations.each do |destination|
      ActiveRecord::Base.connection.execute("UPDATE rates SET destinationgroup_id = #{@dg.id} WHERE destination_id = #{destination.id}")
      destination.destinationgroup = @dg
      destination.save
    end
    pr = _('assigned_to')
    flash[:status] = _('Destinations') + ': ' + @destinations.size.to_s + ' ' + pr + ' - ' + @dg.name
    redirect_back_or_default('/callc/main')
  end

  #  AND rates.tariff_id = #{tariff} AND rates.destinationgroup_id = #{destination_group}
  def retrieve_destinations_remote
    tariff = params[:tariff_id].to_s

    destinations = Rate.select("rates.*, CONCAT_WS(' ', destinations.name, CONCAT('(', rates.prefix, ')')) as full_name, ratedetails.rate as destination_rate").
                        joins('LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id LEFT JOIN destinations on rates.destination_id = destinations.id').
                        where("rates.tariff_id = #{tariff} AND destinations.name LIKE #{ActiveRecord::Base::sanitize(params[:mask].to_s)} COLLATE utf8_general_ci").
                        order('destinations.name, rates.prefix').limit(1001)

    respond_to do |format|
      format.json do
        render text: destinations.map{|destination| {name: destination.full_name, rate: (destination.destination_rate ? Application.nice_number(destination.destination_rate) : '-')} }.to_json
      end
    end
    if destinations.first.present?
     destination_fletter = destinations.first.full_name.first.to_s
     session[:destination_first_letter] = destination_fletter.blank? ? 'A' : destination_fletter
    else
     session[:destination_first_letter] = 'A'
    end
  end

  #========================================= Destinations group stats ======================================================

  def stats
    @page_title = _('Destination_group_stats')
    @page_icon = 'chart_bar.png'

    change_date

    destinationgroup_flag = @destinationgroup.flag
    @html_flag = destinationgroup_flag
    @html_name = @destinationgroup.name
    @html_prefix_name = ''
    @html_prefix = ''

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({a1: session_from_date, a2: session_till_date, code: destinationgroup_flag})

    @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)

    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_calls2 = []
    @a_ars = []
    @a_ars2 = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    index = 0
    while @sdate < @edate
      @a_date[index] = @sdate.strftime('%Y-%m-%d')

      @a_calls[index] = 0
      @a_billsec[index] = 0
      @a_calls2[index] = 0

      sql = "SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[index] = res[0]['calls'].to_i
      @a_billsec[index] = res[0]['billsec'].to_i


      @a_avg_billsec[index] = 0
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0


      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]

      sqll = "SELECT COUNT(calls.id) as \'calls2\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[index] = res2[0]['calls2'].to_i

      @a_ars2[index] = (@a_calls[index].to_d / @a_calls2[index]) * 100 if @a_calls[index] > 0
      @a_ars[index] = nice_number @a_ars2[index]


      @sdate += (60 * 60 * 24)
      index+=1
    end

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    format_graphs(index)
  end

  # ========================================= Dg destination stats ======================================================

  def dg_destination_stats
    @page_title = _('Dg_destination_stats')
    @page_icon = 'chart_bar.png'
    @destinationgroup = Destinationgroup.where(id: params[:dg_id]).first
    unless @destinationgroup
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to(action: :index) && (return false)
    end

    change_date
    destinationgroup_flag = @destinationgroup.flag
    @dest = @destination
    @html_flag = destinationgroup_flag
    @html_name = @destinationgroup.name.to_s
    @html_prefix_name = _('Prefix') + ' : '
    @html_prefix = @dest.prefix

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({a1: session_from_date, a2: session_till_date, destination: @html_prefix, code: destinationgroup_flag})

    @sdate = Time.mktime(session[:year_from], session[:month_from], session[:day_from])

    year, month, day = last_day_month('till')
    @edate = Time.mktime(year, month, day)

    @a_date = []
    @a_calls = []
    @a_billsec = []
    @a_avg_billsec = []
    @a_calls2 = []
    @a_ars = []
    @a_ars2 = []

    @t_calls = 0
    @t_billsec = 0
    @t_avg_billsec = 0
    @t_normative = 0
    @t_norm_days = 0
    @t_avg_normative = 0

    index = 0
    while @sdate < @edate
      @a_date[index] = @sdate.strftime('%Y-%m-%d')

      @a_calls[index] = 0
      @a_billsec[index] = 0
      @a_calls2[index] = 0

      sql = "SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = '#{@html_prefix}') AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[index] = res[0]['calls'].to_i
      @a_billsec[index] = res[0]['billsec'].to_i


      @a_avg_billsec[index] = 0
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0


      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]

      sqll = "SELECT COUNT(calls.id) as \'calls2\' FROM destinations, destinationgroups, calls WHERE (destinations.direction_code = destinationgroups.flag) AND (destinationgroups.flag ='#{destinationgroup_flag}' ) AND (destinations.prefix = '#{@html_prefix}') AND (destinations.prefix = calls.prefix) "+
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[index] = res2[0]['calls2'].to_i

      @a_ars2[index] = (@a_calls[index].to_d / @a_calls2[index]) * 100 if @a_calls[index] > 0
      @a_ars[index] = nice_number @a_ars2[index]


      @sdate += (60 * 60 * 24)
      index+=1
    end

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    # Tariff and rate

    @rate = Rate.where(["destination_id=?", @dest.id])

    @rate_details = []
    @rate1 = []
    @rate2 = []
    for rat in @rate
      if rat.tariff

        rat_tariff_purpose = rat.tariff.purpose
        rat_tariff_name = rat.tariff.name
        rat_id = rat.id

        if rat_tariff_purpose == 'provider'
          @rate1[rat_id] = rat_tariff_name
        elsif rat_tariff_purpose == 'user_wholesale'
          @rate2[rat_id] = rat_tariff_name
        end

        @rate_details[rat_id] = Ratedetail.where(["rate_id=?", rat_id]).first
      end
    end

    #===== Graph =====================

    format_graphs(index)
  end

  # If at least one destination found redirect to confirmation page, else
  # redirect back to /destination_groups/list and inform user that nothing was found
  def bulk_rename_confirm
    @page_title = _('Bulk_management')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Destinations_Groups'

    @prefix = params[:prefix]
  	@saved[:prefix_1] = params[:prefix].to_s if params[:prefix]

    begin
      @destinations = Destination.dst_by_prefix(@prefix)

      if @destinations.present?
        @destination_count = @destinations.size
        @destination_name = params[:destination]
      else
        flash[:notice] = _('No_destinations_found')
        redirect_to action: :bulk, params: params
      end
    rescue
      flash[:notice] = _('Invalid_prefix')
      redirect_to action: :bulk, params: params
    end
  end

  # Update destination names by prefix that matches supplied pattern
  # redirect back to /destination_groups/list and inform user that nothing was found
  def bulk_rename
    Destination.rename_by_prefix(params[:destination].strip, params[:prefix])
    flash[:status] = _('Destinations_were_renamed')
    redirect_to action: :bulk, params: params
  end

  def bulk
    @page_title = _('Bulk_management')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Destinations_Groups'
    params_prefix = params[:prefix]
    prefix = params_prefix.to_s

    if @saved && params_prefix
      @saved[:prefix_2] = prefix
    elsif params_prefix
      @saved[:prefix_1] = prefix
    end
  end

  def destinations_to_dg
    @page_title = _('Destinations_without_Destination_Groups')
    @page_icon = 'wrench.png'
    @last_assigned_destinations_report = File.file?('/tmp/mor/Assigned_Destinations_report.csv')

    @options = session[:destinations_destinations_to_dg_options] || {}
    @options[:page] = params[:page].to_i
    @options[:page] = 1 if @options[:page].to_i <= 0

    @options[:order_desc] = params[:order_desc] || @options[:order_desc] || 0
    @options[:order_by] = params[:order_by] || @options[:order_by] || 'country'

    @options[:order] = Destinationgroup.destinationgroups_order_by(@options)

    @destination_count = Destination.where('destinationgroup_id = 0 OR destinationgroup_id IS NULL').to_a.size
    _fpage, @total_pages, @options = Application.pages_validator(session, @options, @destination_count)

    @destinations_without_dg = Destination.select_destination_assign_dg(@options[:page], @options[:order])
    dgs = Destinationgroup.select('id, name as gname').order('name ASC')
    @dgs = dgs.map { |destinationgroup| [destinationgroup.gname.to_s, destinationgroup.id.to_s] }

    session[:destinations_destinations_to_dg_options] = @options
  end

  def assign_all_unassigned_destinations_configuration
    unless admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    @page_title = _('Fix_all_Unassigned_Destinations')
    @page_icon = 'wrench.png'
  end

  def assign_all_unassigned_destinations
    unless admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    result = Destination.assign_all_unassigned_destinations(
        {
            individual_destination_action: params[:individual_destinations_action].to_i,
            fixed_unassigned_destination_prefix_difference: params[:fixed_unassigned_destination_prefix_difference].to_i
        }
    )

    if result[:error].present?
      flash[:notice] = result[:error]
    elsif result[:success]
      require 'csv'

      filename = 'Assigned_Destinations_report'
      sep, dec = current_user.csv_params

      CSV.open('/tmp/m2/' + filename + '.csv', 'w', {col_sep: sep, quote_char: "\""}) do |csv|
        # Headers
        csv << [
            "#{_('Destination')} #{_('ID')}",
            "#{_('Destination')} #{_('Prefix')}",
            "#{_('Destination')} #{_('Name')}",
            "#{_('Assigned_Destination_Group')} #{_('ID')}",
            "#{_('Assigned_Destination_Group')} #{_('Name')}"
        ]
        # Data
        result[:assigned_destinations].each do |destination|
          csv << [
              destination['id'],
              destination['prefix'],
              destination['name'],
              destination['destinationgroup_id'],
              destination['destinationgroup_name']
          ]
        end
      end

      flash[:status] = _('Automatic_assigning_Unassigned_Destinations_to_Destination_Groups_was_successfully_completed')
    end

    redirect_to(action: :destinations_to_dg) && (return false)
  end

  def download_last_report_for_assigned_destinations
    unless admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    file_path = '/tmp/m2/Assigned_Destinations_report.csv'
    if File.exists?(file_path)
      data = File.open(file_path).try(:read)
      send_data(data, filename: 'Assigned_Destinations_report.csv', content_type: 'text/csv')
    else
      flash[:notice] = _('File_was_not_found')
      redirect_to(action: :destinations_to_dg) && (return false)
    end
  end

  def destinations_to_dg_update
    # Hide for now, ticket  #12066
    dont_be_so_smart
    (redirect_to :root) && (return false)
    @options = session[:destinations_destinations_to_dg_options]
    ds = Destination.select_destination_assign_dg(session[:destinations_destinations_to_dg_options][:page], @options[:order])
    dgs = []
    ds.each { |destination| dgs << destination.id.to_s }
    if dgs and dgs.size.to_i > 0
      @destinations_without_dg = Destination.where("id IN (#{dgs.join(',')})")
      counter = 0
      if @destinations_without_dg and @destinations_without_dg.size.to_i > 0
        size = @destinations_without_dg.size
        for dest in @destinations_without_dg
          if dest.update_by(params)
            dest.save
            counter += 1
          end
        end

        session[:integrity_check] = FunctionsController.integrity_recheck

        not_updated = size - counter
      end
      if not_updated == 0
        flash[:status] = _('Destinations_updated')
      else
        flash[:notice] = "#{not_updated} " + _('Destinations_not_updated')
        flash[:status] = "#{counter} " +_('Destinations_updated_successfully')
      end
    else
      flash[:notice] = _('No_Destinations')
    end

    redirect_to(action: :destinations_to_dg) && (return false)
  end

  def auto_assign_warning
    #Hide for now, ticket  #12066
    dont_be_so_smart
    (redirect_to :root) && (return false)
    @page_title = _('Destinations_Auto_assign_warning')
    @page_icon = 'exclamation.png'
  end

  def auto_assign_destinations_to_dg
    #Hide for now, ticket  #12066
    dont_be_so_smart
    (redirect_to :root) && (return false)
    Destination.auto_assignet_to_dg
    flash[:status] = _('Destinations_assigned')
    redirect_to(controller: :functions, action: :integrity_check) && (return false)
  end

  def csv_upload
  end

  def csv_file_upload
    result = Destinationgroup.csv_file_upload(params)
    if result[:errors].blank?
        session[:prefix_import_table] = result[:table_name]
        flash[:status] = _('File_was_successfully_uploaded')
        redirect_to(action: :map_results) && (return false)
    else
        flash_array_errors_for(_('File_was_not_uploaded'), result[:errors])
        redirect_to(action: :csv_upload) && (return false)
    end
  end

  def map_results
    @results = Destinationgroup.map_prefix_import(session[:prefix_import_table])
    unless @results
      flash[:notice] = _('Map_Failed')
      Destinationgroup.drop_prefix_import_table(session[:prefix_import_table])
      redirect_to(action: :csv_upload) && (return false)
    end
  end

  def invalid_lines
    invalid_lines = Destinationgroup.analyze_temp_table(session[:prefix_import_table], @options)
    @invalid = Kaminari.paginate_array(invalid_lines).page(params[:page] ||= 1)
                                                     .per(session[:items_per_page])
  end

  def prefix_import
    import_result = Destinationgroup.prefix_import(session[:prefix_import_table])
    session[:prefix_import_table] = nil
    if import_result[:status]
      flash[:status] = _('Prefixes_were_successfully_imported')
    else
      flash[:notice] = flash_array_errors_for(_('Prefixes_were_not_imported'), import_result[:error])
    end
    redirect_to(action: :list) && (return false)
  end

  def cancel_prefix_import
    flash[:status] = _('Import_was_successfully_canceled')
    Destinationgroup.drop_prefix_import_table(session[:prefix_import_table])
    session[:prefix_import_table] = nil
    redirect_to(action: :list) && (return false)
  end

  def bulk_management_merge_confirmation
    @page_title = _('Bulk_management')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Destinations_Groups'

    @from_dg = Destinationgroup.where(id: params[:bulk_merge_from_dg_id]).first
    @to_dg = Destinationgroup.where(id: params[:bulk_merge_to_dg_id]).first

    if !(@from_dg && @to_dg)
      flash[:notice] = _('Destinationgroup_was_not_found')
      redirect_to(action: :list, params: params, show_bulk_management: true) and (return false)
    end

    if @from_dg.id == @to_dg.id
      flash[:notice] = _('Same_Destination_Groups_cannot_be_merged')
      redirect_to(action: :list, params: params, show_bulk_management: true) and (return false)
    end
  end

  def bulk_management_merge
    @from_dg = Destinationgroup.where(id: params[:bulk_merge_from_dg_id]).first
    @to_dg = Destinationgroup.where(id: params[:bulk_merge_to_dg_id]).first

    if !(@from_dg && @to_dg)
      flash[:notice] = _('Destinationgroup_was_not_found')
      redirect_to(action: :list, params: params, show_bulk_management: true) and (return false)
    end

    if @from_dg.id == @to_dg.id
      flash[:notice] = _('Same_Destination_Groups_cannot_be_merged')
      redirect_to(action: :list, params: params, show_bulk_management: true) and (return false)
    end

    @to_dg.merge_from(@from_dg.id)

    flash[:status] = _('Destinations_Groups_were_successfully_merged')
    redirect_to(action: :list) and (return false)
  end

  private

  def format_graphs(index)
    ine=0
    @Calls_graph2 = ''
    @Avg_Calltime_graph = ''
    @Asr_graph = ''
    while ine <= index
      -1
      @Calls_graph2 +=@a_date[ine].to_s + ';' + @a_calls[ine].to_s + "\\n"
      @Avg_Calltime_graph +=@a_date[ine].to_s + ';' + @a_avg_billsec[ine].to_s + "\\n"
      @Asr_graph +=@a_date[ine].to_s + ';' + @a_ars[ine].to_s + "\\n"
      ine +=1
    end

    #formating graph for Calltime

    @Calltime_graph = ''
    for nr in 0..@a_billsec.size - 1
      @Calltime_graph += @a_date[nr].to_s + ';' + (@a_billsec[nr] / 60).to_s + "\\n"
    end

  end

  def find_destination_group
    @dg = Destinationgroup.where(['id=?', params[:id]]).first
    @page_title = _('Bulk_management')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Destinations_Groups'
    unless @dg
      flash[:notice]=_('Destinationgroup_was_not_found')
      redirect_to action: :bulk, params: params
    end
    @destgroup = @dg
    @destinationgroup = @dg
  end

  def find_destination
    @destination=Destination.where(['id=?', params[:id]]).first
    unless @destination
      flash[:notice]=_('Destination_was_not_found')
      render(controller: :directions, action: :bulk) && (return false)
    end
    @dest = @destination
  end

  def save_params
    @saved = {
        prefix_1: '',
        prefix_2: '',
        destination: '',
        bulk_merge_from_dg_id: '',
        bulk_merge_to_dg_id: ''
    }

    @saved[:destination] = params[:destination].to_s.strip if params[:destination]
    @saved[:bulk_merge_from_dg_id] = params[:bulk_merge_from_dg_id].to_i if params[:bulk_merge_from_dg_id]
    @saved[:bulk_merge_to_dg_id] = params[:bulk_merge_to_dg_id].to_i if params[:bulk_merge_to_dg_id]
  end

  def validate_upload
    if params[:file].blank? || params[:file].original_filename.match('\.csv$').blank?
      flash[:notice] = _('Please_upload_file')
      redirect_to(action: :csv_upload) && (return false)
    end
  end

  def authorize_import
    if user?
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end

  def search_options_for_invalid_lines
    @options = {
      s_prefix: '',
      s_action: 'all',
      s_dst_group: '',
      s_reason: 'all',
    }
    %i[s_prefix s_action s_dst_group s_reason].each { |param| @options[param] = params[:search][param] if params[:search][param].present? }
  end
end
