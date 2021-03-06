# -*- encoding : utf-8 -*-
# Call Tracing functionality
class CallTracingController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || manager?) }
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_call, only: [:call_log, :retrieve_call_log, :retrace]
  before_filter :find_device, only: [:call_tracing]
  before_filter :fake_call_data, only: [:fake_call_log, :retrieve_fake_call_log, :retrace_fake_call]
  before_filter :authorize_call_tracing_for_calls_list, only: [:call_log, :retrace, :retrieve_call_log]
  before_filter :authorize_call_tracing_for_connection_points, only: [:call_tracing, :fake_call_log, :retrieve_fake_call_log, :retrieve_fake_call_log]

  def call_log
    if @call.user_id.to_i >= 0
      @user = User.where(id: @call.user_id).first
      if @user
        redirect_to(action: :root) && (return false) unless User.check_responsability(@user.id)
      end
    end
  end

  def retrieve_call_log
    call_log = check_call_log(@call.call_log_data)

    render(json: call_log.try(:nice_log) || [])
  end

  def retrace
    CallLog.where(uniqueid: @call.uniqueid).first.try(:delete)

    redirect_to(action: :call_log, id: @call.id) && (return false)
  end

  def call_tracing
    redirect_to(action: :root) && (return false) unless User.check_responsability(@device.user_id)
  end

  def fake_call_log
    @device = Device.where(id: @call_data[:device_id], op: 1).first

    if @device.blank?
      flash[:notice] = _('Device_Was_Not_Found')
      redirect_to(:root) && (return false)
    end
  end

  def retrieve_fake_call_log
    call_log = check_call_log(@call_data)

    render(json: call_log.try(:nice_log) || [])
  end

  def retrace_fake_call
    CallLog.where(uniqueid: @call_data[:uniqueid]).first.try(:delete)

    redirect_to(action: :fake_call_log,
                id: @call_data[:uniqueid],
                cid: @call_data[:caller_id],
                dst: @call_data[:destination],
                did: @call_data[:device_id]
    ) && (return false)
  end

  private

  def find_call
    @call = Call.where(id: params[:id]).first

    if @call.blank?
      flash[:notice] = _('Call_not_found')
      redirect_to(:root) && (return false)
    end
  end

  def find_device
    @device = Device.where(id: params[:id], op: 1).first

    if @device.blank?
      flash[:notice] = _('Device_Was_Not_Found')
      redirect_to(:root) && (return false)
    end
  end

  def fake_call_data
    @call_data = {
        uniqueid: params[:id],
        caller_id: params[:cid] || params[:call_data].try(:[], :caller_id).to_s,
        destination: params[:dst] || params[:call_data].try(:[], :destination).to_s,
        device_id: params[:did] || params[:call_data].try(:[], :device_id).to_s
    }
  end

  def check_call_log(call_data)
    CallLog.find_log(call_data[:uniqueid]) || trace_call(call_data)
  end

  def trace_call(call_data)
    uniqueid = call_data[:uniqueid]
    path_to_file = "/tmp/m2/m2_call_tracing/execute_#{uniqueid}.m2_call_trace"
    call_tracing_server_id = Confline.get_value("call_tracing_server").to_i
    call_tracing_server = Server.where(id: call_tracing_server_id).first

    prepare_blank_call_tracing_file(path_to_file)
    CallLog.fill_data_to_file(call_data, path_to_file)

    port = Confline.get_value('RADIUS_PORT')
    radius_port = port.present? ? port : 1812

    host = Confline.get_value('RADIUS_HOST')
    radius_host = host.present? ? host : 'localhost'

    request = "/usr/local/bin/radclient -r 1 -t 3 #{radius_host}:#{radius_port} auth m2 -f #{path_to_file}"

    if call_tracing_server_id == 0 || (call_tracing_server && call_tracing_server.local?)
      # Execute radius request locally
      system(request)
    elsif (call_tracing_server)
      # Copy radius file from local server to external server
      system("scp -P #{call_tracing_server[:ssh_port]} -i /var/www/.ssh/id_rsa -o ConnectTimeout=10 #{path_to_file} #{call_tracing_server[:ssh_username]}@#{call_tracing_server[:server_ip]}:#{path_to_file}")
      # Execute radius request in external server
      call_tracing_server.execute_command_in_server(request)
    end

    wait_for_call_log(uniqueid, path_to_file)
  end

  def prepare_blank_call_tracing_file(path_to_file)
    system("rm -rf #{path_to_file} && touch #{path_to_file} && chmod 777 #{path_to_file}")
  end

  def wait_for_call_log(uniqueid, path_to_file)
    counter, call_log = 1, []

    loop do
      call_log = CallLog.find_log(uniqueid)
      break if call_log.present? || counter > 10
      sleep(1)
      counter += 1
    end

    system("rm -rf #{path_to_file}")
    call_log
  end

  def authorize_call_tracing_for_calls_list
    if manager? && !authorize_manager_permissions({controller: :calls, action: :call_info, no_redirect_return: 1})
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end

  def authorize_call_tracing_for_connection_points
    if manager? && !authorize_manager_permissions({controller: :devices, action: :show_devices, no_redirect_return: 1})
      flash[:notice] = _('You_are_not_authorized_to_view_this_page')
      redirect_to(:root) && (return false)
    end
  end
end
