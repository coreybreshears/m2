# -*- encoding : utf-8 -*-
# Directions managing and statistics.
class DirectionsController < ApplicationController
  layout :determine_layout

  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_destination, only: [:destination_edit, :destination_update]
  before_filter :find_direction, only: [:edit, :update, :destroy, :stats]
  before_filter :strip_params, only: [:update]

  def list
    @page_title = _('Directions')
    @page_icon = 'details.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Directions_and_Destinations'

    # order
    @options = session[:directions_order_by_options] || {}

    set_options_from_params(@options, params, {
        page: 1,
        order_by: 'name',
        order_desc: 0
    })

    order_by = Direction.directions_order_by(@options)

    store_location

    # page params

    @directions_size = Direction.count

    @fpage, @total_pages, @options = Application.pages_validator(session, @options, @directions_size)

    @page = @options[:page]
    @directions = Direction.order(order_by).limit("#{@fpage}, #{session[:items_per_page].to_i}").all

    respond_to do |format|
      format.html {}
      format.json {
        render json: @directions.map { |dir| [dir.code.to_s, dir.name.to_s] }.to_json
      }
    end

    session[:directions_order_by_options] = @options
  end

  def new
    @page_title = _('Create_new_direction')
    @page_icon = 'add.png'
    @direction = Direction.new
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Directions_and_Destinations'
  end

  def create
    @page_title = _('Create_new_direction')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Directions_and_Destinations'
    params[:direction].values.each {|value| value.to_s.strip! if value}
    @direction = Direction.new(params[:direction])
    @direction.code = @direction.code.to_s.upcase
    if @direction.save
      flash[:status] = _('Direction_was_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Direction_not_updated'), @direction)
      render :new
    end
  end

  def edit
    @page_title = _('Edit_direction') + ': ' + @direction.name
    @page_icon = 'edit.png'
	@help_link = 'http://wiki.ocean-tel.uk/index.php/Directions_and_Destinations'
  end

  def update
    if @direction.update_attributes(params[:direction])
      flash[:status] = _('Direction_was_successfully_updated')
      redirect_to(action: 'list', id: @direction)
    else
      flash_errors_for(_('Direction_not_updated'), @direction)
      render :edit
    end
  end

  def destroy
    name = @direction.name.to_s
    if @direction.destinations.present?
      flash[:notice] = _('Cant_delete_direction_destinations_exist') + ': ' + @direction.name
    else
      @direction.destroy_everything
      flash[:status] = _('Direction') + ": #{name} " + _('successfully_deleted')
    end
    redirect_to(action: 'list') && (return false)
  end

  # ========================================= Directions stats ======================================================

  def stats
    @page_title = _('Directions_stats')
    @page_icon = 'chart_bar.png'

    change_date

    @html_flag = @direction.code
    @html_name = @direction.name
    @html_prefix_name = ''
    @html_prefix = ''

    @calls, @Calls_graph, @answered_calls, @no_answer_calls, @busy_calls, @failed_calls = Direction.get_calls_for_graph({a1: session_from_date, a2: session_till_date, code: @direction.code})

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

      sql = "SELECT COUNT(calls.id) as \'calls\',  SUM(calls.billsec) as \'billsec\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = calls.prefix) " +
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'" +
          "AND disposition = 'ANSWERED'"
      res = ActiveRecord::Base.connection.select_all(sql)
      @a_calls[index] = res[0]['calls'].to_i
      @a_billsec[index] = res[0]['billsec'].to_i

      @a_avg_billsec[index] = 0
      @a_avg_billsec[index] = @a_billsec[index] / @a_calls[index] if @a_calls[index] > 0

      @t_calls += @a_calls[index]
      @t_billsec += @a_billsec[index]

      sqll = "SELECT COUNT(calls.id) as \'calls2\' FROM destinations, directions, calls WHERE (destinations.direction_code = directions.code) AND (directions.code ='#{@direction.code}' ) AND (destinations.prefix = calls.prefix) " +
          "AND calls.calldate BETWEEN '#{@a_date[index]} 00:00:00' AND '#{@a_date[index]} 23:23:59'"
      res2 = ActiveRecord::Base.connection.select_all(sqll)
      @a_calls2[index] = res2[0]['calls2'].to_i

      @a_ars2[index] = (@a_calls[index].to_d / @a_calls2[index]) * 100 if @a_calls[index] > 0
      @a_ars[index] = nice_number @a_ars2[index]

      @sdate += (60 * 60 * 24)
      index += 1
    end

    @t_avg_billsec = @t_billsec / @t_calls if @t_calls > 0

    # ===== Graph =====================

    # formating graph for Calls

    ine = 0
    @Calls_graph2 = ''
    while ine <= index
      -1
      @Calls_graph2 += @a_date[ine].to_s + ';' + @a_calls[ine].to_s + '\\n'
      ine += 1
    end

    # formating graph for Calltime

    i = 0
    @Calltime_graph = ''
    for i in 0..@a_billsec.size - 1
      @Calltime_graph += @a_date[i].to_s + ';' + (@a_billsec[i] / 60).to_s + '\\n'
      ine += 1
    end

    # formating graph for Avg.Calltime

    ine = 0
    @Avg_Calltime_graph = ''
    while ine <= index
      -1
      @Avg_Calltime_graph += @a_date[ine].to_s + ';' + @a_avg_billsec[ine].to_s + '\\n'
      ine += 1
    end

    # formating graph for Asr calls

    ine = 0
    @Asr_graph = ''
    while ine <= index
      -1
      @Asr_graph += @a_date[ine].to_s + ';' + @a_ars[ine].to_s + '\\n'
      ine += 1
    end

  end

  private

  def find_direction
    @direction = Direction.where({id: params[:id]}).first
    unless @direction
      flash[:notice] = _('Direction_was_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def show_clear_button(options)
    [:s_name, :s_description].any? {|key| options[key].present?}
  end

  def clear_options(options)
    [:s_name, :s_description].each do |key|
      options[key] = ''
    end

    options
  end
end
