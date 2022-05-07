# -*- encoding : utf-8 -*-
class CallDetail < ActiveRecord::Base
  include UniversalHelpers
  attr_protected

  attr_accessible *column_names

  belongs_to :call

  def self.find_calldetail(call_id)
    uncached do
      where(call_id: call_id).first
    end
  end

  def nice_pcap_text
    nice_log = []
    str_pcap_text = hex_to_bytes(pcap_text)
    str_pcap_text.split("\n").each do |text|
      begin
        nice_log << resolve_log(text.strip)
      rescue ArgumentError
        next
      end
    end

    nice_log
  end

  def pcap_data?
    pcap.present? && pcap_text.present? && pcap_graph.present?
  end

  private

  def resolve_log(log)
    pt_number = log.slice!(0...log.index(' '))
    log.strip!
    pt_time = log.slice!(0...log.index(' '))
    log.strip!
    pt_source = log.slice!(0...log.index(' '))
    log.strip!
    log.slice!(0..log.index(' '))
    pt_destination = log.slice!(0...log.index(' '))
    log.strip!
    pt_protocol = log.slice!(0...log.index(' '))
    log.strip!
    pt_length = log.slice!(0...log.index(' '))
    log.strip!
    pt_info = log

    {
        pt_number: pt_number, pt_time: pt_time, pt_source: pt_source, pt_destination: pt_destination,
        pt_protocol: pt_protocol, pt_length: pt_length, pt_info: pt_info
    }
  end
end