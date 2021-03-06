# -*- encoding : utf-8 -*-
# Stats view helper
module StatsHelper
  def show_call_dst(call, text_class)
    dest = Destination.where('prefix = ?', call.prefix).first
    dest_txt = []
    if dest
      @direction_cache ||= {}
      direction = @direction_cache[dest.direction_code.to_s] ||= dest.direction
      dest_txt << "#{direction.name.to_s + ' ' if direction } #{dest.name}"
    end
    dest_txt << _('incoming_destination') + ': ' + (hide_gui_dst? ? call.dst[0..-4] + 'XXX' : call.dst)
    dest_txt << _('Prefix_used') + ': ' + call.prefix.to_s if call.prefix.to_s.length > 0

    rez = ["<td id='dst_#{call.id}'
                class='#{text_class}'
                align='left'
                onmouseover=\"Tip(\'#{ dest_txt.join('<br>') }\')\"
                onmouseout = \"UnTip()\">"]
    rez << (hide_gui_dst? ? call.localized_dst[0..-4] + 'XXX' : call.localized_dst)
    rez << '</td>'
    rez.join('').html_safe
  end

  def call_duration(call, text_class, call_type, own = false)
    rez = ["<td id='duration_#{call.id}' class='#{text_class}' align='center'>"]
    unless %w[missed missed_inc missed_inc_all].include?(call_type)
      rez << nice_time((own ? call.user_billsec : call.nice_billsec))
    else
      rez << nice_time(call.duration)
    end
    rez << '</td>'
    rez.join.html_safe
  end

  def active_calls_tooltip(call)
    [
        _('Server') + ': ' + call['server_id'].to_s,
        _('UniqueID') + ': ' + call['uniqueid'].to_s,
        _('User_rate') + ': ' + call['user_rate'].to_s + ' ' + current_user.currency.name
    ].reject(&:blank?).join('<br />')
  end

  def active_calls_total_explanation
    "#{_('Total_Active_Calls')} / #{_('Calls_Answered')}"
  end

  def graph_legend(labels = [])
    nice_legend = labels.each_with_index.map do |name, ind|
      "<graph gid='#{ind}'><title>#{_(name)}</title><line_width>2</line_width><fill_alpha>30</fill_alpha><bullet>round</bullet></graph>"
    end
    nice_legend.join.gsub("\n", '')
  end

  def max(name = nil)
    case name
      when 'cpu_loadstats1'
        nil
      else
        120
    end
  end

  def unit(name = nil)
    case name
      when 'cpu_loadstats1'
        nil
      else
        '%'
    end
  end

  def limited_number(reseller)
    users_number = reseller.f_users.to_i
    if users_number > 2 && ((reseller.own_providers == 0 && !reseller_active?) || (reseller.own_providers == 1 && !reseller_pro_active?))
      2
    else
      users_number
    end
  end

  def show_device_and_callerid(call)
    device = Device.where(id: call.src_device_id).first
    if device
      device_user = device.user
      if device_user
        if [device_user.owner_id, device_user.id].member? correct_owner_id
          link_to call.nice_src_device, {controller: :devices, action: :device_edit, id: call.src_device_id}, {id: "device_edit_link_#{call.id}"}
        else
          call.nice_src_device
        end
      end
    end
  end

  def device_with_owner(device)
    user = User.where(id: device.user_id).first
    user = User.where(id: user.owner_id).first unless user.is_reseller?
    nice_device(device) + ' (' + link_nice_user(user) + ')'
  end

  def show_user_billsec?
    (user? && Confline.get_value('Invoice_user_billsec_show', current_user.owner.id).to_i == 1)
  end

  def reseller_pro?
    reseller? && (current_user.own_providers == 1)
  end

  def action_with_type(action)
    target_type, target_id = action['target_type'].to_s, action['target_id'].to_s
    (target_type + ' (' + target_id + ')') if (target_type + target_id).strip.length > 0
  end

  def link_to_calls(value, aggregate_op_user, aggregate_op_user_id)
    link_to value, action: :calls_list, s_user: aggregate_op_user, s_user_id: aggregate_op_user_id
  end

  def link_to_stats(value, aggregate_op_user_id)
    link_to value, action: :user_stats, id: aggregate_op_user_id
  end

  def show_if_not_zero(aggr_object, answered_calls)
    (aggr_object.to_i == 0) && (answered_calls.to_i == 0) ? '' : aggr_object
  end

  def nice_number_if_not_zero(aggr_object, answered_calls, options = {})
    (aggr_object.to_s.try(:sub, /[\,\;]/, '.').to_f == 0) && (answered_calls.to_i == 0) ? '' : (nice_number(aggr_object, options))
  end

  def get_link_to_rate(rate)
    case rate['purpose'].to_s
      when 'provider', 'user_wholesale', 'user_custom'
        "ratedetail_edit/#{rate['ratedetails_id']}"
      else
        ''
    end
  end

  def options_call_type_select(calltype)
    options_for_select(
      [
        [_('All'), 'all'],
        [_('Answered'), 'answered'],
        [_('No_Answer'), 'no answer'],
        [_('Failed'), 'failed'],
        [_('Busy'), 'busy'],
        [_('Cancel'), 'Cancel']
      ],
      calltype)
  end

  def nice_server_from_data(server, options = {})
    nice_serv = h(server.to_s)
    serv_id = options[:server_id].to_i
    nice_serv = link_to(nice_serv, controller: :servers, action: :edit, id: serv_id) if options[:link] && serv_id > 0
    nice_serv
  end

  def action_data2_alerts(data2)
    # Known possible data2 variations having id:
    #   Disable user (id X)
    #   Enable user (id X)
    #   Disable originator (id X)
    #   Enable originator (id X)
    #   Disable terminator (id X)
    #   Enable terminator (id X)
    #   Change routing group for originator (id X), rg id: Y, restore rg id: Z
    #   Enable terminator (id X) in dial peer (id Y)
    #   Disable terminator (id X) in dial peer (id Y)

    data2.gsub!(/user \(id \d+\)/) do |str|
      user = User.where(id: str.split('id ').last[0..-2]).first
      user.present? ? (str.chop << " - #{link_nice_user(user)})") : str
    end

    data2.gsub!(/(originator|terminator) \(id \d+\)/) do |str|
      device = Device.where(id: str.split('id ').last[0..-2]).first
      device.present? ? (str.chop << " - #{link_nice_device(device)})") : str
    end

    data2.gsub!(/dial peer \(id \d+\)/) do |str|
      dial_peer = DialPeer.where(id: str.split('id ').last[0..-2]).first
      dial_peer.present? ? (str.chop << " - #{link_nice_dial_peer(dial_peer)})") : str
    end

    data2.gsub!(/rg id: \d+/) do |str|
      routing_group = RoutingGroup.where(id: str.split('id: ').last[0..-1]).first
      routing_group.present? ? (str << " - #{link_routing_group(routing_group)}") : str
    end

    data2
  end

  def call_status_options
    [[_('All'), ''], [_('Answered'), '1'], [_('Ringing'), '0']]
  end

  def show_status(status)
    status = (status == 0) ? 'ok' : 'failed'
    "<span class=\"check_status_#{status}\">#{status.upcase}</span>".html_safe
  end

  def get_managers(managers)
    return [] unless managers
    managers.map { |manager| [ manager.nice_user, manager.id] }
  end
end
