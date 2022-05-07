# Server device model
class ServerDevice < ActiveRecord::Base

  attr_protected

  belongs_to :device
  belongs_to :server

  def self.new_relation(server_id, device_id)
    server_device = new
    server_device.server_id = server_id
    server_device.device_id = device_id
    server_device
  end
end
