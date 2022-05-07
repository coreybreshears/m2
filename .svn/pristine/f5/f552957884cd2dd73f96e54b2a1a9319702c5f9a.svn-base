# -*- encoding : utf-8 -*-
# Automatic CDR export allows to create periodic CDR Export tasks that will be executed manually on configured time
#   with specific query parameters.
# Exported data will be archived and sent via Email to User or specific Email address.
class AutomaticCdrExport < ActiveRecord::Base
  include UniversalHelpers

  attr_protected
  belongs_to :user
  belongs_to :cdr_export_template, foreign_key: :template_id, primary_key: :id

  before_validation :remove_whitespaces

  validate :validate_query_settings

  before_save :update_next_run_at, :update_cdr_sql

  def self.build_new(user)
    time_now = Time.now
    time_at_end_of_day = time_now.at_end_of_day
    new(
        user_id: user.id, period: 'daily', timezone: user.time_zone,
        s_from: time_now.at_beginning_of_day, s_till: time_at_end_of_day,
        cdr_export_at_time: '00:00:00', cdr_export_at_datetime: time_at_end_of_day
    )
  end

  def update_from_params(params = {})
    assign_attributes(params[:automatic_cdr_export].merge({s_user: params[:s_user], s_user_id: params[:s_user_id]}))

    s_origination_point = params[:automatic_cdr_export_s_origination_point].to_s
    self.s_origination_point = s_origination_point if s_origination_point.present?

    if params[:send_cdr_to].to_i == 0
      s_username_id = params[:s_username_id].to_i
      self.send_to_user_id = s_username_id < 0 ? -2 : s_username_id
      self.send_to_email = ''
    else
      self.send_to_user_id = -1
    end

    time_now = Time.now
    time_at_end_of_day = time_now.at_end_of_day

    self.s_from = time_now.at_beginning_of_day
    self.s_till = time_at_end_of_day
    self.cdr_export_at_time = '00:00:00'
    self.cdr_export_at_datetime = time_at_end_of_day

    case self.period
      when 'only_once'
        self.s_from = Time.parse("#{params[:date_from]} #{params[:time_from]}:00")
        self.s_till = Time.parse("#{params[:date_till]} #{params[:time_till]}:59")
        self.cdr_export_at_datetime = Time.parse("#{params[:cdr_export_at_datetime1]} #{params[:cdr_export_at_datetime2]}:00")
        self.last_run_at = nil
      else
        self.cdr_export_at_time = "#{params[:cdr_export_at_time]}:00"
    end
  end

  def change_active_status
    update_attribute(:active, active == 0 ? 1 : 0)
    active
  end

  def search_options_origination_points
    user = User.where(id: s_user_id).first if s_user_id.to_i != -2
    user.present? ? user.devices.origination_points_sort_nice_device : []
  end

  def send_to
    (send_to_user_id.to_i == -1 ? send_to_email : nice_user(User.where(id: send_to_user_id).first)).to_s
  end

  def send_to_user_email
    User.where(id: send_to_user_id).first.try(:email).to_s
  end

  def nice_period
    periods = {
        'hourly' => _('Hourly'), 'daily' => _('Daily'), 'weekly' => _('Weekly'), 'bi-weekly' => _('bi_weekly'),
        'monthly' => _('Monthly'), 'only_once' => _('Only_once')
    }
    periods[period.to_s]
  end

  def template_name
    cdr_export_template.try(:name).to_s
  end

  def validate_query_settings
    if period == 'only_once'
      errors.add(:from_is_greater_than_till, _('Till_must_be_greater_than_From')) if s_from > s_till
      errors.add(:cdr_export_at_datetime_in_past, _('Start_CDR_Export_at_must_be_in_future')) if cdr_export_at_datetime < Time.now
    end

    errors.add(:name_must_be_present, _('Name_cannot_be_blank')) if name.blank?

    errors.add(:template_not_selected, _('Template_must_be_selected')) if template_id.to_i <= 0

    if send_to_user_id.to_i == -1
      errors.add(:send_to_email_invalid_format, _('Send_CDR_to_Email_invalid_format')) unless send_to_email.match(/^[a-zA-Z0-9_\+-]+(\.[a-zA-Z0-9_\+-]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.([a-zA-Z0-9_]{2,63})$/)
    else
      errors.add(:send_to_user_not_selected, _('Send_CDR_to_User_must_be_selected')) if send_to_user_id.to_i < 0
    end
  end

  def update_next_run_at
    time_now = Time.now.in_time_zone(timezone)
    hour = cdr_export_at_time.hour
    min = cdr_export_at_time.min
    case period
      when 'hourly'
        self.next_run_at = (time_now.at_beginning_of_hour + 1.hour).strftime('%Y-%m-%d %H:%M:%S')

        self.s_from = next_run_at - 1.hour
      when 'daily'
        self.next_run_at = (time_now.at_beginning_of_day.change(hour: hour, min: min) + 1.day).
            strftime('%Y-%m-%d %H:%M:%S')

        self.s_from = next_run_at - 1.day
      when 'weekly'
        self.next_run_at = (time_now.at_beginning_of_week.change(hour: hour, min: min) + 1.week).
            strftime('%Y-%m-%d %H:%M:%S')

        self.s_from = next_run_at - 1.week
      when 'bi-weekly'
        if time_now.day < 16
          self.next_run_at = (time_now.at_beginning_of_month.change(hour: hour, min: min) + 15.days).
              strftime('%Y-%m-%d %H:%M:%S')

          self.s_from = next_run_at.at_beginning_of_month
        else
          self.next_run_at = (time_now.at_end_of_month.change(hour: hour, min: min) + 1.day).
              strftime('%Y-%m-%d %H:%M:%S')

          self.s_from = (next_run_at - 1.day).change(day: 16)
        end
      when 'monthly'
        self.next_run_at = (time_now.at_beginning_of_month.change(hour: hour, min: min) + 1.month).
            strftime('%Y-%m-%d %H:%M:%S')

        self.s_from = next_run_at - 1.month
      when 'only_once'
        self.next_run_at = cdr_export_at_datetime.strftime('%Y-%m-%d %H:%M:%S')
    end

    self.s_till = next_run_at - 1.second unless period == 'only_once'
  end

  def update_cdr_sql
    time_now = Time.now
    o_s_destination = (s_destination.match(/\A[0-9%]+\Z/) ? s_destination : '')

    options = {
        s_call_type: s_call_type,
        s_origination_point: s_origination_point,
        s_termination_point: s_termination_point,
        s_hgc: s_hgc,
        s_user: s_user,
        s_user_id: s_user_id,
        s_destination: o_s_destination,
        s_country: '',
        s_source: s_source,
        show_device_and_cid: Confline.get_value('Show_device_and_cid_in_last_calls', user_id),
        from: s_from.to_s[0..18],
        till: s_till.to_s[0..18],
        order_by_full: 'time DESC',
        order: 'calls.calldate DESC',
        direction: 'outgoing',
        call_type: s_call_type,
        destination: o_s_destination,
        exchange_rate: Currency.count_exchange_rate(Currency.where(id: 1).first, user.currency.try(:name)).to_d,
        source: s_source,
        current_user: user,
        show_full_src: Confline.get_value('Show_Full_Src'),
        csv: true,
        cdr_template_id: template_id,
        automatic_cdr_export: true,
        seconds_interval: (time_now.in_time_zone(timezone).utc_offset.second - time_now.utc_offset.second).to_i
    }

    options[:collumn_separator], options[:column_dem] = user.csv_params

    options[:user] = User.where(id: s_user_id).first if s_user_id.present? && (s_user_id.to_i != -2)
    options[:origination_point] = Device.where(id: s_origination_point).first if s_origination_point.present? && s_origination_point != 'all'
    options[:hgc] = Hangupcausecode.where(id: s_hgc).first if s_hgc.to_i > 0
    options[:termination_point] = Device.where(id: s_termination_point).first if s_termination_point.present? && s_termination_point != 'all'
    options[:destination_group_id] = s_destination_group.to_i if s_destination_group.to_i > 0

    [:user, :origination_point, :hgc, :termination_point, :destination_group_id].each do |key|
      options.delete(key) unless options[key]
    end

    self.cdr_sql = Call.last_calls_csv(options)
  end

  private

  def remove_whitespaces
    [:name, :s_source, :s_destination, :send_to_email].each { |value| self[value].to_s.strip! }
  end
end
