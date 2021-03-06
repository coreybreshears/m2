# -*- encoding : utf-8 -*-
module TariffsHelper
  def rate_edit_link(rate_id)
    link_to _('edit').upcase, {action: :rate_details, id: rate_id}, id: "edit-link-#{rate_id}"
  end

  def mark_active_rates(rates)
    skip = 0
    active_effective = nil
    # We need to sort the rates to properly perform marking.
    # Note: works on the same prefix and tariff rates.
    rates.sort_by! { |rate| [rate['effective_from'].to_s] }.reverse!
    current_time = current_user.user_time(Time.new)
    # Mark each rates list entry as active/inactive
    rates.each do |rate|
      effective_from = rate['effective_from']
      is_active = 0
      # Process the newest not newer than today effective from date
      if skip == 0 && effective_from.present? && effective_from <= current_time
        is_active = skip = 1
        active_effective = effective_from
      end
      # If there are any rates with the same effective from as the
      # active one make them active too
      is_active = 1 if effective_from.to_i == active_effective.to_i
      rate['active'] = is_active
    end
  end

  def find_rates(tariff_id)
    Rate.where(tariff_id: tariff_id, destination_id: 0)
  end

  def count_of_rates(rates_count)
    rates_count ? rates_count : 0
  end

  def nice_daytype(rate_detail_daytype)
    rate_detail_daytype.blank? ? '' : (rate_detail_daytype.to_s == 'FD' ? 'Free Day' : 'Work Day')
  end

  def destination_name(name)
    name.blank? ? 'NAME ERROR' : name
  end

  def effective_from_date_formats
    formats = ['%Y-%m-%d', '%Y/%m/%d', '%Y,%m,%d', '%Y.%m.%d', '%d-%m-%Y', '%d/%m/%Y',
               '%d,%m,%Y', '%d.%m.%Y', '%m-%d-%Y', '%m/%d/%Y', '%m,%d,%Y', '%m.%d.%Y']
    formats.map{|format| [format.gsub('%', ''), format]}
  end

  def effective_date_values(rate)
    effective_from = rate.effective_from
    return ['-', ''] if effective_from.blank?
    #[formatted_date_in_user_tz(effective_from), effective_from.in_time_zone(user_tz).strftime('%H:%M:%S')]
    nice_date_time(effective_from).split(' ')
  end

  def guess_effective_from_format(datetime = '')
    date = datetime.to_s.split[0].to_s
    date_separator = ''
    date_values = []

    ['-', '/', ',', '.'].each do |possible_seperator|
      date_values = date.split(possible_seperator)
      if date_values.size == 3
        date_separator = possible_seperator
        break
      end
    end

    return nil if date_separator.blank?
    format = []

    if date_values[0].length == 4
      format[0] = '%Y'
      format[1] = '%m'
      format[2] = '%d'
    else
      format[2] = '%Y'

      if date_values[1].to_i > 12
        format[0] = '%m'
        format[1] = '%d'
      else
        format[0] = '%d'
        format[1] = '%m'
      end
    end

    format.join(date_separator)
  end

  def count_active_rates(tariff_id)
    sql = "SELECT COUNT(*) AS active_count FROM (
            SELECT id
              FROM rates
              WHERE (effective_from < NOW() OR effective_from IS NULL) AND rates.tariff_id = #{tariff_id} GROUP BY destination_id) AS active_rates"

    result = ActiveRecord::Base.connection.select(sql)
    result.first['active_count'].to_i
  end

  def destination_name_by_rate(rate)
    Destination.where(id: rate.destination_id).first.try(:name) if rate.destination_id != 0
  end

  def check_if_rate_blocked(rate)
    rate == -1 ? _('Blocked') : nice_number(rate)
  end

  def effective_date_in_session(import_manual_eff)
    import_manual_eff.present? ? import_manual_eff.to_datetime : nil
  end

  def dpeer_tpoints_tariffs(dial_peer_id)
    tariffs_names = Tariff.select('DISTINCT(tariffs.name) AS name').
        joins('JOIN devices ON devices.tp_tariff_id = tariffs.id ').
        joins("JOIN dpeer_tpoints ON (dpeer_tpoints.dial_peer_id = #{dial_peer_id} AND dpeer_tpoints.device_id = devices.id)").
        order(:name).map(&:name)

    tariffs_names.join('<br/>').html_safe
  end

  def options_for_cheapest_rate
    tariff = params[:tariff]
    tariff_cheapest_rate = tariff[:cheapest_rate]
    options_for_select([['1st', 0], ['2nd', 1], ['3rd', 2], ['4th', 3], ['5th', 4]],
                       (!tariff.blank? && !tariff_cheapest_rate.blank?) ? tariff_cheapest_rate : 1)
  end

  def rate_check_extremas(dest)
    dest_row_values = dest.values[2..-1].compact.select { |cell| cell.is_a?(Numeric) && cell >= 0 }
    min_value = dest_row_values.min
    max_value = dest_row_values.max
    max_value = -9999 if min_value == max_value
    {max: max_value, min: min_value}
  end

  def rate_check_cell_value(rate)
    if rate
      if rate < 0
        "<span class=\"grey_text\">#{_('Blocked')}</span>".html_safe
      else
        "<span class=\"grey_text\">#{nice_number(rate)}</span>".html_safe
      end
    else
      '-'
    end
  end

  def csv_import2_completed(user, tariff)
    unless @tariff_analize[:last_step_flag]
      # To prevent additional Action from creating after page refresh
      Action.add_action_hash(
          user,
          {
              action: 'tariff_csv_import_completed', target_id: tariff.id, target_type: 'tariff',
              data: "Name: #{tariff.name}"
          }
      )
    end
    @tariff_analize[:last_step_flag] = true
  end

  def manage_rates_blocked_options
    [[_('Do_not_change_Block_status'), -1], [_('Block'), 1], [_('Unblock'), 0]]
  end
end
