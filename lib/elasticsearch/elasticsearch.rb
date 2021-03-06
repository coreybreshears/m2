# -*- encoding : utf-8 -*-
module Elasticsearch

  require 'net/http'
  require 'uri'
  require 'json'

  def self.search_m2_calls(body = {})
    es_ip = Confline.get_value('ES_IP')
    es_ip = 'localhost' if es_ip.blank?

    uri = URI.parse("http://#{es_ip}:9200/m2/calls/_search?search_type=count&query_cache=true")
    header = {'Content-Type' => 'text/json'}
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 3
    http.open_timeout = 3
    request = Net::HTTP::Post.new(uri.request_uri, header)
    request.body = body.to_json
    response = JSON.parse(http.request(request).body)

    elastic_debug(body, response) if Socket.gethostname.to_s.include?('ocean')

    response
  end

  # All possible ES errors/malfunctions must be escaped here.
  #  if something went wrong, false must be returned.
  #  this method call must always be checked for false return.
  def self.safe_search_m2_calls(body = {})
    begin
      response = self.search_m2_calls(body)
    rescue
      return false
    end

    if response.try(:[], 'error').present?
      return false
    end

    response
  end

  def self.safe_search_m2_calls_with_debug(body = {})
    MorLog.my_debug('Elasticsearch check - start', true)
    begin
      response = self.search_m2_calls(body)
    rescue => exception
      MorLog.my_debug("ES error: #{exception.message}", true)
      MorLog.my_debug('Elasticsearch check - end', true)
      return false
    end

    if response.try(:[], 'error').present?
      MorLog.my_debug("ES error: #{response.try(:[], 'error')}", true)
      MorLog.my_debug('Elasticsearch check - end', true)
      return false
    end
    MorLog.my_debug("Elasticsearch response: #{response}", true)
    MorLog.my_debug('Elasticsearch check - end', true)
    response
  end

  def self.resync
    time = Time.now + 1.day - 1.second
    return if User.where(["billing_run_at < ? AND billing_period IN ('bimonthly','quarterly','halfyearly','dynamic') AND generate_invoice_manually = 0", time.to_s(:db)]).count > 0
    Confline.set_value('dg_group_was_changed_today', 0)
    Server.execute_command_on_remote_server(server_credentials)
  end

  private

  def self.elastic_debug(request, response)
    time_now = Time.now
    MorLog.my_debug('++++++++++++++++++++++++++++++++++++++++++++++++++++++')
    MorLog.my_debug("Time now: #{time_now.strftime('%F %H:%M:%S.%L')}")
    MorLog.my_debug('ElasticSearch Query:')
    MorLog.my_debug(JSON.pretty_generate(request))
    MorLog.my_debug("\nResponse:")
    MorLog.my_debug(JSON.pretty_generate(response))
    MorLog.my_debug("\nQuery began at: #{time_now.strftime('%H:%M:%S.%L')}")
    MorLog.my_debug("Time now: #{Time.now.strftime('%H:%M:%S.%L')}")
    MorLog.my_debug("Difference: #{Time.now - time_now}")
    MorLog.my_debug("-----------------------------------------------------\n")
  end

  def self.server_credentials
    {
      command: 'elasticsearch resync',
      server_ip: Confline.get_value('ES_IP').presence || 'local',
      ssh_username: Confline.get_value('ES_username').presence || 'root',
      ssh_port: Confline.get_value('ES_port').presence || 22
    }
  end
end
