# Blocked Servers' IP
class BlockedIP < ActiveRecord::Base
  include UniversalHelpers

  attr_protected

  def validate_ip_for_blocking
    # IP correct
    return (errors.add(:blocked_ip, _('IP_is_incorrect_or_blank')) && false) if blocked_ip.blank? || blocked_ip.gsub(/(^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:[.](?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$)/, '').to_s.length > 0

    # IP unique per Server
    return (errors.add(:blocked_ip, _('IP_is_already_blocked_for_this_Server')) && false) if BlockedIP.where(blocked_ip: blocked_ip, server_id: server_id).present?

    # IP not used in any server
    return (errors.add(:blocked_ip, _('Server_IP_cannot_be_blocked')) && false) if Server.pluck(:server_ip).include?(blocked_ip)

    # IP not Private (RFC1918)
    return (errors.add(:blocked_ip, _('IP_address_is_private')) && false) if /^(?:10|127|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\..*/.match(blocked_ip)

    # IP not local
    return (errors.add(:blocked_ip, _('IP_address_is_local')) && false) if `/sbin/ifconfig -a`.include?(blocked_ip) || `/sbin/ip addr show`.include?(blocked_ip)
    true
  end

  def self.monitorings_blocked_ips(options = {})
    s_blocked_ip = if options[:s_blocked_ip].to_s.strip.present?
                     options[:s_blocked_ip].to_s.strip
                   else
                     '%'
                   end

    non_duplicate_ids = ActiveRecord::Base.connection.select_values(
        "SELECT id FROM (SELECT id, blocked_ip, server_id FROM blocked_ips WHERE blocked_ip LIKE #{ActiveRecord::Base::sanitize(s_blocked_ip)} ORDER BY unblock ASC) AS x GROUP BY blocked_ip, server_id"
    )

    result = select("
	      blocked_ips.id AS id, blocked_ip, blocked_ips.server_id, unblock,
	      CONCAT('ID: ', blocked_ips.server_id, ', IP: ', servers.server_ip) AS server, chain AS reason,
        iplocations.country AS country
	    ")
    .joins('LEFT JOIN servers ON servers.id = blocked_ips.server_id')
    .joins('LEFT JOIN iplocations ON iplocations.ip = blocked_ips.blocked_ip')
    .where(id: non_duplicate_ids).where("blocked_ip LIKE #{ActiveRecord::Base::sanitize(s_blocked_ip)}")
    .order('server ASC, blocked_ip ASC')

    if options[:fpage].present? && options[:items_limit].present?
      result = result.offset(options[:fpage]).limit(options[:items_limit])
    end

    result
  end

  def self.check_if_blocked(ip = '')
    joins('LEFT JOIN servers ON servers.id = blocked_ips.server_id').where(blocked_ip: ip.to_s, unblock: 0).present?
  end

  # Creates (if IP is not present) OR Updates (if lat/long == 0 && country is nil)
  #   IPLocation table with Geo location data for BlockedIps use
  def self.iplocation_countries_update
    monitorings_blocked_ips.where('country IS NULL').each { |blocked_ip| blocked_ip.country }
  end

  def country
    Iplocation.get_location(blocked_ip).try(:country).to_s
  end

  def direction_code(from_country = country)
    Direction.where(name: adjust_country_name(from_country)).first.try(:code).to_s
  end

  def unblock_me
    update_column(:unblock, 1)
  end
end
