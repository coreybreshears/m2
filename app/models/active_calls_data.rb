# Active Calls Data model
class ActiveCallsData < ActiveRecord::Base
 attr_accessible :id, :time, :count

 def self.find_by_day(time)
   return unless time.class.eql? ActiveSupport::TimeWithZone
   interval_from = time.beginning_of_day.localtime
   interval_to = time.end_of_day.localtime
   select('time, count').where("time BETWEEN '#{interval_from}' AND '#{interval_to}'").all
 end

 def self.find_from_timestamp(timestamp)
   interval_from = timestamp.localtime
   select('time, count').where("time > '#{interval_from}'").all
 end

 def self.round_seconds(seconds)
   mod = seconds % 15
   mod.zero? ? seconds : seconds - mod
 end

 def self.create_graph_data(timez)
   # Find the data for the current and the previous day
   data_today = find_by_day(Time.zone.now)
   data_yesterday = find_by_day(Time.zone.now - 1.day)
   time = Time.now.midnight
   # Prepare array for graph data, interval - 60 seconds
   graph_array = []
   (24 * 60).times do
     hour = time.strftime('%k').to_i
     minute = time.strftime('%M').to_i
     graph_array.push [[hour, minute, 0], 0, 0]
     time += 60.seconds
   end
   data_yesterday.collect! { |data| [data.time.in_time_zone(timez).strftime('%H:%M'), data.count] }
   data_today.collect! { |data| [data.time.in_time_zone(timez).strftime('%H:%M'), data.count] }
   data_yesterday.each do |data|
     hour, minute, second = data[0].try(:split, ':')
     second = round_seconds(second.to_i)
     graph_array[hour.to_i * 60 + minute.to_i][2] = data[1].to_i
   end
   data_today.each do |data|
     hour, minute, second = data[0].try(:split, ':')
     second = round_seconds(second.to_i)
     graph_array[hour.to_i * 60 + minute.to_i][1] = data[1].to_i
   end
   graph_array
 end
end
