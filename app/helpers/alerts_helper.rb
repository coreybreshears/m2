# Alerts Helper
module AlertsHelper
  def alerts_new_contact_timezone(cache = {})
    cache.try(:[], :timezone).blank? ? Time.zone.formatted_offset : cache[:timezone]
  end

  def alerts_edit_selected_timezone(offset = nil)
    return unless offset
    offset = offset.to_s
    offset_size = offset.size
    return "#{offset.insert(1, ((offset_size < 3) ? '0' : ''))}:00" if offset.include?('-')
    "+#{offset.insert(0, ((offset_size < 2) ? '0' : ''))}:00"
  end

  def nice_alert_timezone(offset = nil)
    return unless offset
    offset = offset.to_s.insert(0, ((offset.to_s.size < 2) ? '0' : ''))
    _('gmt') + offset.insert(0, ((offset.to_i >= 1) ? ' +' : ' ')) + ':00'
  end

  def periods_order
    "CASE day_type WHEN 'all days' THEN 1 WHEN 'monday' THEN 2 WHEN 'tuesday' THEN 3 WHEN 'wednesday' THEN 4 " \
    "WHEN 'thursday' THEN 5 WHEN 'friday' THEN 6 WHEN 'saturday' THEN 7 WHEN 'sunday' THEN 8 END"
  end

  def fetch_periods(periods = [], local = false)
    buffer = ''
    if periods.any?
      periods.each do |period|
        buffer << "#{_(period.day_type.gsub(' ', '_').capitalize)} #{period.start.strftime('%H:%M')} - #{period.end.strftime('%H:%M')}#{(local ? '' : '<br />')}"
      end
    end
    buffer.html_safe
  end

  def nice_schedule_period(period, blank = false, day_type = nil)
    buffer = ''
    buffer << (
      "<div id=\"periods_#{period.id}_#{period.day_type}\" style=\"width: 230px;\">".html_safe +
      (day_type ? hidden_field_tag("periods[#{period.id}][day_type]", period.day_type) : '') +
      select_hour(period.start.try(:hour), prefix: "periods[#{period.id}][start]", include_blank: blank) +
      ' : ' +
      select_minute(period.start.try(:min), prefix: "periods[#{period.id}][start]", include_blank: blank) +
      ' - ' +
      select_hour(period.end.try(:hour), prefix: "periods[#{period.id}][end]", include_blank: blank) +
      ' : ' +
      select_minute(period.end.try(:min), prefix: "periods[#{period.id}][end]", include_blank: blank) +
      link_to(b_delete, 'javascript:void(0)', onclick: "drop_period(#{period.id}, '#{period.day_type}');") +
      '</div>'.html_safe
    )
    buffer
  end

  def generate_parameters(alert_type, alert_type_parameters)
    raw (select_tag('alert[alert_type]', options_for_select(alert_type_parameters.map { |a_type| [_(a_type.upcase), a_type] }, alert_type), id: 'alert_type_parameters').squish)
  end

  def generate_check_data(alert)
    alert_check_data = alert.check_data
    alert_check_type = alert.check_type

    if alert_check_data == 'all'
      _('All')
    elsif alert_check_type == 'user'
      if is_numeric?(alert_check_data)
        user = User.where(id: alert_check_data.to_i).first
        link_nice_user(user).to_s.html_safe
      else
        alert_check_data
      end
    elsif %w[origination_point termination_point].include?(alert_check_type)
      dev = Device.where(id: alert_check_data.to_i).first
      link_nice_device(dev).to_s.html_safe if dev
    elsif alert_check_type == 'destination'
      alert_check_data.to_s
    elsif alert_check_type == 'destination_group'
      dg = Destinationgroup.select('id, name as gname').where(id: alert_check_data.to_i).order('name ASC').first
      link_to(dg.gname, controller: :destination_groups, action: :edit, id: dg.id) if dg
    end
  end

  def count_group_contacts(group_id)
    AlertContactGroup.where(alert_group_id: group_id).size
  end

  def nice_group_schedule(schedule)
    schedule.blank? ? _('no_schedule_selected') : schedule.name
  end

  def reject_with_circles(alerts)
    alerts.reject do |alert|
      dependency = AlertDependency.new(owner_alert_id: session[:current_alert_id], alert_id: alert.id)
      AlertDependency.cycle_exists?(dependency)
    end
  end

  def destination_group_name(id)
    return 'All' if id == 'all'
    Destinationgroup.select(:name).where(id: id).first.name
  end

  def cp_routing_group(device_id)
    device = Device.select(:op_routing_group_id).where(id: device_id).first
    RoutingGroup.select(:id, :name).where(id: device.op_routing_group_id).first
  end

  def cp_rg_dial_peers(r_group)
    dps = r_group.rgroup_dpeers.pluck(:id)
    DialPeer.select(:id, :name).where(id: dps).all
  end

  def cp_rg_dial_peer(dial_peer_id)
    DialPeer.select(:name).where(id: dial_peer_id).first.try(:name)
  end

  def hide_dp_in_rg?(alert)
    %w[origination_point].exclude?(alert.check_type.to_s) || (alert.check_type.to_s == 'origination_point' && alert.check_data == 'all')
  end
end
