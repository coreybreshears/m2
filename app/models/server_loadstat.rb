class ServerLoadstat < ActiveRecord::Base
  attr_accessible :id, :server_id, :datetime, :hdd_util, :cpu_general_load, :cpu_mysql_load, :cpu_ruby_load, :cpu_asterisk_load, :cpu_loadstats1

  belongs_to :server

  def csv_line(*arr)
    output = datetime.strftime('%H:%M').to_s
    # self.attributes.has_key? stat.intern
    arr.each { |stat| output << ";#{self[stat.intern]}" if true }
    return output
  end

end
