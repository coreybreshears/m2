# -*- encoding : utf-8 -*-
# M2 calls
class CallsController < ApplicationController
  include SqlExport
  include CsvImportDb
  include UniversalHelpers

  layout :determine_layout
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_call,
                only: [
                    :call_info, :download_pcap, :pcap_image, :retrieve_call_details_pcap_text,
                    :retrieve_call_log_radius_text, :retrieve_call_log_freeswitch_text, :retrieve_pcap_file,
                    :retrieve_call_log, :wait_for_call_log
                ]

  def active_call_soft_hangup
    uniqueid = params[:uniqueid]
    server_id = params[:server_id].to_i

    b2bua_servers = Server.where(b2bua: 1).all
    errors = []

    if b2bua_servers.present?
      src_dst = Activecall.select(:src, :dst).where(uniqueid: uniqueid).first
      b2bua_servers.each do |server|
        server.hangup_sems(src_dst.src, src_dst.dst, uniqueid)
        errors << server.errors.map {|_, value| value } if server.errors.present?
      end
    end

    if server_id > 0 && b2bua_servers.blank?
      server = Server.find_by(id: server_id, server_type: :freeswitch)
      server.hangup_call(uniqueid) if server
      errors << server.errors.map {|_, value| value } if server.errors.present?
    end

    if errors.present?
      @errors_present = true
      flash_array_errors_for(_('Hangup_Failed'), errors.flatten)
    end

    MorLog.my_debug "Hangup on server: #{server_id}"
    render layout: 'layouts/mor_min'
  end

  def call_info
    @show_currency_selector = 1
    if @call.user_id.to_i >= 0
      @user = User.where(id: @call.user_id).first
      if @user
        redirect_to(action: :root) && (return false) unless User.check_responsability(@user.id)
      end
    end

    dst_user_id = @call.dst_user_id
    src_device_id = @call.src_device_id

    @terminator = User.where(id: dst_user_id).first if dst_user_id.to_i >= 0

    @src_device = Device.where(id: src_device_id).first if src_device_id.to_i >= 0
    @dst_device = Device.where(id: @call.dst_device_id).first if @call.provider_id.to_i > 0

    @call_log = @call.call_log
    @radius_call_log = CallLog.where(uniqueid: "log_#{@call.uniqueid}").first
    @currency = current_user.currency.try(:name).to_s
    @exchange_rate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency]).to_d

    @call_details = CallDetail.where(call_id: @call.id).first
  end

  def download_pcap
    call_id = @call.id
    if pcap = CallDetail.where(call_id: call_id).first.try(:pcap)
      send_data(hex_to_bytes(pcap), filename: "call_#{call_id}.pcap", type: 'application/octet-stream')
    end
  end

  def pcap_image
    if pcap_graph = CallDetail.where(call_id: @call.id).first.try(:pcap_graph)
      send_data(hex_to_bytes(pcap_graph), type: 'image/png', disposition: 'inline')
    end
  end

  def retrieve_call_details_pcap_text
    call_detail = CallDetail.where(call_id: @call.id).first
    render(json: call_detail.try(:nice_pcap_text) || [])
  end

  def retrieve_pcap_file
    server = if Confline.get_value('Retrieve_PCAP_files_from_the_Proxy_Server', 0).to_i == 1
               Server.where(proxy: '1').first
             else
               Server.find_by(id: @call.server_id)
             end

    calldate = @call.calldate.strftime('%Y-%m-%d %H:%M:%S')

    response = server.try(
      :execute_command_in_server, "/usr/local/m2/m2_pcap '#{calldate}' '#{@call.dst}' "\
      "'#{@call.src}' '#{@call.originator_ip}' '#{@call.terminator_ip}' '#{@call.id}'"
    )

    if response == false && !server.local?
      flash_help_link = 'http://wiki.ocean-tel.uk/index.php/Configure_SSH_connection_between_servers'
      flash[:notice] = "#{_('Cannot_connect_to_server')} #{server.server_ip}"
      flash[:notice] += "<a href='#{flash_help_link}' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' />&nbsp;#{_('Click_here_for_more_info')}</a>"
    elsif CallDetail.where(call_id: @call.id).first.try(:pcap).blank?
      # PCAP script could not generate a file
      flash[:notice] = _('PCAP_file_does_not_exist')
    end
    redirect_to(action: :call_info, id: params[:id])
  end

  def retrieve_call_log_radius_text
    call_log = CallLog.where(uniqueid: "log_#{@call.uniqueid}").first
    render(json: call_log.try(:nice_log, :radius_log) || [])
  end

  def retrieve_call_log_freeswitch_text
    call_log = CallLog.where(uniqueid: "log_#{@call.uniqueid}").first
    render(json: call_log.try(:nice_log, :freeswitch_log) || [])
  end

  def retrieve_call_log
    # Create new empty call_logs record and set uniqueid to 'log_uniqueid'
    # Due to technical reasons, executed script cannot create call_logs records therefore we create this record here
    # Executed script can only update this record
    CallLog.create_new_log(@call.uniqueid)

    # we know server id on which call was made, also check on core/radius server
    servers = Server.where('id = ? OR core = 1', @call.server_id)
    # Set request (path to m2_call_log script with arguments)
    request = @call.call_log_request
    # Send request to each server via SSH unless server is local
    servers.each do |server|
      MorLog.my_debug "retrieve_call_log: Processing server with ID: #{server.id}"
      if server.local?
        system(request)
      else
        begin
          Net::SSH.start(
            server[:server_ip].to_s, server[:ssh_username].to_s,
            port: server[:ssh_port].to_i, timeout: 10,
            keys: %w[/var/www/.ssh/id_rsa], auth_methods: %w[publickey]
          ) { |ssh| ssh.exec! request }
        rescue Net::SSH::Exception, SystemExit, ScriptError, StandardError => error
          MorLog.my_debug "Retrieve Call Log error: #{error.message}"
          flash[:notice] = _('Cannot_connect_to_core_server')
        end
      end
    end
    redirect_to(action: :call_info, id: params[:id])
  end

  private

  def find_call
    unless @call = Call.where(id: params[:id]).first
      flash[:notice] = _('Call_not_found')
      redirect_to(:root) && (return false)
    end

    # Only admin and accountant can view call info
    if !(admin? || manager?)
      flash[:notice] = _('You_have_no_view_permission')
      redirect_to(:root) && (return false)
    end
  end
end
