# -*- encoding : utf-8 -*-
# Active Calls Model
class Activecall < ActiveRecord::Base
  attr_accessible :id, :server_id, :uniqueid, :start_time, :answer_time, :transfer_time, :src,
    :dst, :src_device_id, :dst_device_id, :channel, :dstchannel, :prefix, :provider_id,
    :user_id, :owner_id, :user_rate, :lega_codec, :legb_codec, :pdd, :destination_name, :direction_code

  belongs_to :user
  belongs_to :server
  belongs_to :origination_point, class_name: 'Device', foreign_key: 'src_device_id'
  belongs_to :termination_point, class_name: 'Device', foreign_key: 'dst_device_id'

  def src_device
    Device.where(id: self.src_device_id).first
  end

  def dst_device
    Device.where(id: self.dst_device_id).first
  end

  def destination
    Destination.where(prefix: self.prefix).first
  end

  def duration
    answer_time ? Time.now.getlocal - Time.parse(answer_time.to_s) : ''
  end

  def get_user_rate#(user = nil, destination = nil)
#    user = self.user unless user
#    destination = self.destination unless destination
#
#    user_rate = nil
#    user_rate = self.user_rate
#    unless user_rate and destination
#      rate = Rate.find(:first, include: [:ratedetails], conditions: ["rates.tariff_id = ? AND rates.destination_id = ?", user.tariff_id, destination.id]).ratedetails[0]
#      user_rate = rate.rate.to_d
#    end
    user_rate = self.user_rate ? self.user_rate.to_d : 0.to_d
    User.current.get_rate(user_rate)
  end

  def Activecall.count_for_user#(user)
    # hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    # hide_active_calls_longer_than = 24 if hide_active_calls_longer_than.zero?
    # if user and user.id and user.usertype
    #   if user.usertype == "admin"
    #     return Activecall.where("(DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW())").count
    #   else
    #     if user.usertype == "reseller"
    #       #reseller
    #       user_sql = " WHERE (activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id} OR  activecalls.owner_id = #{user.id} OR dst_usr.owner_id =  #{user.id}) AND (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
    #     else
    #       #user
    #       user_sql = " WHERE (activecalls.user_id = #{user.id} OR dst_usr.id = #{user.id}) AND (DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) "
    #     end
    #     sql = "
    #     SELECT COUNT(*)
    #     FROM activecalls
    #     LEFT JOIN devices AS dst ON (dst.id = activecalls.dst_device_id)
    #     LEFT JOIN users AS dst_usr ON (dst_usr.id = dst.user_id)
    #     #{user_sql}"
    #     return ActiveRecord::Base.connection.select_value(sql)
    #   end
    # end
    Confline.active_calls
  end

  def Activecall.count_calls(hide_active_calls_longer_than, show_answered = false, current_user = nil)
    only_answered = show_answered ? 'AND (activecalls.answer_time IS NOT NULL)' : ''
    if current_user.try(:show_only_assigned_users?)
      manager = {user_id: User.where(responsible_accountant_id: current_user.try(:id)).pluck(:id)}
    end
    Activecall.where("(DATE_ADD(activecalls.start_time, INTERVAL #{hide_active_calls_longer_than} HOUR) > NOW()) AND active = 1 #{only_answered}").where(manager).to_a.size.to_s
  end

  def update_by_destination
    if prefix.present?
      destination = @@destinations_cache[prefix.try(:to_sym)]
      unless destination.present?
        destination = Application.find_closest_destinations(prefix).try(:select, 'destinations.name, destinations.direction_code, destinations.name AS destination_name').try(:first)
        @@destinations_cache[prefix.to_sym] = destination
      end
      self.destination_name = destination.try(:name).to_s
      self.direction_code = destination.try(:direction_code).to_s
    end
  end

  def self.update_calls_by_destinations(calls)
    @@destinations_cache = {}
    calls.each{ |active_call| active_call.update_by_destination }
    @@destinations_cache = {}
  end

  def self.hangup_calls(active_calls)
    servers = {}
    active_calls.each do |active_call|
      uniqueid = active_call.uniqueid
      server_id = active_call.server_id.to_i

      b2bua_servers = Server.where(b2bua: 1).all

      if b2bua_servers.present?
        src_dst = Activecall.select(:src, :dst).where(uniqueid: uniqueid).first
        next if src_dst.blank?
        b2bua_servers.each { |server| server.hangup_sems(src_dst.src, src_dst.dst, uniqueid) }
      end

      if server_id > 0 && b2bua_servers.blank?
        servers[server_id] ||= (Server.find_by(id: server_id, server_type: :freeswitch) || :none)
        if servers[server_id].is_a?(Server)
          servers[server_id].hangup_call(uniqueid)
          MorLog.my_debug("Hangup on server: #{server_id}")
        end
      end
    end
  end
end
