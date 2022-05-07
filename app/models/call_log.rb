# -*- encoding : utf-8 -*-
# Call log used for Call Tracing functionality
class CallLog < ActiveRecord::Base
  attr_protected

  def self.find_log(uniqueid)
    uncached do
      where(uniqueid: uniqueid).first
    end
  end

  def nice_log(log_type = :call_tracing)
    nice_log = []

    call_log = case log_type
                 when :radius_log
                   radius_log
                 when :freeswitch_log
                   freeswitch_log
                 else
                   log
               end

    call_log.split("\n").each do |log|
      date_index = log.index('[')
      message_index = log.index(']')
      next if date_index.blank? && message_index.blank?
      nice_log << resolve_log(log, date_index, message_index, log_type)
    end

    nice_log
  end

  def self.fill_data_to_file(call_data, path_to_file)
    originator_id = call_data[:device_id].to_s
    device = Device.where(id: originator_id).first
    uniqueid = call_data[:uniqueid]
    original_dst = call_data[:destination]
    clid = call_data[:caller_id]
    originator_ip = call_data[:originator_ip] || device.try(:ipaddr).to_s
    originator_port = device.try(:port) || 5060

    # Handle ip address ranges and subnets pass only single ip from range or subnet
    originator_ip = if originator_ip.include?('-')
                      originator_ip.split('-').first
                    elsif originator_ip.include?('/')
                      IPAddr.new(originator_ip).succ
                    else
                      originator_ip
                    end

    if clid.index('"')
      callerid_name = clid.split('"')[1]
      callerid_number = clid.split('<')[1][0..-2]
    else
      callerid_name = ''
      callerid_number = clid
    end

    File.open(path_to_file, 'w') do |file|
      file.write("h323-remote-address = \"#{originator_ip}\"")
      file.write("\nUser-Name = \"device_id_#{originator_id}\"")
      file.write("\nCisco-AVPair = \"freeswitch-src-port=#{originator_port}\"")
      file.write("\nCisco-AVPair = \"freeswitch-callerid-name=#{callerid_name}\"")
      file.write("\nCalling-Station-Id = \"#{callerid_number}\"")
      file.write("\nCalled-Station-Id = \"#{original_dst}\"")
      file.write("\nCisco-AVPair = \"freeswitch-src-channel=m2_call_trace\"")
      file.write("\ncall-id = \"#{uniqueid}\"")
      file.write("\nAcct-Session-Id = \"#{uniqueid}auth\"")
      file.write("\nService-Type = Authenticate-Only")
      file.write("\nNAS-Port = 0")
      file.write("\nNAS-IP-Address = 127.0.0.1")
    end
  end

  def self.create_new_log(uniqueid)
    # Radius and Freeswitch logs will have prefix 'log_' to uniqueid field
    # This is done to prevent mixing call tracings and call logs
    # Both are inserted to call_log and both have the same uniqueid
    # By separating call log and call tracings we can use same table for both features
    log_uniqueid = "log_#{uniqueid}"

    # Create new record if it does not exist
    create(uniqueid: log_uniqueid) unless where(uniqueid: log_uniqueid).first
  end

  private

  def resolve_log(log, date_index, message_index, log_type)
    ct_date = log[0...date_index]
    ct_type = log[date_index..message_index]
    ct_message = log[message_index + 1..-1]

    ct_type_color = case ct_type.upcase
                      when '[DEBUG]'
                        1
                      when '[ERROR]', '[ERR]', '[WARNING]'
                        2
                      else
                        0
                    end

    # Handle date format for radius log (for example Wed Dec 30 02:04:25 2015)
    ct_date = if (/^[A-Z]/ =~ ct_date) && log_type == :radius_log
                DateTime.strptime(ct_date, '%a %b %e %T %Y').strftime('%Y-%m-%d %T')
              elsif !(/^[A-Z]/ =~ ct_date) && %i[freeswitch_log call_tracing].include?(log_type)
                # Freeswitch date format is 2015-12-31 01:18:24.221908 so we need to cut .221908 part
                ct_date.slice(0, 19)
              else
                ''
              end

    {ct_date: ct_date, ct_type: ct_type, ct_message: ct_message, ct_type_color: ct_type_color}
  end
end
