# -*- encoding : utf-8 -*-
require 'digest/sha1'

module APIClient
  class Configuration

    # serverio ip/adresas
    attr_accessor :server

    # api adresas serveryje
    attr_accessor :address

    # serverio portas
    attr_accessor :port

    # druska
    attr_accessor :salt

    def initialize
      @server = '192.168.0.30'
      @port = '8080'
      @address = '/mor_api'
      @salt = 'salt'
    end
  end

  # sukuriama nepavykus išsiųsti pranešimo API
  class CommunicationError < StandardError
  end

  class << self
    attr_accessor :configuration
    attr_accessor :link
  end

  # naudinga developmentui, konsolėje, kur neveikia environmento config.after_intialize
  def self.init
    self.configuration = Configuration.new
    configuration = self.configuration
    self.link ||= XMLRPC::Client.new(configuration.server, configuration.address, configuration.port)
  end

  def self.configure
    self.configuration ||= Configuration.new
    configuration = self.configuration
    yield(configuration)
    self.link ||= XMLRPC::Client.new(configuration.server, configuration.address, configuration.port)
  end

  # paymento sukūrimas. perduodamas mokančio vartotojo id ir suma floatu
  def self.payment_create()
    true
  end

  def self.payment_update()
    true
  end

  # tikrina ar api gyvas ir pasiekiamas
  def self.ping
    return true
    # begin
    # return true if self.link.call("ping").eql?("0")
    # return false
    # rescue Timeout::Error, Errno::ECONNREFUSED
    # raise CommunicationError, "An error occured while trying to send message to API backend."
    # end
  end

  # universaus kvietimo metodas. argumentai - hashai

  def self.send(method, *args)
    args.collect! { |argument| argument.to_s } # API priima argumentus kaip stringus
    begin
      return true if self.link.call(method, Digest::SHA1.hexdigest("#{args.join}#{self.configuration.salt}"), *args).eql?('0')
      return false
    rescue Timeout::Error, Errno::ECONNREFUSED
      raise CommunicationError, 'An error occured while trying to send message to API backend.'
    end
  end

end
