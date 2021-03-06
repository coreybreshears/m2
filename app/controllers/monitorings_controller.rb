# M2 Monitoring Addon
class MonitoringsController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !admin? }, except: [:blocked_ips, :blocked_ip_unblock, :blocked_ip_block]
  before_filter :authorize, if: -> { !admin? }, only: [:blocked_ips, :blocked_ip_unblock, :blocked_ip_block]
  before_filter :check_post_method, only: [:blocked_ip_unblock, :blocked_countries_update]
  before_filter :blocked_ip, only: [:blocked_ip_unblock]
  before_filter :new_block_ip, only: [:blocked_ips, :blocked_ip_block]
  before_filter :check_if_bc_installed, only: [:blocked_countries, :blocked_countries_update]
  before_filter :find_countries, only: [:blocked_countries_update]

  def settings
    @page_title = _('Monitorings_settings')
    @page_icon = 'magnifier.png'
    @options = session[:ma_setting_options] || Hash.new(nil)
  end

  def blocked_ips
    @servers = Server.select("id, CONCAT('ID: ', id, ' IP: ', server_ip) AS server_name").all

    @options = session[:blocked_ips_options] || {}

    set_options_from_params(@options, params, page: 1)

    if params.member?(:s_blocked_ip)
      @options[:s_blocked_ip] = (params[:clear] ? nil : params[:s_blocked_ip])
    end

    fpage, @total_pages, @options = Application.pages_validator(session, @options, BlockedIP.monitorings_blocked_ips(@options).all.size)
    @blocked_ips = BlockedIP.monitorings_blocked_ips(@options.merge({fpage: fpage, items_limit: session[:items_per_page]}))

    session[:blocked_ips_options] = @options
  end

  def blocked_ip_unblock
    @blocked_ip.unblock_me
    flash[:status] = _('IP_will_be_unblocked')
    block_ip_action(@blocked_ip, 'unblock')
    redirect_to(action: :blocked_ips) && (return false)
  end

  def blocked_ip_block
    (params[:blocked_ip][:server_id] == 'all') ? block_ip_multiple : block_ip_single
  end

  def blocked_countries
    @countries = BlockedCountries.list
    @map_data = BlockedCountries.map_data.to_json
  end

  def blocked_countries_update
    if BlockedCountries.update(params[:cb_state_ids])
      block_country_action(@block)
      block_country_action(@unblock, 'unblock')
      flash[:status] = _('Blocked_Countries_saved')
    else
      flash[:notice] = _('All_Countries_cannot_be_blocked')
    end
    redirect_to(action: :blocked_countries) && (return true)
  end

  private

  def blocked_ip
    @blocked_ip = BlockedIP.where(id: params[:id]).first

    # In case ip blocking script changed IDs, try to find one by IP and Server ID
    if @blocked_ip.blank? && params[:blocked_ip].present? && params[:server_id].present?
      @blocked_ip = BlockedIP.where(blocked_ip: params[:blocked_ip], server_id: params[:server_id], unblock: 0).first
    end

    return if @blocked_ip.present?
    flash[:notice] = _('Blocked_IP_was_not_found')
    redirect_to(action: :blocked_ips) && (return false)
  end

  def new_block_ip
    options = {blocked_ip: {}}
    [:blocked_ip, :server_id, :chain].each { |key| options[:blocked_ip][key] = params[:blocked_ip][key].to_s.strip }

    if options[:blocked_ip][:server_id] == 'all'
      server_ids = Server.pluck(:id) - BlockedIP.where(blocked_ip: options[:blocked_ip][:blocked_ip]).pluck(:server_id)
      @block_ips = server_ids.map { |server_id| BlockedIP.new(options[:blocked_ip].merge(unblock: 2, server_id: server_id)) }
    end
    @block_ip = BlockedIP.new(options[:blocked_ip].merge(unblock: 2))
  end

  def check_if_bc_installed
    return unless Confline.get_value('Blocked_Countries_installed').to_i.zero?
    flash[:notice] = _('Blocked_Countries_installation_problem')
    (redirect_to :root) && (return false)
  end

  def block_ip_single
    if @block_ip.validate_ip_for_blocking
      @block_ip.save
      block_ip_action(@block_ip)
      flash[:status] = _('IP_will_be_blocked_in_1_minute')
      redirect_to(action: :blocked_ips)
    else
      flash_errors_for(_('IP_was_not_blocked'), @block_ip)
      redirect_to(action: :blocked_ips, blocked_ip: params[:blocked_ip], visible: true)
    end
  end

  def block_ip_multiple
    if @block_ips.blank?
      flash[:status] = _('IP_is_already_blocked_in_all_Servers')
      redirect_to(action: :blocked_ips) && (return false)
    end

    if @block_ips.size != @block_ips.select { |block_ip| block_ip.validate_ip_for_blocking }.size
      flash_errors_for(_('IP_was_not_blocked'), @block_ips[0])
      redirect_to(action: :blocked_ips, blocked_ip: params[:blocked_ip], visible: true)
    else
      @block_ips.each { |block_ip| block_ip.save }
      block_ip_action(@block_ip, 'block', true)
      flash[:status] = _('IP_will_be_blocked_in_1_minute')
      redirect_to(action: :blocked_ips)
    end
  end

  def block_ip_action(blocked_ip, action = 'block', all_servers = false)
    data3 = all_servers ? "IP was #{action}ed on all servers" : "IP was #{action}ed on single server"
    data4 = "Server id: #{blocked_ip.server_id}" unless all_servers
    Action.add_action_hash(0, action: "#{action}_ip",
                              data: "IP: #{blocked_ip.blocked_ip}",
                              data2: "Country: #{blocked_ip.country}",
                              data3: data3,
                              data4: data4 ? data4 : ''
                          )
  end

  def find_countries
    cb_keys = params[:cb_state_ids].try(:keys) || []
    @unblock = BlockedCountries.countries_to_unblock(cb_keys)
    @block = BlockedCountries.countries_to_block(cb_keys)
  end

  def block_country_action(countries, action = 'block')
    countries.each do |country|
      Action.add_action_hash(0, action: "#{action}_country",
                                data: "Country: #{country}",
                                data2: "Country IP addresses were #{action}ed"
                            )
    end
  end
end
