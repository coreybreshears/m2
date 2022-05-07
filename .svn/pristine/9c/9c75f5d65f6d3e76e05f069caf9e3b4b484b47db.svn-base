# Test Controller
class TestController < ApplicationController
  before_filter :authorize_admin, except: [:fake_form, :vat_checking_get_status]
  # require 'google4r/checkout'
  # include Google4R::Checkout

  def create_user
    # opts = {}
    # params[:tax] ? opts[:tax] = params[:tax] : opts[:tax] = false
    # params[:address] ? opts[:address] = params[:address] : opts[:address] = false
    user = User.order('id desc').first.dup
    user.username = user.username.to_s + 'no_adr'
    user.tax_id = 999999
    user.address = nil
    user.save(validate: false)
    render text: 'OK'
  end

  def time_zones
    render text: "<table><tr><th>NAME</th><th>VALUE</th></tr>#{ActiveSupport::TimeZone.all.each_with_index.collect { |tz, index| "<tr #{"style='background-color:#EEE'" if index % 2 == 1}><td id='#{tz.name.downcase}'>#{tz.to_s}</td><td id='tz_value_#{index}'>#{tz.name}</td></tr>" }.join()}</table>".html_safe
  end

  def recaptcha_config_values
    Confline.load_recaptcha_settings
    render text: "<table><tr><td>Public Key</td><td id='public'>#{Recaptcha.configuration.public_key}</td></tr><tr><td>Private Key</td><td id='private'>#{Recaptcha.configuration.private_key}</td></tr></table>".html_safe
  end

  def time
    @time = Time.now()
  end

  def vat_checking_get_status
    condition = Timeout::timeout(5) { !!Net::HTTP.new('ec.europa.eu', 80).request_get('/taxation_customs/vies/vatRequest.html').code } rescue false
    render text: (condition ? 1 : 0)
  end

  def check_db_update
    value = Confline.get_value('DB_Update_From_Script', 0)
    render text: ((value.to_i == 1) ? value : '')
  end

  def launch_script
  end

  def script_output
    command = params[:command].to_s
    script_path = command.split(' ').first
    if command.present?
      if File.exists?(script_path)
        result = 'Launching script.</br>Output:</br>'
        result << `/usr/src/mor/test/launcher.sh #{command}`
        result.gsub! /\n/, '<br>'
      else
        result = 'No such file'
      end
      render text: result
    else
      redirect_to action: :launch_script
    end
  end

  def raise_exception
    params[:this_is_fake_exception] = nil
    params[:do_not_log_test_exception] = 1
    case params[:id]
      when 'Errno::ENETUNREACH'
        raise Errno::ENETUNREACH
      when 'Transactions'
        raise ActiveRecord::Transactions::TransactionError, 'Transaction aborted'
      when 'RuntimeError'
        raise RuntimeError, 'No route to host'
      when 'RuntimeErrorExit'
        raise RuntimeError, 'exit'
      when 'Errno::EHOSTUNREACH'
        raise Errno::EHOSTUNREACH
      when 'Errno::ETIMEDOUT'
        raise Errno::ETIMEDOUT
      when 'SystemExit'
        raise SystemExit
      when 'SocketError'
        raise SocketError
      when 'NoMemoryError'
        params[:this_is_fake_exception] = 'YES'
        raise NoMemoryError
      when 'DNS_TEST'
        raise 'getaddrinfo: Temporary failure in name resolution'
      when 'ReCaptcha'
        raise NameError, 'uninitialized constant Ambethia::ReCaptcha::Controller::RecaptchaError'
      when 'SyntaxError'
        raise SyntaxError
      when 'OpenSSL::SSL::SSLError'
        Confline.set_value('Last_Crash_Exception_Class', '')
        raise OpenSSL::SSL::SSLError
      when 'Cairo'
        raise LoadError, 'Could not find the ruby cairo bindings in the standard locations or via rubygems. Check to ensure they\'re installed correctly'
      when 'Google_account_not_active'
        params[:this_is_fake_exception] = 'YES'
        raise GoogleCheckoutError, message: 'Seller Account 666666666666666 is not active.', response_code: '', serial_number: '6666666-6666-6666-6666-666666666666'
      when 'Google_500'
        params[:this_is_fake_exception] = ''
        raise RuntimeError, 'Unexpected response code (Net::HTTPInternalServerError): 500 - Internal Server Error'
      when 'Gems'
        raise LoadError, 'in the standard locations or via rubygems. Check to en'
      when 'MYSQL'
        params[:this_is_fake_exception] = 'YES'
        Confline.set_value('Last_Crash_Exception_Class', '')
        sql = 'alter table users drop first_name ;'
        test = ActiveRecord::Base.connection.execute(sql)
        us = User.find(0)
        us.first_name
      when 'test_exceptions'
        Confline.set_value('Last_Crash_Exception_Class', '')
        params[:this_is_fake_exception] = ''
        raise SyntaxError
      when 'pdf_limit'
        PdfGen::Count.check_page_number(4, 1)
      else
        flash[:notice] = _('ActionView::MissingTemplate')
        redirect_to(:root) && (return false)
    end
  end

  def nice_exception_raiser
    params[:do_not_log_test_exception] = 1
    params[:this_is_fake_exception] = nil
    if params[:exc_class]
      raise eval(params[:exc_class].to_s), params[:exc_message].to_s
    end
  end

  def last_exception
    render text: Confline.get_value('Last_Crash_Exception_Class', 0).to_s
  end

  def load_delta_sql
    path = (params[:path].to_s.empty? ? params[:id] : params[:path])
    MorLog.my_debug(path)
    # MorLog.my_debug(params[:path].join("/"))
    MorLog.my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/#{path.to_s.gsub(/[^A-Za-z0-9_\/]/, '')}.sql"
    MorLog.my_debug(filename)
    if File.exist?(filename)
      command = "mysql -u mor -pmor --default-character-set=utf8 mor < #{filename}"
      MorLog.my_debug(command)
      rez = `#{command}`
      MorLog.my_debug("DELTA SQL FILE WAS LOADED: #{filename}")
    else
      MorLog.my_debug("Delta SQL file was not found: #{filename}")
      rez = 'Not Found'
    end
    sys_admin = User.where(id: 0).first
    renew_session(sys_admin) if sys_admin
    render text: rez
  end

  # loads bundle file which has patch to sql files which are loaded one-by-one
  # used for tests to prepare data before testing
  # called by Selenium script through MOR GUI
  def load_bundle_sql
    path = (params[:path].to_s.empty? ? params[:id] : params[:path])
    MorLog.my_debug(path)
    # MorLog.my_debug(params[:path].join("/"))
    MorLog.my_debug(File.exist?("#{Rails.root}/config/routes.rb"))
    filename = "#{Rails.root}/selenium/bundles/#{path.to_s.gsub(/[^A-Za-z0-9_\/]/, '')}.bundle"
    MorLog.my_debug(filename)
    if File.exist?(filename)
      command = "/home/mor/selenium/scripts/load_bundle.sh #{filename}"
      MorLog.my_debug(command)
      rez = `#{command}`
      MorLog.my_debug("BUNDLE WAS LOADED: #{filename}")
    else
      MorLog.my_debug("Bundle file was not found: #{filename}")
      rez = 'Not Found'
    end
    render text: rez
  end

  def restart
    `mor -l`
  end

  def fake_form
    @all_fields = params.reject { |key, _| ['controller', 'action', 'path_to_action'].include?(key) }
    @data = params[:path_to_action]
  end

  def test_api
    api_name = params[:api_name] ||= ''
    allow, values = MorApi.hash_checking(params, request, api_name)
    render text: values[:system_hash]
  end

  def make_select
    @tables = ActiveRecord::Base.connection.tables
    @table = @tables.include?(params[:table]) ? params[:table] : nil

    if params[:id] && @table
      @select = if @table.to_s != 'sessions'
                  @table.singularize.titleize.gsub(' ', '').constantize.where(id: params[:id]).first
                else
                  ActiveRecord::Base.connection.select_all("SELECT * FROM #{params[:table]} WHERE id = #{params[:id].to_i}")
                end
    end
  end

  # Returns touched files from Models/Controllers/Views
  # from application launch till now
  # !!!Be aware, works only once!!!
  # after only 'n -l *' and 'rm -rf /home/mor/log' will help

  # /config/application.rb must have these above 'module Mor'

  # require 'simplecov'
  # SimpleCov.start do
  #   add_filter "app/assets/"
  #   add_filter "app/helpers/"
  #   add_filter "app/views/"
  #   add_filter "lib/"
  #   add_filter "config/"

  #   add_group "Models", "app/models"
  #   add_group "Controllers", "app/controllers"

  #   puts "required simplecov"
  # end
  def covered_files
    # Actual_Dir = /home/mor
    # Web_Dir = /billing or ''
    touched_files, view_files = [], []
    rails_environment = Rails.env.to_s
    leave_me_alone = 'This method should not be used any more'

    # Get Models/Controllers
    begin
      #SimpleCov::Result.new(Coverage.result).filenames.each { |string| touched_files << string.gsub("#{Actual_Dir}/", '') }
    rescue
      leave_me_alone
    end

    # Get Views
    path_to_log = "#{Actual_Dir}/log/#{rails_environment}.log"
    if File.exists?(path_to_log)
      File.read(path_to_log).scan(/^\s\sRendered.*$/).each { |string| view_files << "app/views/#{string.strip!.split[1]}" }
      view_files.delete_if { |string| string.include?('/usr/local/rvm/') }
      view_files.each { |string| touched_files << string }
    else
      leave_me_alone
    end

    touched_files.uniq!

    render text: touched_files
  end

  def delete_invoice_xlsx_files_in_tmp_folder
    FileUtils.rm_rf(Dir.glob('/tmp/m2/invoices/*'))
  end

  def is_get_location_working
    ip = '77.240.248.90'

    iplocation = Iplocation.where(ip: ip).first
    iplocation.update_columns(latitude: 0, longitude: 0, country: nil, city: nil) if iplocation.present?

    is_get_location_working = Iplocation.get_location(ip).try(:country).to_s == 'Lithuania'

    render text: (is_get_location_working ? 'yes' : 'no')
  end

  def tariff_import_v2
    render layout: 'callc'
  end
end
