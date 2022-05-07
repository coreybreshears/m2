# Helper for Dial Peers
module DialPeersHelper
  def termination_point_name(termination_point, options = {})
    device = Device.where(id: termination_point.device_id).first
    user = User.where(id: device.user_id).first
    device_name = nice_device(device, options)
    user_name = nice_user(user)

    if options[:link]
      return link_to(user_name.html_safe, controller: :users, action: :edit, id: user.try(:id).to_i) +
          ' / ' + link_to(device_name.html_safe, controller: :devices, action: :device_edit, id: device.try(:id).to_i)
    end
    raw(device_name + ' ' + user_name)
  end

  def default_margin_value(dial_peer, session, message = '')
    margin_value = ''
    if session[message.to_sym].blank?
      if dial_peer.respond_to?(message)
        value = dial_peer.send(message.to_s)
        margin_value = nice_number(value) if value.present?
      end
    else
      margin_value = session[message.to_sym].to_s
    end
  end

  def routing_groups_list(dial_peer_id)
    rg_ids = RgroupDpeer.where(dial_peer_id: dial_peer_id)
                        .all
                        .pluck(:routing_group_id)
    RoutingGroup.where(id: rg_ids).all.pluck(:name)
  end

  def rg_tooltip_text(routing_groups)
    text = routing_groups.take(15).join('</br>')
    text += '</br>...' if routing_groups.length > 15
    text
  end
end
