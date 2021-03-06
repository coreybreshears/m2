# Getting location by IP
# (Future reference)
#   * WhatIsMyIPAddress.com is not supported for such use and also conflicts with their terms & agreements.
#     It drops any suspicious connection, by responding with "It may be a script..." or just returns blank page.
#     Also it has access/request over time restrictions, so it is useless to even make a workaround.
class Iplocation < ActiveRecord::Base
  require 'net/http'
  require 'uri'
  require 'open-uri'

  attr_protected

  validates_presence_of :latitude, :longitude, :ip

  def self.check_ip(ip)
    ip_splitted = ip.try(:split, '.')
    if ip_splitted.try(:size) == 4
      ip_splitted.each do |digit|
        next if digit =~ /^[0-9]+$/ && digit.to_i.between?(0, 255)
        return false
      end
      return ip_splitted[3].to_i.between?(0, 254) ? true : false
    else
      false
    end
  end

  def self.admin_ip_find_or_create(ip)
    where("ip = ? AND uniquehash != ''", ip).first || create(ip: ip, created_at: Time.now, uniquehash: ApplicationController::random_password(30))
  end

  def self.get_location(ip, prefix = nil)
    loc = where(ip: ip).first
    return loc if loc && loc.latitude != 0 && loc.longitude != 0

    loc = new unless loc

    if ip.to_s == ''
      loc.latitude = 0
      loc.longitude = 0
      return loc
    end

    if prefix
      dst = Destination.where(prefix: ip).first
      loc = get_location_from_google_geo(dst.name.to_s, dst.direction.try(:name).to_s, loc, ip) if dst
    else
      loc.latitude = 0
      loc.longitude = 0
      loc = Iplocation.get_location_from_ip_address(ip, loc)
    end

    loc.save
    loc
  end

  def self.get_location_from_ip_address(ip, loc)
    if check_ip(ip)
      loc.ip = ip
      begin
        res = Nokogiri::HTML(open("https://www.ip-adress.com/ip-address/ipv4/#{ip}", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE))

        if res.present?
          cou = res.at("th:contains('Country')").parent.at('td').text
          cit = res.at("th:contains('City')").parent.at('td').text
          lat = res.at("th:contains('Latitude')").parent.at('td').text
          lon = res.at("th:contains('Longitude')").parent.at('td').text

          loc.country = cou.to_s.strip.titlecase if cou
          loc.city = cit.strip.titlecase if cit
          loc.longitude = lon.strip.to_d if lon
          loc.latitude = lat.strip.to_d if lat
        else
          self.reset_location(loc)
        end
      rescue => exc
        MorLog.my_debug("IpLocation error: #{exc.message}")
        self.reset_location(loc)
      end
    end
    loc
  end

  def self.get_location_from_google_geo(dst, dir, loc, prefix)
    return loc if dst == '' && dir == ''

    begin
      res = JSON.parse(
          Net::HTTP.get_response(
              URI.parse(
                  URI.escape("http://maps.googleapis.com/maps/api/geocode/json?address=#{dir}&output=csv&sensor=false")
              )
          ).body
      )['results'].first['geometry']['location']

      if res
        loc.ip = prefix
        loc.latitude = res['lat'].to_d
        loc.longitude = res['lng'].to_d
        loc.city = ''
        loc.country = dir.lstrip
      end

    rescue => exc
      MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
      loc.ip = prefix
      self.reset_location(loc)
    end
    loc
  end

  def approve
    update_attribute(:approved, 1)
  end

  def block_ip
    Server.all.each do |server|
      BlockedIP.create(blocked_ip: ip, server_id: server.id, chain: 'Unauthorized Admin IP', unblock: 2)
    end
  end

  def direction_code(from_country = country)
    Direction.where(name: from_country).first.try(:code).to_s
  end

  def admin_ip_send_email_authorization
    url = "#{Web_URL}/#{Web_Dir}/callc/admin_ip_access?id=#{uniquehash}"
    body = "Unauthorized IP: #{ip} tried to login as Admin to your system #{Web_URL}.<br/><br/>"
    body << "If you want to authorize this IP press this link: <a href=\"#{url}\">#{url}</a><br/><br/>"
    body << "If you want to block this IP press this link: <a href=\"#{url}&block_ip=1\">#{url}&block_ip=1</a>"

    admin_email_to = User.find(0).try(:email).to_s

    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1 && admin_email_to.present?
      smtp_server = Confline.get_value('Email_Smtp_Server', 0).to_s.strip
      smtp_user = Confline.get_value('Email_Login', 0).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', 0).to_s.strip
      smtp_port = Confline.get_value('Email_Port', 0).to_s.strip

      from = Confline.get_value('Email_from', 0).to_s
      begin
        system_call = ApplicationController::send_email_dry(from, admin_email_to, body, 'Admin IP authorization request', '', "'#{smtp_server.to_s}:#{smtp_port.to_s}' -xu '#{smtp_user.to_s}' -xp $'#{smtp_pass.to_s.gsub("'", "\\\\'")}'", 'html')

        if defined?(NO_EMAIL) && NO_EMAIL.to_i == 1
          # do nothing
        else
          system(system_call)
        end
      rescue
      end
    end
  end

  private

  def self.reset_location(loc)
    loc.country = ''
    loc.city = ''
    loc.latitude = 0
    loc.longitude = 0
  end
end
