# -*- encoding : utf-8 -*-
# M2 tariffs (rates/destinations)
class TariffsController < ApplicationController
  require 'csv'

  include UniversalHelpers

  layout :determine_layout

  helper_method :get_prefix_rate

  before_filter :check_post_method,
                only: [
                  :generate_request_for_tariff_generator, :destroy, :create, :update, :rate_destroy,
                  :ratedetail_update, :ratedetail_destroy, :ratedetail_create,
                  :day_destroy, :day_update,
                  :update_tariff_for_conection_points, :update_rates_by_destination_mask, :conversion_request
                ]
  before_filter :check_localization
  before_filter :access_denied, except: [:rates_list, :generate_personal_rates_xlsx], if: -> { user? }
  before_filter :authorize
  before_filter :find_user_from_session,
                only: [
                  :generate_personal_wholesale_rates_pdf,
                  :generate_personal_wholesale_rates_csv, :user_rates
                ]
  before_filter :find_user_tariff,
                only: [
                  :generate_personal_wholesale_rates_pdf, :generate_personal_wholesale_rates_csv, :user_rates
                ]
  before_filter :find_tariff_whith_currency, only: [:generate_providers_rates_csv, :generate_user_rates_csv]
  before_filter :find_tariff_from_id,
                only: [
                  :check_tariff_time, :rate_new_by_direction, :edit, :update, :destroy, :rates_list,
                  :rate_try_to_add, :rate_new, :rate_new_by_direction_add, :delete_all_rates,
                  :ghost_percent_edit, :ghost_percent_update, :update_rates,
                  :update_rates_by_destination_mask
                ]
  before_filter :authorize_manager_functionality,
                only: [
                  :check_tariff_time, :rate_new_by_direction, :edit, :update, :destroy, :rates_list,
                  :rate_try_to_add, :rate_new, :rate_new_by_direction_add, :delete_all_rates,
                  :ghost_percent_edit, :ghost_percent_update, :update_rates,
                  :update_rates_by_destination_mask
                ]
  before_filter :authorize_user, only: [:rates_list]

  after_action :tariff_changes_present_set_1,
               only: [
                   :update, :update_rates_by_destination_mask, :rate_try_to_add, :rate_new_by_direction_add,
                   :delete_all_rates, :ghost_percent_update, :update_rates
               ]

  def index
    redirect_to(action: :list) && (return false)
  end

  def list
    user = User.where(id: correct_owner_id).first
    unless user
      flash[:notice] = _('User_was_not_found')
      redirect_to(:root) && (return false)
    end

    @processing_tariffs_id = TariffImportRule.
        joins("JOIN tariff_jobs ON tariff_jobs.tariff_import_rule_id = tariff_import_rules.id AND tariff_jobs.status IN ('analyzing', 'analyzed', 'importing')").
        pluck(:tariff_id).uniq

    @email = current_user.email
    @page_title = _('Tariffs')
    @page_icon = 'view.png'
    # @tariff_pages, @tariffs = paginate :tariffs, :per_page => 10
    params_s_prefix = params[:s_prefix]
    if params_s_prefix
      @s_prefix = params_s_prefix.gsub(/[^0-9%]/, '')
      dest = Destination.where('prefix LIKE ?', @s_prefix.to_s).all
    end
    @des_id = []
    if dest && dest.size.to_i > 0
      dest.each { |item| @des_id << item.id }
      cond = " AND rates.destination_id IN (#{@des_id.join(',')})"
      @search = 1
      incl =  [:rates]
    else
      con = cond = incl = ''
    end

    user_id = user.id
    tp_count = '(SELECT COUNT(*) FROM devices WHERE devices.tp_tariff_id = tariffs.id) AS tp_count'
    op_count = '(SELECT COUNT(*) FROM devices WHERE devices.op_tariff_id = tariffs.id) AS op_count'

    @prov_tariffs = Tariff.provider_tariffs_for_list(session[:user_id], user_id, cond, tp_count, op_count, incl)
    @user_wholesale_tariffs = Tariff.users_tariffs_for_list(session[:user_id], user_id, cond, tp_count, op_count, incl)

    @user_wholesale_enabled = true

    @show_currency_selector = 1
    @tr = []
    select = 'tariffs.id, COUNT(rates.id) as rsize'
    condition = "(purpose = 'provider' or purpose = 'user_wholesale') AND owner_id = '#{user_id}' AND tariffs.id = rates.tariff_id"

    tariffs_rates = Rate.selection(select, 'JOIN tariffs ON tariffs.id = rates.tariff_id', condition, params, nil, 'tariffs.id')
    tariffs_rates.each { |tariff| @tr[tariff.id] = tariff.rsize.to_i }

    # deleting not necessary session vars - just in case after crashed csv rate import
    clean_session_variables
  end

  def custom_tariffs
    if (tariffs_owner_id = User.where(id: correct_owner_id).first.try(:id)).blank?
      flash[:notice] = _('User_was_not_found')
      redirect_to(:root) && (return false)
    end

    op_count = '(SELECT COUNT(*) FROM devices WHERE devices.op_tariff_id = tariffs.id) AS op_count'
    @tariffs = Tariff.select("*, #{op_count}")
                     .where(purpose: :user_custom, owner_id: tariffs_owner_id)
                     .order(:name)
                     .group('tariffs.id').all

    @tr = []
    select = 'tariffs.id, COUNT(rates.id) as rsize'
    condition = "(purpose = 'user_custom') AND owner_id = '#{tariffs_owner_id}' AND tariffs.id = rates.tariff_id"

    tariffs_rates = Rate.selection(select, 'JOIN tariffs ON tariffs.id = rates.tariff_id', condition, params, nil, 'tariffs.id')
    tariffs_rates.each { |tariff| @tr[tariff.id] = tariff.rsize.to_i }
  end

  def create_custom_tariff
    tariff = Tariff.new(name: params[:name], currency: params[:currency], purpose: 'user_custom')

    if tariff.save
      flash[:status] = _('Custom_Tariff_was_successfully_created')
      redirect_params = {action: :custom_tariffs}
    else
      flash_errors_for(_('Custom_Tariff_was_not_created'), tariff)
      redirect_params = {action: :custom_tariffs, name: tariff.name, currency: tariff.currency, visible: true}
    end

    redirect_to(redirect_params) && (return false)
  end

  def dst_to_update_from_csv
    @page_title = _('Dst_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2 = params[:csv2].to_i
    session_tariff_name_csv = "tariff_name_csv_#{@tariff_id}"
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session[session_tariff_name_csv.to_sym])
        @dst = ActiveRecord::Base.connection.select_all("SELECT destinations.prefix, col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_dst]} as new_name, IFNULL(original_destination_name,destinations.name) as dest_name FROM destinations JOIN #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} ON (replace(col_#{session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]}, '\\r', '') = prefix) WHERE ned_update IN (1, 3, 5, 7) AND (BINARY replace(replace(TRIM(col_2), '\r', ''), '  ', ' ') != IFNULL(original_destination_name,destinations.name) OR destinations.name IS NULL)")
      end
    end
    render(layout: 'layouts/mor_min')
  end

  def dst_to_create_from_csv
    @page_title = _('Dst_to_create_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2 = 0
    if @file.present?
      if params[:csv2].to_i == 0
        flash[:notice] = _('Zero_file_size')
        redirect_to controller: 'tariffs', action: 'list'
      else
        @csv2 = 1
        tariff_id = params[:tariff_id].to_i
        if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{tariff_id}".to_sym])
          @csv_file = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]} WHERE not_found_in_db = 1 AND f_error = 0")
        end
        render(layout: 'layouts/mor_min')
      end
    else
      flash[:notice] = _('Zero_file_size')
      redirect_to controller: 'tariffs', action: 'list'
    end
  end

  def tariff_generator
    @tariffs = Tariff.tariffs_for_tariff_generator(session[:user_id], correct_owner_id)
    @dial_peers = DialPeer.order(:name)
  end

  def generate_request_for_tariff_generator
    tariff_to_bg_task = BackgroundTask.new
    tariff = tariff_to_bg_task.tariff_generation_validate_params(params)

    # Sending to Background Tasks else renders back to Generation
    if tariff_to_bg_task.errors.blank?
      # Making good data for Background Task and sending it
      tariff_to_bg_task.update_attributes(
          owner_id: current_user_id,
          user_id: current_user_id,
          task_id: 3,
          status: 'WAITING',
          created_at: Time.now,
          data1: tariff[:name],
          data2: tariff[:currency_id],
          data3: tariff[:profit_margin_at_least].sub(/[\,\.\;]/, '.').to_d.round(2).to_s,
          data4: tariff[:selected].join(','),
          data5: "#{tariff[:profit_margin].sub(/[\,\.\;]/, '.').to_d.round(2).to_s};#{tariff[:cheapest_rate]}",
          data6: tariff[:date_time],
          data7: tariff[:prefixes_for_generated_tariff_for_db],
          data8: tariff[:do_not_add_a_profit_margin_if_rate_more_than].sub(/[\,\.\;]/, '.').to_d.round(2).to_s,
          data9: tariff[:tariff_generation_for],
          data10: tariff[:tariff_generation_for_existing_tariff_id]
      )
      flash[:status] = _('Tariff_generation_sent_to_background_tasks')

      if manager? && !authorize_manager_permissions(controller: :functions, action: :background_tasks, no_redirect_return: 1)
        redirect_to(controller: :tariffs, action: :tariff_generator) && (return false)
      else
        redirect_to(controller: :functions, action: :background_tasks) && (return false)
      end
    else
      flash_errors_for(_('Tariff_Was_Not_Generated'), tariff_to_bg_task)
      redirect_to(
          action: :tariff_generator, tariff: params[:tariff],
          dial_peer_id: params[:dial_peer_id], tariff_id: params[:tariff_id],
          date: params[:date], time: params[:time]
      ) && (return false)
    end
  end

  def new
    @page_title = _('Tariff_new')
    @page_icon = 'add.png'
    @tariff = Tariff.new
    @currs = Currency.get_active
    @user_wholesale_enabled = true
  end

  def create
    @page_title = _('Tariff_new')
    @page_icon = 'add.png'
    @tariff = Tariff.new(params[:tariff])
    @currs = Currency.get_active
    @user_wholesale_enabled = true

    @tariff.owner_id = correct_owner_id
    if @tariff.save
      Action.add_action_hash(
          current_user,
          action: 'tariff_created', target_id: @tariff.id, target_type: 'tariff', data: "Name: #{@tariff.name}"
      )
      flash[:status] = _('Tariff_was_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Tariff_Was_Not_Created'), @tariff)
      render :new
    end
  end

  # before_filter : tariff(find_tariff_from_id)
  def edit
    session[:redirect_link] = params[:redirect_link].presence
    check_user_for_tariff(@tariff.id)
    @page_icon = 'edit.png'
    @page_title = _('Tariff_edit') # +": "+ @tariff.name
    @no_edit_purpose = true
    @currs = Currency.get_active
    @user_wholesale_enabled = true
    @rates_count = params[:rates] || Rate.where(tariff_id: @tariff.id).count
  end

  # before_filter : tariff(find_tariff_from_id)
  def update
    tariffs = check_user_for_tariff(@tariff.id)
    return false unless tariffs
    @page_icon = 'edit.png'
    @currs = Currency.get_active

    if @tariff.update_attributes(params[:tariff])
      flash[:status] = _('Tariff_was_successfully_updated')
      action = session[:redirect_link] || 'list'
      session.delete(:redirect_link)
      redirect_to(action: action, id: @tariff)
    else
      flash_errors_for(_('Tariff_Was_Not_Updated'), @tariff)
      render :edit
    end
  end

  # before_filter : tariff(find_tariff_from_id)
  def destroy
    tariffs = check_user_for_tariff(@tariff.id)
    return false unless tariffs

    if @tariff.able_to_delete?
      @tariff.delete_all_rates
      @tariff.destroy
      Action.add_action_hash(
        current_user,
        action: 'tariff_deleted', target_id: @tariff.id, target_type: 'tariff', data: "Name: #{@tariff.name}"
      )
      flash[:status] = _('Tariff_deleted')
    else
      flash_errors_for(_('Tariff_not_deleted'), @tariff)
    end
    redirect_to action: params[:redirect_link] || 'list'
  end

  def rates_list
    rates_list_set_correct_layout_path_link
    rates_list_quick_rate_creation
    rates_list_options

    join = 'LEFT JOIN destinations on rates.destination_id = destinations.id'

    custom_tariff_id = (@options[:device_id] ? Device.where(id: @options[:device_id]).first.try(:op_custom_tariff_id) : 0).to_i
    condition = "rates.tariff_id = #{@tariff.id}"
    condition = "(#{condition} OR rates.tariff_id = #{custom_tariff_id})" if custom_tariff_id != 0

    if @options[:searching_by] == _('rates_list_manage_rates_destination') && @options[:destination].to_s.present?
      condition << " AND (destinations.name LIKE #{ActiveRecord::Base::sanitize(@options[:destination])})"

    elsif @options[:searching_by] == _('rates_list_manage_rates_prefixes') && @options[:prefix].to_s.present?
      good_prefixes, @bad_prefixes = prefixes_input_decomposition(@options[:prefix].to_s)

      search_by_prefixes_sql = " AND (rates.prefix LIKE '#{good_prefixes.join("' OR rates.prefix LIKE '")}' )"

      condition << search_by_prefixes_sql

    else
      @options[:searching_by] = ''

      @letters_to_bold = @directions_first_letters = @tariff.rates_destination_first_letters

      @st = session[:st] = if params[:st]
                             params[:st].upcase.to_s
                           elsif @options[:clear_search]
                             @directions_first_letters[0].to_s
                           else
                             (session[:st].presence || @directions_first_letters[0]).to_s
                           end

      if @st == '#'
        condition << " AND (destinations.name NOT REGEXP '^[A-Za-z]')"
      else
        condition << " AND (destinations.name LIKE #{ActiveRecord::Base::sanitize(@st + '%')})"
      end

      @letter_select_header_id = @tariff.id
    end

    rates_list_manage_rates(condition)

    @active_rates = get_active_rates_ids(condition)
    if user? || @options[:show_only_active_rates].to_i == 1
      condition << "AND (rates.id IN (#{@active_rates.join(', ').presence || -1}))"
    end

    @rates_for_kaminari = Rate.joins(join).where(condition).prefix_group(user?).page(params[:page] ||= 1).per(session[:items_per_page])
    @rates_for_kaminari.total_pages

    @rates = Rate.selection(
        'rates.*, destinations.name as destinations_name',
        join.concat(' LEFT JOIN ratedetails on rates.id = ratedetails.rate_id '),
        condition,
        params, session[:items_per_page], 'rates.id', custom_tariff_id
    )

    @total_count = user? ? @tariff.rate_total_user(custom_tariff_id) : @tariff.rate_total

    session[:rates_list] = @options
  end

  # Checks if prefix is available
  # Post data - prefix that needs to be checked.
  def check_prefix_availability
    @destination = Destination.where(prefix: params[:prefix]).first
    render layout: false
  end

  # Shows list of free destinations for 1 direction. User can set rates for destinations.
  #
  # *Params*:
  #
  # +id+ - Tariff id
  # +dir_id+ Direction id
  # +st+ - Directions first letter for correct pagination
  # +page+ - list page number

  # before_filter : tariff(find_tariff_from_id)
  def rate_new_by_direction
    params_page = params[:page].to_i
    @page = (params_page > 0) ? params_page : 1
    @st = params[:st]
    @direction = Direction.where(['id = ?', params[:dir_id]]).first
    unless @direction
      flash[:notice] = _('Direction_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    @destinations = @tariff.free_destinations_by_direction(@direction)
    # MorLog.my_debug(@destinations)
    @total_items = @destinations.size
    items_per_page = session[:items_per_page]
    @total_pages = (@total_items.to_d / items_per_page.to_d).ceil
    istart = (@page - 1) * items_per_page
    iend = @page * items_per_page - 1
    # MorLog.my_debug(istart)
    # MorLog.my_debug(iend)
    @destinations = @destinations[istart..iend]
    @page_select_options = {
        id: @tariff.id,
        dir_id: @direction.id,
        st: @st
    }
    @page_title = "#{_('Rates_for_tariff')} #{_('Direction')}: #{@direction.name}"
    @page_icon = 'money.png'
    # MorLog.my_debug(@destinations)
  end

=begin rdoc

=end
  # before_filter : tariff(find_tariff_from_id)
  def rate_new_by_direction_add
    @st = params[:st]
    @direction = Direction.where(['id = ?', params[:dir_id]]).first
    unless @direction
      flash[:notice] = _('Direction_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    @destinations = @tariff.free_destinations_by_direction(@direction)
    @destinations.each do |dest|
      destination_id = dest.id
      params_dst_id = nice_input_separator(params["dest_#{destination_id}"])
      ghost_percent = nice_input_separator(params[('gh_' + destination_id.to_s).intern])
      if params_dst_id && !params_dst_id.to_s.empty?
        @tariff.add_new_rate(destination_id, params_dst_id, 1, 0, 0, ghost_percent)
      end
    end
    flash[:status] = _('Rates_updated')
    redirect_to(action: :rate_new_by_direction, id: params[:id], st: params[:st], dir_id: @direction.id)
  end

  # before_filter : tariff(find_tariff_from_id)
  def rate_new
    tariff_id = @tariff.id
    check_user_for_tariff(tariff_id)

    @page_title = _('Add_new_rate_to_tariff') # +": " + @tariff.name
    @page_icon = 'add.png'

    # st - from which letter starts rate's direction (usualy country)
    params_st = params[:st]
    @st = params_st.present? ? params_st.upcase : 'A'
    @page = (params[:page] || 1).to_i
    items_per_page = session[:items_per_page]
    offset = (@page - 1) * items_per_page.to_i

    @dests, total_records = @tariff.free_destinations_by_st(@st, items_per_page, offset)
    @total_pages = (total_records.to_f / items_per_page.to_f).ceil

    unless @dests.any?
      flash[:notice] = _('no_destinations')
      redirect_to(action: :rates_list, id: @tariff.id, st: @st)
    end

    @letter_select_header_id = tariff_id
    @page_select_header_id = tariff_id
  end

  # before_filter : tariff(find_tariff_from_id)
  def ghost_percent_edit
    tariffs = check_user_for_tariff(@tariff.id)
    return false unless tariffs
    @page_title = _('Ghost_percent')
    @rate = Rate.where(id: params[:rate_id]).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    @destination = @rate.destination
  end

  # before_filter : tariff(find_tariff_from_id)
  def ghost_percent_update
    tariffs = check_user_for_tariff(@tariff.id)
    params_rate_id = params[:rate_id]
    return false unless tariffs
    @rate = Rate.where(id: params_rate_id).first
    if @rate
      @rate.ghost_min_perc = nice_input_separator(params[:rate][:ghost_min_perc])
      @rate.save
    end

    flash[:status] = _('Rate_updated')
    redirect_to(action: :ghost_percent_edit, id: @tariff.id, rate_id: params_rate_id)
  end

  # before_filter : tariff(find_tariff_from_id)
  def rate_try_to_add
    tariffs = check_user_for_tariff(@tariff.id)
    return false unless tariffs

    convert_blocked_params(params)

    # st - from which letter starts rate's direction (usualy country)
    st = params[:st].try(:upcase) || 'A'

    @tariff.free_destinations_by_st(st).each do |dest|
      # add only rates which are entered
      destination_id = dest.id.to_s
      destination = nice_input_separator(params[destination_id.intern])
      ghost_percent = nice_input_separator(params[('gh_' + destination_id).intern])
      unless destination.to_s.empty?
        @tariff.add_new_rate(destination_id, destination, 1, 0, 0, ghost_percent)
        tariff_rates_effective_from_cache("-pt #{dest.prefix} #{@tariff.id}")
      end
    end

    flash[:status] = _('Rates_updated')
    redirect_to action: 'rates_list', id: params[:id], st: st
    #    render :action => 'debug'
  end

  def rate_destroy
    rate = Rate.where(['id = ?', params[:id]]).first
    unless rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    if rate
      tariffs = check_user_for_tariff(rate.tariff_id)
      return false unless tariffs

      st = (rate.destination.try(:direction).try(:name) || rate.destination.try(:name)).to_s.first
      rate.destroy_everything
    end
    rate.try(:tariff).try(:changes_present_set_1)
    flash[:status] = _('Rate_deleted')
    tariff_rates_effective_from_cache("-pt #{rate.prefix} #{rate.tariff_id}")
    redirect_to action: 'rates_list', id: params[:tariff], st: st
  end

  # =============== RATE DETAILS ==============

  def rate_details
    @rate = Rate.where(id: params[:id]).first

    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    rated = Ratedetail.where(rate_id: params[:id]).first

    unless rated
      Ratedetail.create(
        start_time: '00:00:00',
        end_time: '23:59:59',
        rate: 0,
        connection_fee: 0,
        rate_id: params[:id].to_i,
        increment_s: 1,
        min_time: 0,
        daytype: ''
      )
    end

    check_user_for_tariff(@rate.tariff_id)
    @page_title = _('Rate_details')
    @rate_details = @rate.ratedetails

    if @rate_details[0] && @rate_details[0].daytype == ''
      @wdfd = true
    else
      @wdfd = false
      @WDrdetails = []
      @FDrdetails = []
      @rate_details.each do |rate_detail|
        @WDrdetails << rate_detail if rate_detail.daytype == 'WD'
        @FDrdetails << rate_detail if rate_detail.daytype == 'FD'
      end

    end

    @tariff = @rate.tariff
    @destination = Destination.linked_with_rate(@rate.destination).first
    unless @destination
      flash[:notice] = _('Rate_does_not_have_destination_assigned')
      redirect_to :root
    end
    @can_edit = true

    # Header path links
    action, title = (Tariff.find(@rate.tariff_id).purpose == 'user_custom') ? ['custom_tariffs', 'Custom Tariffs'] : ['list', 'Tariffs']

    params[:options_for_path_links] = {out: [
        "Rate Details",
        "<a href=\"#{Web_Dir}/tariffs/rates_list/#{@tariff.id}\" id=\"tariff name\">#{@tariff.name}</a>",
        "<a href=\"#{Web_Dir}/tariffs/#{action}\">#{title}</a>",
        "<a href=\"#\" id=\"billing\">Billing</a>"
    ]}
  end

  def ratedetails_manage
    @rate = Rate.where(id: params[:id]).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    tariffs = check_user_for_tariff(@rate.tariff_id)
    return false unless tariffs

    rdetails = @rate.ratedetails

    rdaction = params[:rdaction]

    if rdaction == 'SPLIT' && m4_functionality?
      dont_be_so_smart
      redirect_to(action: 'rate_details', id: @rate.id) && (return false)
    end

    if rdaction == 'COMB_WD'
      rdetails.each { |rate_detail| rate_detail.combine_work_days }
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == 'COMB_FD'
      rdetails.each { |rate_detail| rate_detail.combine_free_days }
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == 'SPLIT'
      rdetails.each { |rate_detail| rate_detail.split }
      flash[:status] = _('Rate_details_split')
    end

    @rate.tariff_changes_present_set_1

    redirect_to action: 'rate_details', id: @rate.id
  end

  def ratedetail_edit
    @ratedetail = Ratedetail.where(id: params[:id]).first
    unless @ratedetail
      flash[:notice] = _('Ratedetail_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    @rate = Rate.where(id: @ratedetail.rate_id).first
    unless @rate
      flash[:notice] = _('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    check_user_for_tariff(@rate.tariff_id)

    rdetails = @rate.ratedetails_by_daytype(@ratedetail.daytype)

    @tariff = @rate.tariff
    @destination = Destination.linked_with_rate(@rate.destination_id).first
    unless @destination
      flash[:notice] = _('Rate_does_not_have_destination_assigned')
      redirect_to(:root) && (return false)
    end

    @etedit = (rdetails[(rdetails.size - 1)] == @ratedetail)

    @user_date_format = session[:date_time_format].split(' ').first
    # Header path links
    action, title = (Tariff.find(@rate.tariff_id).purpose == 'user_custom') ? ['custom_tariffs', 'Custom Tariffs'] : ['list', 'Tariffs']
    params[:options_for_path_links] = {out: ['Edit',
                         "<a href=\"#{Web_Dir}/tariffs/rate_details/#{@rate.id}\" id=\"rate details\">Rate Details</a>",
                         "<a href=\"#{Web_Dir}/tariffs/rates_list/#{@tariff.id}\" id=\"tariff name\">#{@tariff.name}</a>",
                         "<a href=\"#{Web_Dir}/tariffs/#{action}\">#{title}</a>",
                         "<a href=\"#\" id=\"billing\">Billing</a>"
    ]}
  end

  def ratedetail_update
    @ratedetail = Ratedetail.where(id: params[:id]).first
    unless @ratedetail
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    rd = @ratedetail

    rate = Rate.where(id: @ratedetail.rate_id).first
    unless rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    tariffs = check_user_for_tariff(rate.tariff_id)
    return false unless tariffs

    rdetails = rate.ratedetails_by_daytype(@ratedetail.daytype)
    user_date_format = session[:date_time_format].split(' ').first

    if params[:ratedetail].present? && params[:end_time].present?
      begin
        params[:ratedetail][:end_time] = Time.strptime(params[:end_time], "%H:%M:%S").strftime("%H:%M:%S")
        if (nice_time2(rd.start_time) > params[:ratedetail][:end_time]) || (params[:ratedetail][:end_time] > '23:59:59')
          @ratedetail.errors.add(:Bad_time, _('Bad_time'))
        end
      rescue
        @ratedetail.errors.add(:Bad_time, _('Bad_time'))
      end
    end

    @ratedetail.validate_increment_and_min_time(params)

    if @ratedetail.errors.present?
      flash_errors_for(_('Rate_Details_was_not_updated'), @ratedetail)
      redirect_to(action: :rate_details, id: @ratedetail.rate_id) && (return false)
    end

    params[:ratedetail][:rate] = if params[:ratedetail][:rate].downcase == 'blocked'
                                   -1
                                 else
                                   nice_input_separator(params[:ratedetail][:rate])
                                 end

    params[:ratedetail][:connection_fee] = nice_input_separator(params[:ratedetail][:connection_fee])

    if @ratedetail.update_attributes(params[:ratedetail])
      # we need to create new rd to cover all day
      if (nice_time2(@ratedetail.end_time) != '23:59:59') && ((rdetails[(rdetails.size - 1)] == @ratedetail))
        st = @ratedetail.end_time + 1.second

        attributes = rd.attributes.merge(start_time: st.to_s, end_time: '23:59:59')
        nrd = Ratedetail.new(attributes)
        nrd.save
      end

      @ratedetail.action_on_change(@current_user)
      @ratedetail.tariff_changes_present_set_1
      flash[:status] = _('Rate_details_was_successfully_updated')
      redirect_to(action: :rate_details, id: @ratedetail.rate_id)
    else
      render :ratedetail_edit
    end
  end

  def ratedetail_new
    @rate = Rate.where(id: params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    @page_title = _('Ratedetail_new')
    @page_icon = 'add.png'
    @ratedetail = Ratedetail.new(
      start_time: '00:00:00',
      end_time: '23:59:59'
    )
  end

  def ratedetail_create
    @rate = Rate.where(id: params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    params[:ratedetail][:rate] = nice_input_separator(params[:ratedetail][:rate])
    params[:ratedetail][:connection_fee] = nice_input_separator(params[:ratedetail][:connection_fee])
    @ratedetail = Ratedetail.new(params[:ratedetail])
    @ratedetail.rate = @rate
    if @ratedetail.save
      @rate.tariff_changes_present_set_1
      flash[:status] = _('Rate_detail_was_successfully_created')
      redirect_to action: 'rate_details', id: @ratedetail.rate_id
    else
      render :ratedetail_new
    end
  end

  def ratedetail_destroy
    @rate = Rate.where(id: params[:rate]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    tariffs = check_user_for_tariff(@rate.tariff_id)
    return false unless tariffs

    rd = Ratedetail.where(id: params[:id]).first
    unless rd
      flash[:notice]=_('Ratedetail_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    rdetails = @rate.ratedetails_by_daytype(rd.daytype)


    if rdetails.size > 1

      #update previous rd
      et = nice_time2(rd.start_time - 1.second)
      daytype = rd.daytype
      prd = Ratedetail.where(['rate_id = ? AND end_time = ? AND daytype = ?', @rate.id, et, daytype]).first
      if prd
        prd.end_time = '23:59:59'
        prd.save
      end
      rd.destroy
      @rate.tariff_changes_present_set_1
      flash[:status] = _('Rate_detail_was_successfully_deleted')
    else
      flash[:notice] = _('Cant_delete_last_rate_detail')
    end

    redirect_to action: 'rate_details', id: params[:rate]
  end


  # ======== XLS IMPORT =================
  def import_xls
    @step = 1
    @step = params[:step].to_i if params[:step]

    step_names = [_('File_upload'),
                  _('Column_assignment'),
                  _('Column_confirmation'),
                  _('Analysis'),
                  _('Creating_destinations'),
                  _('Updating_rates'),
                  _('Creating_new_rates')]
    @step_name = step_names[@step - 1]

    @page_title = (_('Import_XLS') + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + _('Step') + ': ' + @step.to_s + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + @step_name).html_safe
    @page_icon = 'excel.png';

    @tariff = Tariff.where(id: params[:id]).first
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    tariffs_id = @tariff.id
    files_size = @file.size
    tariffs = check_user_for_tariff(tariffs_id)
    return false unless tariffs

    if @step == 2
      if params[:file] || session[:file]
        if params[:file]
          @file = params[:file]
          session[:file] = params[:file].read if files_size > 0
        else
          @file = session[:file]
        end
        session[:file_size] = files_size
        if session[:file_size].to_i == 0
          flash[:notice] = _('Please_select_file')
          redirect_to(action: 'import_xls', id: tariffs_id, step: '1') && (return false)
        end

        file_name = '/tmp/temp_excel.xls'
        file = File.open(file_name, 'wb')
        file.write(session[:file])
        file.close
        workbook = Excel.new(file_name)
        session[:pagecount] = 0
        pages = []
        page = []
        #        MorLog.my_debug(workbook.info)
        last_sheet, count = count_data_sheets(workbook)
        if count == 1
          #          MorLog.my_debug("single")
          #          MorLog.my_debug(last_sheet.class)
          #          MorLog.my_debug(find_prefix_column(workbook, last_sheet))

        end

        #        MorLog.my_debug("++")

        flash[:status] = _('File_uploaded')
      end
    end
  end

  def find_prefix_column(workbook, sheet)
    workbook.default_sheet = sheet
    size = workbook.last_row
    midle = size/2
    midle.upto(size) do |index|
      workbook.row(index)
    end
  end

  def count_data_sheets(workbook)
    count = 0
    for sheet in workbook.sheets do
      workbook.default_sheet = sheet
      if workbook.last_row.to_i > 0 && workbook.last_column.to_i > 1
        count += 1
        last = sheet
      end
    end
    return sheet, count
  end

  # ======== CSV IMPORT =================
  def import_csv
    redirect_to(action: :import_csv2, id: params[:id]) && (return false)
  end

  def import_csv2
    @sep, @dec = Application.nice_action_session_csv(params, session, correct_owner_id)
    store_location

    params[:step] ? @step = params[:step].to_i : @step = 0
    @step = 0 unless (0..9).include?(@step.to_i)

    @step = 6 if (@step == 5) && !(manager? || admin?)

    @step_name = _('File_upload')
    @step_name = _('Column_assignment') if @step == 2
    @step_name = _('Column_confirmation') if @step == 3
    @step_name = _('Analysis') if @step == 4
    @step_name = _('Creating_destinations') if @step == 5
    @step_name = _('deleting_rates') if @step == 6
    @step_name = _('Updating_rates') if @step == 7
    @step_name = _('Creating_new_rates') if @step == 8


    step = @step

    @page_title = (_('Import_CSV') + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + _('Step') + ': ' + step.to_s + '&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;' + @step_name).html_safe
    @page_icon = 'excel.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Rate_import_from_CSV'

    @tariff = Tariff.where(['id = ?', params[:id]]).first
    if @tariff
      tariff_id = @tariff.id
      @action = (@tariff.purpose == 'user_custom') ? 'custom_tariffs' : 'list'
    else
      flash[:notice] = _('Tariff_Was_Not_Found')
      redirect_to(action: :list) && (return false)
    end

    tariffs = check_user_for_tariff(tariff_id)
    return false unless tariffs

    @effective_from_active = (admin? || manager? || reseller?)

    if @step == 0
      options_to_session_delete(session)
      my_debug_time '**********import_csv2************************'
      my_debug_time 'step 0'
      session["tariff_name_csv_#{tariff_id}".to_sym] = nil
      session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
      session[:import_csv_tariffs_import_csv_options] = nil
    end

    if @step == 1
      my_debug_time 'step 1'
      session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
      session["tariff_name_csv_#{tariff_id}".to_sym] = nil
      if params[:file]
        @file = params[:file]
        file_size = @file.size
        if  file_size > 0
          if !@file.respond_to?(:original_filename) || !@file.respond_to?(:read) || !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to(action: 'import_csv2', id: tariff_id, step: '0') && (return false)
          end
          if get_file_ext(@file.original_filename, 'csv') == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to(action: 'import_csv2', id: tariff_id, step: '0') && (return false)
          end
          @file.rewind
          file = @file.read.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?').gsub("\r\n", "\n")
          session[:file_size] = file.size
          session["temp_tariff_name_csv_#{tariff_id}".to_sym] = @tariff.save_file(file)
          flash[:status] = _('File_downloaded')
          redirect_to(action: 'import_csv2', id: tariff_id, step: '2') && (return false)
        else
          session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
          flash[:notice] = _('Please_select_file')
          redirect_to(action: 'import_csv2', id: tariff_id, step: '0') && (return false)
        end
      else
        session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: 'import_csv2', id: tariff_id, step: '0') && (return false)
      end
    end


    if @step == 2
      if session[:import_date_from].present?
        %i[ year month day hour minute].each do |key|
          params[:date_from] ||= {}
          params[:date_from][key] = session[:import_date_from][key] if params[:date_from][key].blank?
        end
      end
      my_debug_time 'step 2'
      my_debug_time "use : #{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}"
      if session["temp_tariff_name_csv_#{tariff_id}".to_sym]
        begin
          file = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 20).join('').to_s
        rescue => exception
          MorLog.log_exception(exception, Time.now.to_i, params[:controller], params[:action])
          flash[:notice] = _('Please_upload_file')
          redirect_to(action: 'import_csv2', id: tariff_id, step: '1') && (return false)
        end
        session[:file] = file
        csv_sep = params[:dont_check_seperator] || check_csv_file_seperators(file, 2, 2)
        if csv_sep
          @fl = @tariff.head_of_file("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 1).join('').to_s.split(@sep)
          begin
            session["tariff_name_csv_#{tariff_id}".to_sym] = @tariff.load_csv_into_db(session["temp_tariff_name_csv_#{tariff_id}".to_sym], @sep, @dec, @fl)

            # drop columns from temp table that are not allowed to be imported
            ['Class'].each do |column_to_drop|
              if @fl.index("#{column_to_drop}").present?
                ActiveRecord::Base.connection.execute("ALTER TABLE #{session["tariff_name_csv_#{tariff_id}".to_sym]} " +
                                                      "DROP col_#{@fl.index("#{column_to_drop}")};")
              end
            end

            session[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]}")

            session[:first_effective_from_value] =
                if @effective_from_active
                  effective_from_col = @fl.index { |column_header| Regexp.union(/\Aeffective from\z/).match(column_header.to_s.strip.downcase) }
                  if effective_from_col.blank?
                    ''
                  else
                    ActiveRecord::Base.connection.select_value("SELECT col_#{effective_from_col} FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]} WHERE id = 2")
                  end
                else
                  ''
                end
          rescue => exception
            MorLog.log_exception(exception, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_tariffs_import_csv_options] = {}
            session[:import_csv_tariffs_import_csv_options][:sep] = @sep
            session[:import_csv_tariffs_import_csv_options][:dec] = @dec

            if rows_too_big?(exception, tariff_id)
              redirect_to(action: 'import_csv2', id: tariff_id, step: '0') && (return false)
            end

            begin
              session[:file] = File.open("/tmp/#{session["temp_tariff_name_csv_#{tariff_id}".to_sym]}.csv", 'rb').read
            rescue => exception
              MorLog.log_exception(exception, Time.now.to_i, params[:controller], params[:action])
              flash[:notice] = _('Please_upload_file')
              redirect_to(action: 'import_csv2', id: tariff_id, step: '1') && (return false)
            end
            Tariff.clean_after_import(session["temp_tariff_name_csv_#{tariff_id}".to_sym])
            session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
            flash[:notice] = _('MySQL_permission_problem_contact_Kolmisoft_to_solve_it')
            redirect_to(action: 'import_csv2', id: tariff_id, step: '2') && (return false)
          end
          default_time = Time.now
          session[:default_effective_from] = default_time - default_time.sec
          flash[:status] = _('File_uploaded') if !flash[:notice]
        end
      else
        session["tariff_name_csv_#{tariff_id}".to_sym] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: 'import_csv2', id: tariff_id, step: '1') && (return false)
      end
      @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
    end

    if  @step > 2
      unless ActiveRecord::Base.connection.tables.include?(session["temp_tariff_name_csv_#{tariff_id}".to_sym]) && session[:file]
        flash[:notice] = _('Please_upload_file')
        redirect_to(action: 'import_csv2', id: tariff_id, step: '0') && (return false)
      end

      if session["tariff_name_csv_#{tariff_id}".to_sym] && session[:file]

        if @step == 3
          my_debug_time 'step 3'
          params_prefix_id = params[:prefix_id]
          if params_prefix_id && params[:rate_id] && params_prefix_id.to_i >= 0 && params[:rate_id].to_i >= 0
            @options = {}
            @options[:imp_prefix] = params_prefix_id.to_i
            @options[:imp_rate] = params[:rate_id].to_i
            if @effective_from_active
              params_effective_from = params[:effective_from].to_i
              if params_effective_from >= 0
                @options[:imp_effective_from] = params_effective_from
                @options[:current_user_tz] = Time.zone.now.formatted_offset
                date_format = params[:effective_from_date_format] + ' %H:%i:%s'
                @options[:date_format] = date_format.blank? ? '%Y-%m-%d %H:%i:%s' : date_format
              else
                change_date_from
                blank_params = params[:date_from].any? { |_param, value| value.blank? }
                if blank_params # Effective From not selected manualy, default value will be used
                  @options[:manual_effective_from] = session[:default_effective_from]
                else # Effective from selected manually
                  chosen_time = session_from_datetime
                  @options[:manual_effective_from] = chosen_time[0, chosen_time.rindex(':') + 1]
                end
              end
            end
            @options[:imp_increment_s] = params[:increment_id].to_i
            @options[:imp_min_time] = params[:min_time_id].to_i
            @options[:imp_ghost_percent] = params[:ghost_percent_id].to_i
            options_to_session(params)

            @options[:imp_cc] = -1

            @options[:imp_city] = -1

            @options[:imp_country] = -1
            @options[:imp_connection_fee] = params[:connection_fee_id] ? params[:connection_fee_id].to_i : -1
            @options[:imp_date_day_type] = params[:rate_day_type].to_s
            @options[:imp_dst] = params[:destination_id] ? params[:destination_id].to_i : -1
            @options[:imp_change] = params[:change_action].try(:to_i) || -1
            @options[:imp_delete_effective_from] = params[:delete_effective_from].try(:to_i) || -1

            @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)
            # #5808 not cheking any more
            # unless flash[:notice_2].blank?
            #   flash[:notice] = _('Tariff_import_incorrect_time').html_safe
            #   flash[:notice] += '<br /> * '.html_safe + _('Please_select_period_without_collisions').html_safe
            #   redirect_to :action => "import_csv", :id => @tariff.id, :step => "2" and return false
            # end

            @options[:imp_time_from_type] = params[:time_from][:hour].to_s + ":" + params[:time_from][:minute].to_s + ":" + params[:time_from][:second].to_s if params[:time_from]
            @options[:imp_time_till_type] = params[:time_till][:hour].to_s + ":" + params[:time_till][:minute].to_s + ":" + params[:time_till][:second].to_s if params[:time_till]

            @options[:imp_update_dest_names] = params[:update_dest_names].to_i if admin? || manager?
            @options[:imp_delete_unimported_prefix_rates] = params[:delete_unimported_prefix_rates].to_i
            @options[:high_rate] = Rate.save_high_rate(params[:high_rate])
            @options[:ignore_effective_from_time] = params[:ignore_effective_from_time].to_i
            @options[:imp_delete_effective_from] = params[:delete_effective_from].try(:to_i) || -1
            @options[:imp_blocked] = params[:blocked].try(:to_i) || -1

            if (admin? || manager?) && params[:update_dest_names].to_i == 1
              if params[:destination_id] && params[:destination_id].to_i >=0
                check_destination_names = 'select count(*) as notnull from ' + session["tariff_name_csv_#{@tariff.id}".to_sym].to_s + ' where original_destination_name is NOT NULL'
                not_blank_values = ActiveRecord::Base.connection.select(check_destination_names).first["notnull"].to_i
                if not_blank_values == 0
                  sql = 'UPDATE ' + session["tariff_name_csv_#{@tariff.id}".to_sym].to_s + " JOIN destinations ON (replace(col_1, '\\r', '') = destinations.prefix) SET original_destination_name = destinations.name"
                  ActiveRecord::Base.connection.execute(sql)
                end
              else
                flash[:notice] = _('Please_Select_Columns_destination')
                redirect_to(action: 'import_csv2', id: tariff_id, step: '2') && (return false)
              end
            end

            # priority over csv

            @options[:manual_connection_fee] = ''
            @options[:manual_increment] = ''
            @options[:manual_min_time] = ''

            @options[:manual_connection_fee] = params[:manual_connection_fee] if params[:manual_connection_fee]
            @options[:manual_increment] = params[:manual_increment]
            @options[:manual_min_time] = params[:manual_min_time] if params[:manual_min_time]
            @options[:manual_ghost_percent] = params[:manual_ghost_percent] if params[:manual_ghost_percent]

            @options[:sep] = @sep
            @options[:dec] = @dec
            @options[:file]= session[:file]
            @options[:file_size] = session[:file_size]
            @options[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session["tariff_name_csv_#{tariff_id}".to_sym]}")
            session["tariff_import_csv2_#{tariff_id}".to_sym] = @options
            flash[:status] = _('Columns_assigned')
          else
            flash[:notice] = _('Please_Select_Columns')
            redirect_to(action: 'import_csv2', id: tariff_id, step: '2') && (return false)
          end
        end

        if session["tariff_import_csv2_#{tariff_id}".to_sym] && session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_prefix] && session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_rate]
          # check how many destinations and should we create new ones?
          if @step == 4
            my_debug_time 'step 4'
            options_to_session_delete(session)
            @tariff_analize = @tariff.analize_file(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym])
            tariff_analize_bad_prefixes = @tariff_analize[:bad_prefixes]
            session[:bad_destinations] = tariff_analize_bad_prefixes
            session[:bad_lines_array] = tariff_analize_bad_prefixes
            session[:bad_lines_status_array] = @tariff_analize[:bad_prefixes_status]

            flash[:status] = _('Analysis_completed')
            session["tariff_analize_csv2_#{tariff_id}".to_sym] = @tariff_analize
          end
          # update rates (ratedetails actually)
          if @step == 5 && check_session(tariff_id)
            @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]

            my_debug_time 'step 5'
            if %w[admin manager].include?(session[:usertype])
              begin
                status = ''
                session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file] = @tariff.create_deatinations(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                status += _('Created_destinations') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file]}" if session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_destination_from_file].to_i > 0
                if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_update_dest_names].to_i == 1
                  session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file] = @tariff.update_destinations(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
                  status += '<br />' if status.present?
                  status += _('Destination_names_updated') + ": #{session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file]}" if session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_destination_from_file].to_i > 0
                end
                session["tariff_analize_csv2_#{tariff_id}".to_sym][:nil_destinations_in_db] = Destination.count_without_group
                flash[:status] = status if status.present?
              rescue => exc
                # my_debug_time exc.to_yaml
                flash[:notice] = _('collision_Please_start_over')
                # my_debug_time "clean start"
                Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
                session["temp_tariff_name_csv_#{@tariff.id}".to_sym] = nil
                # my_debug_time "clean done"
                redirect_to(action: :import_csv2, id: @tariff.id, step: '0') && (return false)
              end
            end
          end

          # delete unimported rates
          if @step == 6 && check_session(tariff_id)
              my_debug_time 'step 6'

              @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
              @tariff_analize[:deleted_rates] = 0

              if session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_delete_unimported_prefix_rates].to_i == 1
                @tariff_analize[:deleted_rates] += @tariff.delete_unimported_rates(session["tariff_name_csv_#{tariff_id}".to_sym],
                                                                                  session["tariff_import_csv2_#{tariff_id}".to_sym])
              end

              if @tariff_analize[:rates_to_delete].to_i > 0
                change = session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_change].to_i
                if change > -1
                  @tariff_analize[:deleted_rates] += @tariff.delete_by_action(session["tariff_name_csv_#{tariff_id}".to_sym],
                                                                              session["tariff_import_csv2_#{tariff_id}".to_sym])
                end
              end
              flash[:status] = _('deleted_rates') + ': ' + @tariff_analize[:deleted_rates].to_s
              Action.add_action(session[:user_id], 'tariff_import_2', _('Tariff_was_imported_from_CSV'))
          end

          # update rates (ratedetails actually)

          if @step == 7 && check_session(tariff_id)
            @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
            my_debug_time 'step 7'

            delete_effective_from = session["tariff_import_csv2_#{tariff_id}".to_sym][:imp_delete_effective_from].to_i
            if delete_effective_from > -1
              @tariff.delete_by_effective_from(session["tariff_name_csv_#{tariff_id}".to_sym],
                session["tariff_import_csv2_#{tariff_id}".to_sym])
            end

            session["tariff_analize_csv2_#{tariff_id}".to_sym][:updated_rates_from_file] = @tariff_analize[:rates_to_update]
            @tariff.update_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym]) if session["tariff_analize_csv2_#{tariff_id}".to_sym].present?
            if @tariff_analize[:new_rates_to_create].to_i.zero?
              @tariff.insert_ratedetails(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
            end
            flash[:status] = "#{_('Rates_updated')}: #{@tariff_analize[:rates_to_update]}"
          end

          # create rates/ratedetails
          if @step == 8 && check_session(tariff_id)
            @tariff_analize = session["tariff_analize_csv2_#{tariff_id}".to_sym]
            my_debug_time 'step 8'
            session["tariff_analize_csv2_#{tariff_id}".to_sym][:created_rates_from_file] = @tariff.create_rates_from_csv(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
            if @tariff_analize[:new_rates_to_create].to_i > 0
              @tariff.insert_ratedetails(session["tariff_name_csv_#{tariff_id}".to_sym], session["tariff_import_csv2_#{tariff_id}".to_sym], session["tariff_analize_csv2_#{tariff_id}".to_sym])
            end
            flash[:status] = "#{_('New_rates_created')}: #{@tariff_analize[:new_rates_to_create]}"
          end

          check_session_redirect(check_session(tariff_id), tariff_id) if @step >= 5

          @tariff.changes_present_set_1
          tariff_rates_effective_from_cache("-t #{tariff_id}") if (@step == 7 || @step == 8)
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to(action: 'import_csv2', id: tariff_id, step: '2') && (return false)
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to(controller: 'tariffs', action: @action.to_sym) && (return false)
      end
    end
  end

  def high_rates
    @page_title = _('High_Rates')
    @csv2 = 1
    tariff_id = params[:tariff_id].to_i
    imp_opts = session["tariff_import_csv2_#{tariff_id}"]
    imp_table = session["tariff_name_csv_#{tariff_id}"]
    @rows = Tariff.imp_high_rates(
      imp_opts[:high_rate],
      table: imp_table, dec: imp_opts[:dec], rate_col: imp_opts[:imp_rate]
    )

    render('tariffs/bad_rows_from_csv', layout: 'layouts/mor_min')
  end

  def bad_rows_from_csv
    @page_title = _('Bad_rows_from_CSV_file')
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @rows = session[:bad_lines_array]
      @status = session[:bad_lines_status_array]
    else
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        @rows = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]} WHERE f_error = 1")
      end
    end
    render(layout: 'layouts/mor_min')
  end

  def zero_rates_from_csv
    @page_title = _('Zero_rates_csv')
    @csv2= params[:csv2].to_i
    params_tariff_id_to_i = params[:tariff_id].to_i
    if @csv2.to_i == 0
      @rows = []
    else
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params_tariff_id_to_i}".to_sym])
        @rows = ActiveRecord::Base.connection.
            select_all("SELECT *
                        FROM #{session["tariff_name_csv_#{params_tariff_id_to_i}".to_sym]}
                        WHERE col_#{session["tariff_import_csv2_#{params_tariff_id_to_i}".to_sym][:imp_rate]} #{SqlExport.is_zero_condition}")
      else
        @rows = []
      end
    end
    render(template: 'cdr/bad_rows_from_csv', layout: 'layouts/mor_min', locals: {rows: @rows})
  end

  def dir_to_update_from_csv
    @page_title = _('Direction_to_update_from_csv')
    @file = session[:file]
    @status = session[:status_array]
    @csv2= params[:csv2].to_i
    if @csv2.to_i == 0
      @dst = session[:dst_to_update_hash]
    else
      @tariff_id = params[:tariff_id].to_i
      if ActiveRecord::Base.connection.tables.include?(session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym])
        imp_cc = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_cc]
        table_name = session["tariff_name_csv_#{params[:tariff_id].to_i}".to_sym]
        imp_prefix = session["tariff_import_csv2_#{@tariff_id}".to_sym][:imp_prefix]
        @directions = ActiveRecord::Base.connection.select_all("SELECT prefix, destinations.direction_code old_direction_code, replace(col_#{imp_cc}, '\\r', '') new_direction_code from #{table_name} join directions on (replace(col_#{imp_cc}, '\\r', '') = directions.code) join destinations on (replace(col_#{imp_prefix}, '\\r', '') = destinations.prefix) WHERE destinations.direction_code != directions.code;")
      end
    end
    render(layout: 'layouts/mor_min')
  end

  def rate_import_status
    # render(:layout => false)
  end

  def rate_import_status_view
    render(layout: false)
  end

  # before_filter : tariff(find_tariff_from_id)
  def delete_all_rates
    checking_for_tariff = check_user_for_tariff(@tariff.id)
    return false if !checking_for_tariff
    @tariff.delete_all_rates
    flash[:status] = _('All_rates_deleted')
    tariff_rates_effective_from_cache("-t #{@tariff.id}")
    redirect_to action: params[:redirect_link] || 'list'
  end

  # returns first letter of destination group name if it has any rates set, if nothing is set return 'A'
  def tariff_dstgroups_with_rates(tariff_id)
    res = Destinationgroup.select('destinationgroups.name')
                          .joins(:rates).where("rates.tariff_id = #{tariff_id}")
                          .group('destinationgroups.id').order('destinationgroups.name ASC')
                          .all
    res.map! { |rate| rate['name'][0..0] }
    res.uniq
  end

  def dstgroup_name_first_letters
    res = Destination.select('destinationgroups.name')
                     .joins(:destinationgroup)
                     .group(:destinationgroup_id)
                     .order('destinationgroups.name ASC')
                     .all
    res.map! {|dstgroup| dstgroup['name'][0..0].upcase}
    res.uniq
  end

  # for final user
  # before_filter : user; tariff
  def user_rates
    @page_title = _('Personal_rates')
    @page_icon = 'coins.png'
    if not (user? or reseller?) or session[:show_rates_for_users].to_i != 1
      dont_be_so_smart
      redirect_to(:root) && (return false)
    end
    @show_currency_selector = true

    @page = 1
    @page = params[:page].to_i if params[:page]

    (params[:st] && ('A'..'Z').include?(params[:st].upcase)) ? @st = params[:st].upcase : @st = 'A'
    @dgroupse = Destinationgroup.where(['name like ?', "#{@st}%"]).order('name ASC')

    @dgroups = []
    session_items_per_page = session[:items_per_page].abs
    iend = ((session_items_per_page * @page) - 1)
    iend = @dgroupse.size - 1 if iend > (@dgroupse.size - 1)
    (((@page - 1) * session_items_per_page)..iend).each { |index| @dgroups << @dgroupse[index] }

    @rates = @tariff.rates_by_st(@st, 0, 10000)
    @total_pages = (@rates.size.to_d / session_items_per_page.to_d).ceil

    @all_rates = @rates
    @rates = []
    iend = ((session_items_per_page * @page) - 1)
    all_rates_minus_one = @all_rates.size - 1
    iend = all_rates_minus_one if iend > (all_rates_minus_one)
    (((@page - 1) * session_items_per_page)..iend).each { |index| @rates << @all_rates[index] }

    exrate = Currency.count_exchange_rate(@tariff.currency, session[:show_currency].gsub(/[^A-Za-z]/, ''))
    @ratesd = Ratedetail.find_all_from_id_with_exrate({rates: @rates, exrate: exrate, destinations: true, directions: true})

    @letter_select_header_id = @page_select_header_id = @tariff.id

    @exchange_rate = count_exchange_rate(@tariff.currency, session[:show_currency].gsub(/[^A-Za-z]/, ''))
    @cust_exchange_rate = count_exchange_rate(session[:default_currency], session[:show_currency].gsub(/[^A-Za-z]/, ''))
    @show_rates_without_tax = Confline.get_value('Show_Rates_Without_Tax', @user.owner_id)
  end

  # ======= Day setup ==========

  def day_setup
    @page_title = _('Day_setup')
    @page_icon = 'date.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Day_setup'
    @days = Day.order('date ASC')
  end

  def day_add
    date = params[:date][:year] + '-' + good_date(params[:date][:month]) + '-' + good_date(params[:date][:day])

    # real_date = Time.mktime(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day]))

    if Application.validate_date(params[:date][:year], good_date(params[:date][:month]), good_date(params[:date][:day])) == 0
      flash[:notice] = _('Bad_date')
      redirect_to(action: 'day_setup') && (return false)
    end

    if Day.where(['date = ? ', date]).first
      flash[:notice] = _('Duplicate_date')
      redirect_to(action: 'day_setup') && (return false)
    end

    attributes = params.slice(:daytype, :description).merge date: date
    day = Day.new(attributes)
    day.save

    flash[:status] = "#{_('Day_added')}: #{date}"
    redirect_to action: 'day_setup'
  end

  def day_destroy
    day = Day.where(id: params[:id]).first
    unless day
      flash[:notice] = _('Day_was_not_found')
      redirect_to(action: :list) && (return false)
    end
    flash[:status] = "#{_('Day_deleted')}: #{day.date}"
    day.destroy
    redirect_to action: 'day_setup'
  end


  def day_edit
    @page_title = _('Day_edit')
    @page_icon = 'edit.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Day_setup'

    @day = Day.where(id: params[:id]).first
    unless @day
      flash[:notice]=_('Day_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def day_update
    day = Day.where(id: params[:id]).first
    unless day
      flash[:notice] = _('Day_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    date = params[:date][:year] + '-' + good_date(params[:date][:month]) + '-' + good_date(params[:date][:day])

    if Day.where(['date = ? and id != ?', date, day.id]).first
      flash[:notice] = _('Duplicate_date')
      redirect_to(action: 'day_setup') && (return false)
    end

    attributes = params.slice(:daytype, :description).merge date: date
    day.assign_attributes(attributes)
    day.save

    flash[:status] = "#{_('Day_updated')}: #{date}"
    redirect_to action: 'day_setup'

  end

  def change_tariff_for_connection_points
    @page_title = _('change_tariff_for_connection_points')
    @tariffs_from = Tariff.tariffs_for_change_tariff(session[:user_id], correct_owner_id)
    @tariffs_to = @tariffs_from
    @tariffs_from.order!(:name) if @tariffs_from
    @tariffs_to.order!(:name) if @tariffs_to
    @selected_tariff = {from: params[:tariff_from], to: params[:tariff_to]}
  end

  def update_tariff_change_checkbox
    tariffs = Tariff.tariffs_for_change_tariff(session[:user_id], correct_owner_id).group('tariffs.id')
    where_sentence = []
    if params[:op_checked] == 'true'
      tariffs = tariffs.joins('LEFT JOIN devices origination_points ON origination_points.op_tariff_id = tariffs.id')
      where_sentence << 'origination_points.op = 1'
    end
    if params[:tp_checked] == 'true'
      tariffs = tariffs.joins('LEFT JOIN devices termination_points ON termination_points.tp_tariff_id = tariffs.id')
      where_sentence << 'termination_points.tp = 1'
    end
    tariffs = tariffs.where(where_sentence.join(' OR '))
    tariffs.order!(:name) if tariffs
    render partial: 'tariff_change_dropdown', layout: false,
           locals: { tariffs: tariffs, name: 'tariff_from', selected: params[:selected].to_i, selected_tariff_id: params[:selected] }
  end

  def update_tariff_for_conection_points
    if params[:tariff_from] && params[:tariff_to]
      tariff_from = Tariff.where(id: params[:tariff_from]).first
      tariff_to = Tariff.where(id: params[:tariff_to]).first
      if tariff_from.blank? || tariff_to.blank?
        flash[:notice]=_('Tariff_was_not_found')
        redirect_to(action: :list) && (return false)
      end
      if params[:change_for_tp].blank? && params[:change_for_op].blank?
        flash[:notice] = _('Tariff_was_not_changed_cp_must_be_selected')
        redirect_to(action: :change_tariff_for_connection_points, tariff_from: params[:tariff_from], tariff_to: params[:tariff_to]) && (return false)
      end
      changed_tp = changed_op = 0
      if params[:change_for_op] == '1'
        tariff_from.origination_points.each do |op|
          op.op_tariff_id = tariff_to.id
          op.save
          changed_op += 1
        end
      end
      if params[:change_for_tp] == '1'
        tariff_from.termination_points.each do |tp|
          tp.tp_tariff_id = tariff_to.id
          tp.save
          changed_tp += 1
        end
      end
      flash[:status] = _('Tariffs_was_successfully_updated')
      flash[:status] += '<br/>* ' + _('Termination_points_changed', changed_tp) if changed_tp > 0
      flash[:status] += '<br/>* ' + _('Origination_points_changed', changed_op) if changed_op > 0
    else
      flash[:notice] = _('Tariff_not_found')
    end
    redirect_to action: 'list'
  end


  # ----------------- PDF/CSV export

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_providers_rates_csv
    tariffs = check_user_for_tariff(@tariff)
    return false unless tariffs
    default_currency = Confline.get_value('tariff_currency_in_csv_export').to_i
    currency_name = default_currency == 0 ? session[:show_currency].to_s : @tariff.currency.to_s
    filename = "#{@tariff.name.gsub(' ', '_').upcase}-#{currency_name}.csv"
    file = @tariff.generate_providers_rates_csv(session)
    cookies['fileDownload'] = 'true'
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_csv
    filename = "Rates-#{(session[:show_currency]).to_s}.csv"
    file = @tariff.generate_providers_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  def generate_personal_rates_xlsx
    tariff_id = params[:tariff_id]
    custom_tariff = Device.where(id: params[:device_id]).first.try(:op_custom_tariff_id) if params[:device_id].present?
    tariff = Tariff.where(id: tariff_id).first
    filename = "Rates-#{current_user_id}-#{Time.now.to_i}"
    data = tariff.generate_providers_rates_csv(session, for_xlsx: true, custom_tariff: custom_tariff)
    dir = '/tmp/m2'
    path = "#{dir}/#{filename}"
    path_csv = "#{path}.csv"
    path_xlsx = "#{path}.xlsx"
    File.open(path_csv, 'w'){|file| file.write(data)}
    convert_via_libreoffice(dir, filename, 'csv', 'xlsx')
    file_xlsx = File.open(path_xlsx).read
    send_data(file_xlsx, filename: "#{filename}.xlsx", type: 'application/octet-stream')
    system("rm -f #{path_csv} #{path_xlsx}")
    cookies['fileDownload'] = 'true'
  end

  # before_filter : user; tariff
  def generate_personal_wholesale_rates_pdf
    rates = Rate.includes({destination: :direction})
                .where(['rates.tariff_id = ?', @tariff.id])
                .order('directions.name ASC')
                .all
    options = {
        name: @tariff.name,
        pdf_name: _('Rates'),
        currency: session[:show_currency]
    }
    pdf = PdfGen::Generate.generate_rates_header(options)
    pdf = PdfGen::Generate.generate_personal_wholesale_rates_pdf(pdf, rates, @tariff, options)
    file = pdf.render
    filename = "Rates-#{(session[:show_currency]).to_s}.pdf"
    testable_file_send(file, filename, 'application/pdf')
  end

  # before_filter : tariff(find_tariff_whith_currency)
  def generate_user_rates_csv
    filename = "Rates-#{session[:show_currency]}.csv"
    file = @tariff.generate_user_rates_csv(session)
    testable_file_send(file, filename, 'text/csv; charset=utf-8; header=present')
  end

  def analysis
    @page_title = _('Tariff_analysis')
    @page_icon = 'table_gear.png'

    @prov_tariffs = Tariff.where("purpose = 'provider'").order('name ASC')
    @user_wholesale_tariffs = Tariff.where("purpose = 'user_wholesale'").order('name ASC')
    @currs = Currency.get_active
  end

  def analysis2
    @page_title = _('Tariff_analysis')
    @page_icon = 'table_gear.png'
    params_tariff_id_intern = params["t#{tariff_id}".intern] == '1'

    @prov_tariffs_temp = Tariff.where("purpose = 'provider'").order('name ASC').all
    @user_wholesale_tariffs_temp = Tariff.where("purpose = 'user_wholesale'").order('name ASC').all

    @prov_tariffs = []
    @user_wholesale_tariffs = []
    @all_tariffs = []

    @prov_tariffs_temp.each do |provider_tariff|
      tariff_id = provider_tariff.id
      @prov_tariffs << provider_tariff if params_tariff_id_intern
      @all_tariffs << tariff_id if params_tariff_id_intern
    end

    @user_wholesale_tariffs_temp.each do |wholesale_tariff|
      tariff_id = wholesale_tariff.id
      @user_wholesale_tariffs << wholesale_tariff if params_tariff_id_intern
      @all_tariffs << tariff_id if params_tariff_id_intern
    end

    @curr = params[:currency]

    @tariff_line = ''
    @all_tariffs.each do |tariff|
      @tariff_line << "#{tariff}|"
    end
  end

  def destinations_csv
    sql = "SELECT prefix, directions.name AS 'dir_name', destinations.name AS 'dest_name'  FROM destinations JOIN directions ON (destinations.direction_code = directions.code) ORDER BY directions.name, prefix ASC;"
    res = ActiveRecord::Base.connection.select_all(sql)
    cs = confline('CSV_Separator', correct_owner_id)
    cs = ',' if cs.blank?
    csv_line = res.map { |one_res| "#{one_res['prefix']}#{cs}#{one_res['dir_name'].to_s.gsub(cs, ' ')}#{cs}#{one_res['dest_name'].to_s.gsub(cs, ' ')}" }.join("\n")
    if params[:test].to_i == 1
      render text: csv_line
    else
      send_data(csv_line, type: 'text/csv; charset=utf-8; header=present', filename: 'Destinations.csv')
    end
  end

  def check_tariff_time
    checking_for_tariff = check_user_for_tariff(@tariff.id)
    return false if !checking_for_tariff
    session[:imp_date_day_type] = params[:rate_day_type].to_s

    @f_h, @f_m, @f_s, @t_h, @t_m, @t_s = params[:time_from_hour].to_s, params[:time_from_minute].to_s, params[:time_from_second].to_s, params[:time_till_hour].to_s, params[:time_till_minute].to_s, params[:time_till_second].to_s
    @rate_type, flash[:notice_2] = @tariff.check_types_periods(params)

    # logger.info @f_h

    render(layout: false)
  end

  def update_rates
    action, title = @tariff.purpose == 'user_custom' ? ['custom_tariffs', 'Custom Tariffs'] : ['list', 'Tariffs']

    params[:options_for_path_links] = {out: [
                         'Update Rates',
                         "<a href=\"#{Web_Dir}/tariffs/#{action}\">#{title}</a>",
                         "<a href=\"#\" id=\"billing\">Billing</a>"]}

    @rate_updater = Tariff::RateUpdater.new
    # This line should be removed after the Tariff front-end rework
    render layout: 'm2_admin_layout'
  end

  def update_rates_by_destination_mask
    @rate_updater = Tariff::RateUpdater.new(
      dg_name: params[:dg_name].to_s,
      rate: params[:new_rate].to_s.try(:sub, /[,.;]/, '.').try(:strip),
      tariff: @tariff,
      exchange_rate: 1
    )

    if @rate_updater.update_rates
      flash[:status] = _('rates_successfully_updated')
      redirect_to action: 'rates_list' , id: @tariff.id, st: session[:destination_first_letter]
    else
      flash_errors_for(_('rates_were_not_updated'), @rate_updater)
      # This line should be edited after the Tariff front-end rework
      render layout: 'm2_admin_layout', action: 'update_rates'
    end
  end

  def rate_check
    @options = initialize_rate_check_options
    @options[:number_of_digits] = Confline.get_value('Nice_Number_Digits').to_i
    tariff_query = (@options[:who] == 'providers') ? "purpose = 'provider'" : "purpose = 'user_wholesale'"
    current_user.id = 0 if manager?
    @tariffs = Tariff.where("(#{tariff_query}) AND owner_id = #{current_user.id}").all

    if @tariffs.blank?
      flash[:notice] = _('No_tariffs')
      redirect_to(:root) && (return false)
    end

    if params[:commit] && (@options[:dg_name].delete('%').try(:size).to_i >= 5 || @options[:search_prefix].delete('%').try(:size).to_i >= 2)

      destinations = tariff_rate_check_list(@tariffs)

      flash[:warning] = _('Only_first_500_results_are_shown_Please_update_your_query_to_get_less_results') if destinations.try(:size).to_i >= 500
      max_prefix = 0

      destinations.each_with_index do |dest, index|
        prefix = dest['prefix']
        prefix_length = prefix.length
        max_prefix = prefix_length if prefix_length > max_prefix
        @tariffs.each do |tariff|
          if dest["rate_#{tariff.id}"].blank?
            dest["rate_#{tariff.id}"] = get_prefix_rate(destinations, index, tariff.id, prefix)
            dest["rate_#{tariff.id}_nil"] = true
          end
        end
      end
      @destinations = destinations.sort_by { |item| [item['full_name'], item['prefix']] }
      @options[:max_prefix] = max_prefix
    end
  end

  def get_prefix_rate(destinations, index, tariff_id, prefix)
    rate = nil
    dest_prefix = destinations[index]['prefix']
    while dest_prefix[0] == prefix[0] do

      if dest_prefix == prefix[0..dest_prefix.size-1] && destinations[index]["rate_#{tariff_id}"].present?
        rate = destinations[index]["rate_#{tariff_id}"]
      end
      index -= 1

      break if index == -1 || rate.present?
      dest_prefix = destinations[index]['prefix']
    end
    rate
  end

  def update_effective_from_ajax
    valid = validate_update_effective_from_ajax

    if valid && @date_object && @date_object.year <= 9999
      @rate.update_attributes(effective_from: current_user.system_time(@date_object))
      @rate.tariff_changes_present_set_1
      tariff_rates_effective_from_cache("-pt #{@rate.prefix} #{@rate.tariff_id}")
    end

    if @rate
      rate_effective_from = @rate.effective_from
      effective_date, effective_time = rate_effective_from ?
        [rate_effective_from.strftime(session[:date_format] || '%Y-%m-%d'), rate_effective_from.strftime('%H:%M:%S')] :
        [params[:date], params[:time]]

      render json: {
        date: effective_date,
        time: effective_time
      }
    else
      render json: { error: 'Rate Was Not Found'}
    end
  end

  def compare_tariffs
    params_email = params[:email]
    errors = {}
    if params_email.present?
      if Email.address_validation(params_email)
        cmd = "/usr/local/m2/m2_compare_tariffs #{params[:tariff_1]} #{params[:tariff_2]} \"#{params_email}\" #{params[:currency]} &"
        flash[:status] = _('Task_created_results_will_be_sent_shortly_to_email') + ' ' + params_email.to_s
        system(cmd)
      else
        errors[:invalid_email] = _('Invalid_email_format_in_emails_field')
      end
    else
       errors[:enter_email] = _('Please_enter_email')
    end
    flash_collection_errors_for(_('email_not_sent'), errors)
    (redirect_to action: :list, params: params) && (return false)
  end

  def conversion
    unless admin?
      dont_be_so_smart
      (redirect_to :root) && (return false)
    end

    require 'net/http'
    source = 'https://support.ocean-tel.uk/api/tariff_templates'

    3.times do
      MorLog.my_debug('API to CRM tariff_templates', true)
      MorLog.my_debug("  Request URL: #{source}")
      begin
        @result = JSON.parse(Net::HTTP.get_response(URI.parse(source)).body)
        MorLog.my_debug("  JSON Response: #{@result}")
        break if @result && ['ok', 'not authorized'].include?(@result['status'].to_s)
      rescue => exception
        MorLog.my_debug("  EXCEPTION: #{exception}")
        sleep 2
        next
      end
    end

    if @result && @result['status'] == 'ok'
      @tariff_templates = @result['tariff_templates'].map do |tariff_template|
        [tariff_template['name'], tariff_template['tariff_template_id']]
      end
      @tariff_templates.sort! { |left, right| left[0] <=> right[0] }
    elsif @result && @result['status'] == 'not authorized'
      flash[:notice] = _('Tariff_Templates_could_not_be_retrieved_because_this_Server_installation_was_not_authenticated_in_Kolmisoft_System_Please_contact_Kolmisoft_Support')
    else
      flash[:notice] = _('Tariff_Templates_could_not_be_retrieved_please_refresh_the_page_and_try_again_If_problem_persist_please_contact_Kolmisoft_Support')
    end

    @tariff_templates = [[]] if @tariff_templates.blank?
    session[:tariff_templates] = @tariff_templates
    @tariff_template_id = session[:tariff_template_id].blank? ? @tariff_templates[0] : session[:tariff_template_id]
    @column_separator = Confline.get_value('CSV_Separator', 0).to_s
    @decimal_separator = Confline.get_value('CSV_Decimal', 0).to_s
    @email = Confline.get_value('Conversion_email').to_s.blank? ? current_user.email({first_possible: true}) : Confline.get_value('Conversion_email').to_s
  end

  def conversion_request
    @tariff_template_id = params[:tariff_template_id].to_i
    session[:tariff_template_id] = @tariff_template_id
    @file = params[:file]
    @column_separator = params[:column_separator].to_s.strip
    @decimal_separator = params[:decimal_separator].to_s.strip
    @email = params[:email].to_s.strip

    if validate_conversion_request_params
      require 'net/http'
      require 'base64'

      source = 'https://support.ocean-tel.uk/api/tariff_conversion'
      request_data = {
          tariff_template_id: @tariff_template_id, email: @email,
          column_separator: @column_separator, decimal_separator: @decimal_separator,
          filename: sanitize_filename(@file.original_filename),
          base64encoded: Base64.encode64(@file.read)
      }

      response = JSON.parse(Net::HTTP.post_form(URI.parse(source), request_data).body) rescue {'status' => _('External_Server_error_please_try_again_If_problem_persist_please_contact_Kolmisoft_Support')}

      if response && response['status'] == 'ok'
        flash[:status] = _('Tariff_Conversion_was_successfully_submitted')
        Confline.set_value('Conversion_email', @email)
        redirect_to(action: :conversion) && (return false)
      elsif response && response['status'] == 'not authorized'
        flash[:notice] = _('Tariff_Conversion_was_not_successful_because_this_Server_installation_was_not_authenticated_in_Kolmisoft_System_Please_contact_Kolmisoft_Support')
      elsif response && response['status'] == 'No Active Service Plan'
        flash[:notice] = _('Tariff_Conversion_was_not_successful_because_this_Server_installation_does_not_have_any_active_Service_Plan_in_Kolmisoft_System_Please_contact_Kolmisoft_Support')
      else
        flash_array_errors_for(_('Tariff_Conversion_was_not_successful'), [response['status']])
      end
    end
    render :conversion
  end

  def manage_rates_clear_change_params
    return unless request.xhr?
    clear_manage_rates = params[:clear].present? && params[:clear].to_s == 'clear_manage_rates'
    return unless clear_manage_rates
    %w[rate connection_fee increment_s min_time effective_date effective_time blocked].each { |key| session[:rates_list][:manage_rates_ratedetail][key] = '' }
    render json: {data: {message: 'change paramaters cleared'}}
  end

  private

  def validate_conversion_request_params
    errors = []
    (errors << _('Tariff_Template_not_found')) if @tariff_template_id <= 0
    (errors << _('invalid_email')) if @email.blank? || !Email.address_validation(@email, true)
    (errors << _('Column_Separator_must_be_1_character_long')) if @column_separator.size != 1
    (errors << _('Decimal_Separator_must_be_1_character_long')) if @decimal_separator.size != 1

    if !@file.respond_to?(:original_filename) || !@file.respond_to?(:read) || !@file.respond_to?(:rewind) || @file.size <= 0
      errors << _('File_not_uploaded')
    elsif !%w[csv xls xlsx rar zip].include?(sanitize_filename(@file.original_filename).split('.').last.downcase)
      errors << _('Invalid_File_Type')
    elsif @file.size >= 10485760 # 10 MegaBytes
      errors << _('File_is_too_big')
    end

    errors.present? ? (flash_array_errors_for(_('There_were_errors'), errors) && false) : true
  end

  def validate_update_effective_from_ajax
    id = params[:id]
    @rate = Rate.where(id: id).first
    @tariff = @rate.try(:tariff)
    if @rate.blank? || @tariff.blank? || @tariff.owner_id != corrected_user_id
      return false
    end

    date = params[:date]
    time = params[:time]
    done_clicked = params[:done_clicked]

    return false if time.blank? || date.blank? || done_clicked == 'no'

    date_string = "#{date} #{time}"

    return false if [:id, :date, :time].any? { |key|  params[key].blank? }

    correct_date = Date.strptime(date, "#{session[:date_format] || '%Y-%m-%d'}") rescue nil
    @date_object = time.to_time.change(year: correct_date.year, month: correct_date.month, day: correct_date.day) rescue nil


    return false unless @date_object && correct_date

    return true
  end

  def check_user_for_tariff(tariff)
    tariff = Tariff.where(id: tariff).first if tariff.class.to_s != 'Tariff'
    owner_id = tariff.owner_id

    if reseller? && (owner_id != session[:user_id]) &&
      %w[rate_details rates_list].include?(params[:action])
      dont_be_so_smart
      redirect_to(action: 'list') && (return false)
    elsif (owner_id != session[:user_id]) && !manager?
      dont_be_so_smart
      redirect_to(action: 'list') && (return false)
    end
    return true
  end

  def find_tariff_whith_currency
    @tariff = Tariff.where(['id=?', params[:id]]).first
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def find_tariff_from_id
    @tariff = Tariff.where(id: params[:id]).first

    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def find_user_from_session
    @user = User.includes(:tariff).where(['users.id = ?', session[:user_id]]).first
    unless @user
      flash[:notice]=_('User_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def find_user_tariff
    @tariff = @user.tariff
    unless @tariff
      flash[:notice]=_('Tariff_was_not_found')
      redirect_to(action: :list) && (return false)
    end

    unless @tariff.real_currency
      flash[:notice]=_('Tariff_currency_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.where(['rate_id = ?', rate.id]).order('rate DESC')
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({exrate: exrate, prices: [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    @rate_details
  end

  def initialize_rate_check_options
    options = session[:rate_check] || {}
    who = params[:who].to_s

    options[:who] = who if who.present?
    options[:who] = 'users' if options[:who].blank?
    options[:dg_name] = params[:dg_name].to_s.strip if params[:dg_name]
    options[:search_prefix] = params[:search_prefix].to_s.strip if params[:search_prefix]
    session[:rate_check] = options

    options
  end

  def csv_import_cleanup
    if @tariff_analize && @tariff_analize[:last_step_flag] == true
      my_debug_time 'clean start'
      Tariff.clean_after_import(session["tariff_name_csv_#{@tariff.id}".to_sym])
      # MorLog.my_debug session.to_yaml
      session[:file] = nil

      my_debug_time 'clean done'
    end
  end

  def authorize_user
    if user?
      tariff_id = params[:id].to_i
      authorized = false
      devices = current_user.devices
      devices.each { |device| authorized = true if device.tp_tariff_id.to_i == tariff_id || device.op_tariff_id.to_i == tariff_id }
      unless authorized
        dont_be_so_smart
        redirect_to(:root) && (return false)
      end
    end
  end

  def clean_session_variables
    %i{
      file status_array update_rate_array short_prefix_array bad_lines_array
      bad_lines_status_array manual_connection_fee manual_increment manual_min_time
    }.each {|key| session[key] = nil}

    tariffs_clean = ->(tariff) do
      temp_tariff_name = "temp_tariff_name_csv_#{tariff.id}".to_sym
      if session[temp_tariff_name]
        Tariff.clean_after_import(session[temp_tariff_name])
        session["tariff_import_csv2_#{tariff.id}".to_sym] = session[temp_tariff_name] = nil
      end
    end

    @prov_tariffs.each(&tariffs_clean) if @prov_tariffs
    @tariffs.each(&tariffs_clean) if @tariffs
  end

  def find_rate
    @rate = Rate.where(id: params[:id]).first
    unless @rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to action: :list
      false
    end
  end

  def convert_blocked_params(params)
    params.each { |key, value| params[key] = -1 if params[key].to_s.downcase == 'blocked' }
  end

  def options_to_session(params)
    %i[ prefix_id rate_id effective_from connection_fee_id increment_id min_time_id ghost_percent_id destination_id manual_connection_fee manual_increment manual_min_time manual_ghost_percent change_action blocked ].each do |key|
      session[key] = params[key]
    end
    if params[:date_from][:year].present? && params[:date_from][:month].present? && params[:date_from][:day].present? && params[:date_from][:hour].present? && params[:date_from][:minute].present?
      session[:import_manual_eff] = manual_effective_date_from(params[:date_from])
    end
    if params[:time_from].present?
      session[:time_from_hour] = params[:time_from][:hour].to_s
      session[:time_from_minute] = params[:time_from][:minute].to_s
      session[:time_from_second] = params[:time_from][:second].to_s
    end
    if params[:time_till].present?
      session[:time_till_hour] = params[:time_till][:hour].to_s
      session[:time_till_minute] = params[:time_till][:minute].to_s
      session[:time_till_second] = params[:time_till][:second].to_s
    end
    session[:update_dest_names] = params[:update_dest_names]
    session[:delete_unimported_prefix_rates] = params[:delete_unimported_prefix_rates].to_i
    session[:effective_from_date_format] = params[:effective_from_date_format]
    session[:rate_day_type] = params[:rate_day_type]
    session[:high_rate] = Rate.save_high_rate(params[:high_rate])
  end

  def options_to_session_delete(session)
    session.delete(:time_from_hour)
    session.delete(:time_from_minute)
    session.delete(:time_from_second)
    session.delete(:time_till_hour)
    session.delete(:time_till_minute)
    session.delete(:time_till_second)
    session.delete(:import_manual_eff)
    %i[ prefix_id rate_id effective_from connection_fee_id increment_id min_time_id ghost_percent_id destination_id manual_connection_fee manual_increment manual_min_time manual_ghost_percent blocked ].each do |key|
      session.delete(key)
    end
    session.delete(:rate_day_type)
    session.delete(:update_dest_names)
    session.delete(:delete_unimported_prefix_rates)
    session.delete(:high_rate)
    session.delete(:effective_from_date_format)
  end

  def tariff_rate_check_list(tariffs)
    start_point, end_point, index, destinations, destinations_tmp = 0, 40, 0, [], []

    begin
      tariffs_rate_check_list_select_query, tariffs_rate_check_data_select_query, tariffs_joins_query, tariffs_where_query, tariffs_order_query, tariffs_group_query = '', '', '', [], [], []
      @tariffs[start_point...end_point].each do |tariff|
        currency = session[:show_currency]
        queries = tariff.queries(currency)
        tariffs_rate_check_list_select_query << queries[0]
        tariffs_rate_check_data_select_query << queries[1]
        tariffs_joins_query << queries[2]
        tariffs_where_query << queries[3]
        tariffs_order_query << queries[4]
        tariffs_group_query << queries[5]
        index += 1
      end

      rate_check_list_final_sql = 'SELECT rate_check_list.prefix, rate_check_list.full_name ' +
      "#{tariffs_rate_check_list_select_query} " +
      'FROM ( ' +
            'SELECT * ' +
            'FROM ( ' +
                  'SELECT rates.prefix AS prefix, CONCAT_WS(\' \', destinations.name) AS full_name, ' +
                  "rates.effective_from, ratedetails.rate #{tariffs_rate_check_data_select_query} " +
                  'FROM destinations ' +
                  'INNER JOIN rates ON rates.destination_id = destinations.id ' +
                  'LEFT JOIN ratedetails ON ratedetails.rate_id = rates.id ' +
                  "#{tariffs_joins_query} " +
                  "WHERE (#{tariffs_where_query.join(' OR ')}) " +
                  "AND destinations.name LIKE '#{@options[:dg_name].present? ? @options[:dg_name] : '%'}' " +
                  "AND destinations.prefix LIKE '#{@options[:search_prefix].present? ? @options[:search_prefix] : '%'}' " +
                  'AND (rates.effective_from <= NOW() OR rates.effective_from IS NULL) ' +
                  "ORDER BY #{tariffs_order_query.join(', ')}, rates.effective_from DESC, LENGTH(full_name) DESC " +
                  ') AS rate_check_data ' +
            "GROUP BY #{tariffs_group_query.join(', ')} " +
            ') AS rate_check_list ' +
      'GROUP BY rate_check_list.prefix ORDER BY rate_check_list.full_name LIMIT 500'

      # If no tariffs no need to show destinations, so []
      destinations_tmp = tariffs_where_query.blank? ? [] : ActiveRecord::Base.connection.select_all(rate_check_list_final_sql).sort_by { |item| item['prefix'] }

      if destinations.blank?
        destinations = destinations_tmp
      else
        destinations_tmp.each do |dst_tmp|
          dst_index = destinations.index { |dst| dst['prefix'] == dst_tmp['prefix'] }
          if dst_index
            destinations[dst_index].merge!(dst_tmp)
          else
            destinations << dst_tmp
          end
        end
      end

      if index == end_point
        end_point += 40
        start_point += 40
      end
    end while index <= tariffs.count

    return destinations
  end

  def check_session(tariff_id)
    session["tariff_analize_csv2_#{tariff_id}".to_sym].present?
  end

  def check_session_redirect(result, tariff_id)
    return if result
    flash[:notice] = _('Tariff_was_not_imported')
    redirect_to(action: :import_csv2, id: tariff_id) && (return false)
  end
  def get_active_rates_ids(condition)
    sql = "SELECT id FROM (SELECT rates.id, rates.prefix, tariffs.purpose FROM rates
            LEFT JOIN destinations on rates.destination_id = destinations.id
            LEFT JOIN tariffs ON rates.tariff_id = tariffs.id
            WHERE (effective_from < now() OR effective_from IS NULL) AND #{condition}
            ORDER BY rates.effective_from DESC, tariffs.purpose ASC, id DESC) AS tmp_table GROUP BY prefix"
    ActiveRecord::Base.connection.select_all(sql).rows.flatten
  end

  def tariff_changes_present_set_1
    @tariff.try(:changes_present_set_1) if @tariff && @tariff.is_a?(Tariff)
  end

  def tariff_rates_effective_from_cache(command_params)
    Tariff.tariff_rates_effective_from_cache(command_params)
    tariff_rates_effective_from_error_check
  end

  def manual_effective_date_from(date_from)
    "#{date_from[:year]}-#{date_from[:month]}-#{date_from[:day]} #{date_from[:hour]}:#{date_from[:minute]}:00"
  end

  def rows_too_big?(exception, tariff_id)
    if exception.class.to_s.include?('ActiveRecord::StatementInvalid') && exception.message.include?('Row size too large')
      session["temp_tariff_name_csv_#{tariff_id}".to_sym] = nil
      flash[:notice] = _('Invalid_file_format')
      return true
    end
    false
  end

  def authorize_manager_functionality
    if manager?
      manager = User.where(id: session[:user_id]).first
      unauthorized = false
      if @tariff.purpose == 'provider'
        in_use = Tariff.tariffs_in_use(manager.id)
        unauthorized = (in_use.present? && in_use.exclude?(@tariff.id)) || manager.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_vendors_tariffs, ac: 2)
      end

      if @tariff.purpose == 'user_wholesale'
        in_use = Tariff.tariffs_in_use(manager.id, 'op')
        unauthorized = (in_use.present? && in_use.exclude?(@tariff.id)) || manager.authorize_manager_fn_permissions_with_access_level(fn: :billing_tariffs_users_tariffs, ac: 2)
      end

      if unauthorized
        flash[:notice] = _('You_are_not_authorized_to_view_this_page')
        redirect_to(:root) && (return false)
      end
    end
  end

  def rates_list_set_correct_layout_path_link
    if @tariff.is_purpose_user_custom?
      params[:options_for_path_links] = {
          out: [
              "<a href=\"#{Web_Dir}/tariffs/rates_list/#{@tariff.id}\" id=\"tariff name\">#{@tariff.name}</a>",
              "<a href=\"#{Web_Dir}/tariffs/custom_tariffs\">Custom Tariffs</a>",
              "<a href=\"#\" id=\"billing\">Billing</a>"
          ]
      }
    end

    # Param for Tariff name in path header (Billing > Tariffs > NAME)
    params[:spec_param_for_layout_name] = @tariff.name.to_s unless user?
  end

  def rates_list_quick_rate_creation
    params_rate = params[:rate]
    params_rate[:rate] = if params_rate && params_rate[:rate].try(:downcase) == 'blocked'
                           '-1'
                         else
                           nice_input_separator(params_rate[:rate])
                         end
    effective_date = params[:effective_date]
    effective_time = params[:effective_time]
    @effective_from = if effective_date.present?
                        current_user.system_time(effective_date.to_s + ' ' + effective_time.to_s + ':00')
                      else
                        DateTime.now
                      end
    if params_rate
      params_rate[:effective_from] = @effective_from
      params_rate[:prefix] = params_rate[:prefix].strip
    end

    @quick_rate = Rate.new
    unless user?
      @quick_rate.quick_create(params_rate)
      if @quick_rate.changed?
        if @quick_rate.quick_save
          @tariff.try(:changes_present_set_1)
          flash[:status] = _('rate_successfully_created')
          tariff_rates_effective_from_cache("-pt #{@quick_rate.prefix} #{@tariff.id}")
          # New Blank Rate Object Created After
          @quick_rate = Rate.new
        else
          flash_errors_for(_('rate_was_not_created'), @quick_rate)
        end
      end
    end
  end

  def rates_list_manage_rates(condition = '')
    effective_date = @options[:manage_rates_ratedetail]['effective_date']
    effective_time = @options[:manage_rates_ratedetail]['effective_time']

    @manage_rates_effective_from = if effective_date.present?
                                     current_user.system_time("#{effective_date} #{effective_time}:00")
                                   else
                                     DateTime.now
                                   end

    if !user? && params[:commit] == _('rates_list_manage_rates_apply_changes')
      manage_rates_errors = []
      manage_rates_updated = []

      rate = @options[:manage_rates_ratedetail]['rate'].to_s.try(:sub, /[\,\.\;]/, '.')
      if rate.present? && (rate.to_s =~ /^-?(\d+|\d+.{1}\d+)$/).nil?
        manage_rates_errors << _('Incorrect_Rate_value')
      end

      connection_fee = @options[:manage_rates_ratedetail]['connection_fee'].to_s.try(:sub, /[\,\.\;]/, '.')
      if connection_fee.present? && (connection_fee.to_s =~ /^-?(\d+|\d+.{1}\d+)$/).nil?
        manage_rates_errors << _('Incorrect_Connection_Fee_value')
      end

      increment_s = @options[:manage_rates_ratedetail]['increment_s']
      if increment_s.present? && (increment_s.to_s =~ /^(\d+)$/).nil?
        manage_rates_errors << _('Incorrect_Increment_value')
      end

      min_time = @options[:manage_rates_ratedetail]['min_time']
      if min_time.present? && (min_time.to_s =~ /^(\d+)$/).nil?
        manage_rates_errors << _('Incorrect_Minimal_Time_value')
      end

      effective_from = @manage_rates_effective_from
      blocked = @options[:manage_rates_ratedetail]['blocked'].to_i

      if manage_rates_errors.present?
        flash_array_errors_for(_('Rates_were_not_updated'), manage_rates_errors)
      else
        active_rates = get_active_rates_ids(condition)
        update_rates_condition = "(rates.id IN (#{active_rates.join(', ').presence || -1}))"

        if active_rates.blank?
          flash_array_errors_for(_('Rates_were_not_updated'), [_('Active_Rates_in_search_not_found')])
        else
          if rate.present?
            retry_lock_error(5) {
              ActiveRecord::Base.connection.execute("
                UPDATE rates LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
                SET ratedetails.rate = #{rate}
                WHERE #{update_rates_condition};
              ")
            }
            manage_rates_updated << "Rate: #{rate.gsub('.', Confline.get_value('Global_Number_Decimal').to_s || '.')}"
          end

          if connection_fee.present?
            retry_lock_error(5) {
              ActiveRecord::Base.connection.execute("
                UPDATE rates LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
                SET ratedetails.connection_fee = #{connection_fee}
                WHERE #{update_rates_condition};
              ")
            }
            manage_rates_updated << "Connection Fee: #{connection_fee.gsub('.', Confline.get_value('Global_Number_Decimal').to_s || '.')}"
          end

          if increment_s.present?
            retry_lock_error(5) {
              ActiveRecord::Base.connection.execute("
                UPDATE rates LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
                SET ratedetails.increment_s = #{increment_s}
                WHERE #{update_rates_condition};
              ")
            }
            manage_rates_updated << "Increment: #{increment_s}"
          end

          if min_time.present?
            retry_lock_error(5) {
              ActiveRecord::Base.connection.execute("
                UPDATE rates LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
                SET ratedetails.min_time = #{min_time}
                WHERE #{update_rates_condition};
              ")
            }
            manage_rates_updated << "Minimal Time: #{min_time}"
          end

          if effective_from.present?
            retry_lock_error(5) {
              ActiveRecord::Base.connection.execute("
                UPDATE rates
                SET rates.effective_from = '#{effective_from}'
                WHERE #{update_rates_condition};
              ")
            }

            manage_rates_updated << "Effective From: #{effective_from}"
          end

          if blocked.to_i > -1
            retry_lock_error(5) {
              ActiveRecord::Base.connection.execute("
                UPDATE rates LEFT JOIN ratedetails ON rates.id = ratedetails.rate_id
                SET ratedetails.blocked = #{blocked}
                WHERE #{update_rates_condition};
              ")
            }
            manage_rates_updated << (blocked == 1 ? 'Blocked' : 'Unblocked')
          end

          flash_array_status_for(_('Refined_Active_Rates_successfully_updated_to'), manage_rates_updated)
          @tariff.try(:changes_present_set_1)
          tariff_rates_effective_from_cache("-t #{@tariff.id}")
        end
      end
    end
  end

  def rates_list_options
    @options = session[:rates_list] || {}

    %i[prefix destination show_only_active_rates device_id order_by order_desc].each do |key|
      params[key] ||= @options[key]
    end

    @options[:manage_rates_ratedetail] = session[:rates_list][:manage_rates_ratedetail] || {}
    params[:manage_rates_ratedetail] ||= {}
    @options[:manage_rates_ratedetail]['blocked'] = @options[:manage_rates_ratedetail]['blocked'].presence || -1

    %w[rate connection_fee increment_s min_time effective_date effective_time blocked].each do |key|
      params[:manage_rates_ratedetail][key] ||= @options[:manage_rates_ratedetail][key]
    end

    @options = load_params_to_session(session[:rates_list])

    unless user?
      %w[rate connection_fee increment_s min_time].each do |key|
        @options[:manage_rates_ratedetail][key] = @options[:manage_rates_ratedetail][key].to_s.gsub(' ', '')
      end
    end

    @options[:commit] = params[:commit]
    @options[:clear_search] = params[:clear].present? && params[:clear] == 'clear'

    @options[:searching_by] = if [_('rates_list_manage_rates_destination'), _('rates_list_manage_rates_prefixes')].include?(params[:commit].to_s)
                                params[:commit]
                              elsif [_('rates_list_manage_rates_destination'), _('rates_list_manage_rates_prefixes')].include?(@options[:commit])
                                @options[:commit]
                              else
                                @options[:searching_by]
                              end

    %i[commit searching_by prefix destination show_only_active_rates].each { |key| @options[key] = '' } if @options[:clear_search]
  end
end
