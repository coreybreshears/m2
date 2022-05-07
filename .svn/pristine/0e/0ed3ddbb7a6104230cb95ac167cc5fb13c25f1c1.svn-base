# -*- encoding : utf-8 -*-
# Blank page for code example.
class BlanksController < ApplicationController
  include UniversalHelpers
  layout :determine_layout

  before_filter :access_denied, if: -> { session[:usertype] != 'admin' }
  before_filter :check_post_method, only: %i[destroy create update]
  before_filter :check_localization

  before_filter :find_blank, only: %i[edit update destroy value3_change_status]
  before_filter :number_separator

  before_filter :change_separator, only: %i[create update]
  before_filter :init_help_link, only: %i[list new create edit update]
  before_filter :strip_params, only: [:list]
  before_filter :change_currency, only: [:list]

  def list
    @page_title = _('Blanks')
    @page_icon = 'details.png'
    @show_currency_selector = true
    @provider_list = Device.visible.where(tp: 1, tp_active: 1)
    @options = initialize_options
    @blanks, @total_pages, @options = nice_list(@options, session[:items_per_page].to_i)
    # CSV Export
    export_to_csv unless params[:csv].to_i.zero?
    Application.change_separators(@options, @nbsp)
    session[:blanks_options] = @options
  end

  def new
    @page_title = _('Blank_new')
    @page_icon = 'add.png'

    # Creating new Blank and getting/updating time for Blank.time
    @blank = Blank.new
    @blank.date = Time.zone.now
  end

  def create
    @page_title = _('Blank_new')
    @page_icon = 'add.png'

    # Creating new Blank by getting params(values) from already filled forms
    blank_options = blank_attributes
    @blank = Blank.new(blank_options)
    unless blank_options
      @blank.errors.add(:base, _('Wrong_date_format'))
      @blank.date = Time.zone.now
    end
    if @blank.errors.empty? && @blank.save
      flash[:status] = _('Blank_successfully_created')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Blank_not_created'), @blank)
      Application.change_separators(params[:blank], @nbsp)
      render :new
    end
  end

  def edit
    @page_title = _('Blank_edit')
    @page_icon = 'edit.png'

    @blank.value2 = nice_input_separator(@blank.value2)
    @blank.balance = nice_input_separator(@blank.balance)
  end

  def update
    @page_title = _('Blank_edit')
    @page_icon = 'edit.png'

    # If update fails this will get params(values) from already edited forms
    # When returning to his page, 'render' method must be used instead of 'redirect_to', (render :action => 'edit')
    if @blank.update_attributes(blank_attributes)
      flash[:status] = _('Blank_successfully_updated')
      redirect_to action: 'list'
    else
      flash_errors_for(_('Blank_not_updated'), @blank)
      Application.change_separators(params[:blank], @nbsp)
      render :edit
    end
  end

  def destroy
    if @blank.destroy
      flash[:status] = _('Blank_deleted')
    else
      dont_be_so_smart
    end
    redirect_to action: 'list'
  end

  # Change 'value3' in 'list'
  def value3_change_status
    @blank.value3, flash[:status] = if @blank.value3.to_s == 'yes'
                                      ['no', _('Value3_disabled')]
                                    else
                                      ['yes', _('Value3_enabled')]
                                    end
    @blank.save
    redirect_to action: 'list'
  end

  private

  # Find and select 'Blank' by 'id'
  def find_blank
    @blank = Blank.where(id: params[:id]).first
    return if @blank
    flash[:notice] = _('Blank_not_found')
    redirect_to(action: list) && (return false)
  end

  def generate_csv(blanks, sep)
    csv_string = "#{_('ID')}#{sep}#{_('Name')}#{sep}#{_('Date')}#{sep}" \
                 "#{_('Description')}#{sep}#{_('Value1')}#{sep}#{_('Value2')}#{sep}#{_('Value3')}#{sep}" \
                 "#{_('Value4')}#{sep}#{_('Value5')}#{sep}#{_('Value6')}\n"
    blanks.each do |blank|
      id, name, date, description, first_value, second_value, third_value, _, fourth_value, fifth_value, sixth_value =
      blank.attributes.values
      device = blank.provider_by_id(sixth_value)
      csv_string += "\"#{id.to_i}\"#{sep}\"#{name}\"#{sep}\"#{date}\"#{sep}\"#{description}\"#{sep}" \
                    "\"#{first_value.to_i}\"#{sep}\"#{nice_number(second_value.to_d)}\"#{sep}\"#{third_value}\"#{sep}" \
                    "\"#{fourth_value}\"#{sep}\"#{fifth_value}\"#{sep}" +
                    if sixth_value.present? && sixth_value >= 0
                      "\"#{nice_user(User.where(id: device.user_id).first)}" \
                      "#{device.description.present? ? ' - ' + device.description : '/' + device.host.to_s }\"\n"
                    else
                      "\"#{device}\"\n"
                    end
    end
    csv_string
  end

  def change_separator
    # Change user's number separator to MOR's
    %i[value2 balance].each do |key|
      params[:blank][key].try(:sub!, /[\,\.\;]/, '.')
    end
  end

  def export_to_csv
    sep, dec = current_user.csv_params
    csv_string = generate_csv(@blanks, sep.first)
    filename = 'Blanks.csv'

    if params[:test].to_i.zero?
      send_data(csv_string, type: 'text/csv; charset=utf-8; header=present', filename: filename)
    else
      render text: csv_string
    end
  end

  def init_help_link
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Main_Page'
  end

  def blank_attributes
    if datetime = to_default_date(params[:date_from] + ' ' + params[:time_from])
      datetimearray = datetime.split(' ')
      params[:date_from] = datetimearray[0]
      params[:time_from] = datetimearray[1]
      params[:date] = {
        year: params[:date_from].split('-')[0],
        month: params[:date_from].split('-')[1],
        day: params[:date_from].split('-')[2],
        hour: params[:time_from].split(':')[0],
        minute: params[:time_from].split(':')[1]
      }
    params[:blank].merge(date: user_time_from_params(*params[:date].values).localtime)
    else
      params[:date] = Blank.params_date
      false
    end
  end

  def nice_list(options, items_per_page)
    fpage, total_pages, options = Application.pages_validator(session, options, Blank.filter(options, session_from_datetime, session_till_datetime).count)

    selection = Blank.filter(options, session_from_datetime, session_till_datetime).order_by(options, items_per_page)
    [selection, total_pages, options]
  end

  def get_time
    time = current_user.user_time(Time.now)
    year = time.year
    month = time.month
    day = time.day
    from = (session_from_datetime_array.map(&:to_i) != [year, month, day, 0, 0, 0])
    till = (session_till_datetime_array.map(&:to_i) != [year, month, day, 23, 59, 59])
    [from, till]
  end

  def show_clear_button(options)
    from, till = get_time
    %i[s_name s_min_value2 s_max_value2 s_value4 s_value5 s_value6].any? { |key| options[key].present? } || from || till
  end

  def clear_options(options)
    change_date_to_present
    %i[s_name s_min_value2 s_max_value2 s_value4 s_value5 s_value6].each do |key|
      options[key] = ''
    end
    options
  end

  def initialize_options
    options = session[:blanks_options] || {}

    adjust_m2_date
    change_date
    param_keys = %w[order_by order_desc search_on page s_name s_min_value2 s_max_value2 s_value4 s_value5 s_value6]
    params.select { |key, _| param_keys.member?(key) }.each do |key, value|
      options[key.to_sym] = value.to_s
    end
    Application.change_separators(options, '.')
    options[:csv] = params[:csv].to_i

    options = clear_options(options) if params[:clear]
    options[:clear] = show_clear_button(options)
    options[:exchange_rate] = change_exchange_rate
    options[:from] = session_from_datetime
    options[:till] = session_till_datetime

    options
  end
end
