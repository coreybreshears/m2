# -*- encoding : utf-8 -*-
# Destinations managing and statistics.
class DestinationsController < ApplicationController
  layout :determine_layout
  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, only: [:edit, :update, :destroy]
  before_filter :find_direction, only: [:list, :create, :stats, :new, :create]

  def list
    @page_title = _('Destinations')

    @page = 1
    @page = params[:page].to_i if params[:page]
    items_per_page = session[:items_per_page]
    @destinations2 = @direction.destinations_with_groups
    @total_pages = (@destinations2.size.to_d / items_per_page).ceil

    if @page > @total_pages
      redirect_to action: :list, page: @total_pages
    end

    @destinations = []
    iend = items_per_page * @page - 1
    iend = (@destinations2.size - 1) if iend > (@destinations2.size - 1)
    for item in (items_per_page * @page - items_per_page)..iend
      @destinations << @destinations2[item] if @destinations2[item]
    end

    @page_select_header_id = @direction.id

    store_location
  end

  def new
    @page_title = _('Add_new_destination')
    @page_icon = 'add.png'

    prefix = params[:dest_prefix] || ''
    name = params[:dest_name] || ''

    @destination = Destination.new(prefix: prefix, name: name)
  end

  def create
    @page_title = _('Add_new_destination')

    params[:destination]['direction_code'] = @direction.code
    dest = Destination.where(prefix: params[:destination][:prefix]).first
    if dest && dest.direction
      flash[:notice] = _('Destination_exist_and_belong_to_Direction') + ': ' + dest.direction.name.to_s
      redirect_to(action: :new, id: @direction, dest_prefix: params[:destination][:prefix], dest_name: params[:destination][:name]) && (return false)
    end

    @dest = Destination.new(params[:destination])

    @dest.name.to_s.strip!
    # @dest.destinationgroup_id = dg.id if dg
    if @dest.save
      flash[:status] = _('Destination_was_successfully_created')
      redirect_to(action: :list, id: @direction) && (return false)
    else
      flash_errors_for(_('Destination_was_not_successfully_created'), @dest)
      redirect_to(action: :new, id: @direction, dest_prefix: params[:destination][:prefix], dest_name: params[:destination][:name]) && (return false)
    end
  end

  def edit
    @page_title = _('Edit_destination')
    @page_icon = 'edit.png'
    @direction = Direction.all
    @destination_group_list = Destinationgroup.get_destination_groups
  end

  def update
    params[:destination][:destinationgroup_id] = nil if params[:destination] and params[:destination][:destinationgroup_id] and params[:destination][:destinationgroup_id].to_s == 'none'
    params[:destination][:name].to_s.strip! if params[:destination]
    if @destination.update_attributes(params[:destination])
      @direction = @destination.direction
      flash[:status] = _('Destination_was_successfully_updated')
      redirect_to action: 'list', id: @direction
    else
      flash_errors_for(_('Destination_was_not_updated'), @destination)
      #flash[:notice] = _('Such_destination_exists_already')
      redirect_to action: 'edit', id: @destination
    end
  end

  def destroy
    dd_id = @destination.direction.id
    if @destination.destroy
      flash[:status] = _('Destination_was_deleted')
    else
      flash_errors_for(_('Cant_delete_destination'), @destination)
    end
    redirect_back_or_default("/destinations/list/#{dd_id}")
  end

  #========================================= Destinations stats =====================================================

  def stats
    @page_title = _('Destination_stats')
    @page_icon = 'chart_bar.png'
    @destination = Destination.where(id: params[:des_id]).first
    unless @destination
      flash[:notice] = _('Destination_was_not_found')
      redirect_to :root and return false
    end
    change_date

    @html_flag = @direction.code
    @html_name = @direction.name
    @html_prefix_name = _('Prefix') + ' : '
    @html_prefix = @destination.prefix

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph(a1: session_from_date, a2: session_till_date, destination: @destination.prefix, code: @direction.code)

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

      sql = "SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = #{q(@destination.prefix)}) AND (destinations.prefix = calls.prefix) " +
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[index] = res[0]['calls'].to_i
      @a_billsec[index] = res[0]['billsec'].to_i

      @a_avg_billsec[index] = 0
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0

      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]

      sqll = "SELECT COUNT(calls.id) as \'calls2\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = #{q(@destination.prefix)}) AND (destinations.prefix = calls.prefix) " +
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[index] = res2[0]['calls2'].to_i

      @a_ars2[index] = (@a_calls[index].to_d / @a_calls2[index]) * 100 if @a_calls2[index] > 0
      @a_ars[index] = nice_number @a_ars2[index]
      @sdate += (60 * 60 * 24)
      index += 1
    end

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    # Tariff and rate
    @rate, @rate1, @rate2, @rate_details = Rate.separated_rates(@destination.id)

    #===== Graph=====================

    # formating graph for Calls
    @Calls_graph2 = format_graph(@a_date, @a_calls, index)

    # formating graph for Calltime
    @Calltime_graph = format_graph(@a_date, @a_billsec, @a_billsec.size)

    # formating graph for Avg.Calltime
    @Avg_Calltime_graph = format_graph(@a_date, @a_avg_billsec, index)

    # formating graph for Asr calls
    @Asr_graph = format_graph(@a_date, @a_ars, index)
  end

  def get_destinations_json
    return unless request.xhr?
    tariff_id = params[:tariff_id].to_i
    destinations = Destination.joins('LEFT JOIN rates ON destinations.id = rates.destination_id')
                              .where("rates.tariff_id = #{tariff_id}")
                              .all.group(:name).order(:name)
                              .pluck(:name).to_json

    render json: {data: destinations}
  end

  def get_prefixes_json
    return unless request.xhr?
    tariff_id = params[:tariff_id].to_i
    destination_name = params[:dst_name].to_s
    prefixes = Destination.joins('LEFT JOIN rates ON destinations.id = rates.destination_id')
                          .where("rates.tariff_id = #{tariff_id} AND destinations.name LIKE #{ActiveRecord::Base::sanitize(destination_name)}")
                          .all.order(:prefix)
                          .pluck(:prefix).to_json

    render json: {data: prefixes}
  end

  private

  def find_direction
    @direction = Direction.where(id: params[:id]).first
    unless @direction
      flash[:notice] = _('Direction_was_not_found')
      redirect_to :root and return false
    end
  end

  def find_destination
    @destination = Destination.where(id: params[:id]).first
    unless @destination
      flash[:notice] = _('Destination_was_not_found')
      redirect_to :root and return false
    end
  end

  def format_graph(date_collection, data_collection, element_count, options = {})
    index = 0
    graph = ''
    while index <= element_count - 1
      graph += date_collection[ine].to_s + ';' + (options[:to_minutes].to_s == 'false') ? data_collection[ine].to_s : (data_collection[ine] / 60).to_s + '\\n'
      index += 1
    end
  end
end
