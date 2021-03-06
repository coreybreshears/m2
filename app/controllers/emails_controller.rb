# -*- encoding : utf-8 -*-
# Emails managing and sending.
class EmailsController < ApplicationController
  require 'enumerator'
  require 'net/pop'
  # require 'pop_ssl'
  BASE_DIR = '/tmp/attachements'
  layout :determine_layout

  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_email, only: [:edit, :update, :show_emails, :list_users, :destroy, :send_emails, :send_emails_from_cc]
  before_filter :find_session_user, only: [:edit, :update, :show_emails, :destroy]

  def index
    redirect_to(action: :list) && (return false)
  end

  def new
    @page_title = _('New_email')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Email_variables'
    @email = Email.new
    @tariff_details = TariffEmailDetail.new
    # @user = User.find(session[:user_id])
  end

  def create
    @page_title = _('New_email')
    @page_icon = 'add.png'
    @email = Email.new(params[:email])
    @tariff_details = TariffEmailDetail.new_by_params(params[:tariff_details])
    @email.assign_attributes(
                                 date_created: Time.now,
                                 callcenter: session[:user_cc_agent],
                                 owner_id: corrected_user_id
                             )

    if @email.save
      notification = params[:email][:email_type].to_i == 1
      @tariff_details.email_id = @email.id if notification
      @tariff_details.save if notification

      flash[:status] = _('Email_was_successfully_created')
      if session[:user_cc_agent].to_i != 1
        redirect_to action: 'list'
      else
        redirect_to action: 'emeils_callcenter'
      end
    else
      flash_errors_for(_('Email_was_not_created'), @email)
      render :new
    end
  end

  # In before filter : @email, @user
  def edit
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Email_variables'
    @page_title = "#{_('Edit_email')}: #{@email.name}"
    @page_icon = 'edit.png'
    @email.subject = @email.subject.force_encoding('UTF-8').html_safe
    @email.body = @email.body.force_encoding('UTF-8').html_safe
    @tariff_details = @email.tariff_email_detail.present? ? @email.tariff_email_detail : TariffEmailDetail.new
  end

  # In before filter : @email, @user
  def update
    @user = User.where(id: session[:user_id]).first
    unless @user
      flash[:notice] = _('User_was_not_found')
      render controller: 'callc', action: 'main'
    end

    notification = params[:email][:email_type].to_i == 1
    email_detail = @email.tariff_email_detail if notification

    @tariff_details = if email_detail.present?
                        email_detail.update_by_params(params[:tariff_details])
                      else
                        TariffEmailDetail.new_by_params(params[:tariff_details])
                      end

    if @email.update_attributes(params[:email])
      @email.save
      @tariff_details.email_id = @email.id if email_detail.blank? && notification
      @tariff_details.save if notification
      flash[:status] = _('Email_was_successfully_updated')
      if session[:user_cc_agent].to_i != 1
        redirect_to action: 'list'
      else
        redirect_to action: 'emeils_callcenter'
      end
    else
      flash_errors_for(_('Email_was_not_updated'), @email)
      render action: 'edit', id: params[:id], ccc: @ccc
    end
  end

  def list
    @page_title = _('Emails')
    @page_icon = 'email.png'

    @emails = Email.select('*').where(["owner_id= ? and (callcenter='0' or callcenter is null)", corrected_user_id]).joins("LEFT JOIN (SELECT data, data2, COUNT(*) as emails FROM actions WHERE (action = 'email_sent' or action = 'warning_balance_send') GROUP BY data2) as actions ON (emails.id = actions.data2)").all.order(:name)
    @email_sending_enabled = Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
    if @emails.size.to_i == 0 && session[:usertype] == 'reseller'
      user = User.find(session[:user_id])
      user.create_reseller_emails
      @emails = Email.where(["owner_id= ? and (callcenter='0' or callcenter is null)", corrected_user_id])
                     .joins("LEFT JOIN (SELECT data, data2, COUNT(*) as emails FROM actions WHERE (action = 'email_sent' or action = 'warning_balance_send') GROUP BY data2) as actions ON (emails.id = actions.data2)")
    end
  end

  def emeils_callcenter
    @page_title = _('Emails')
    @page_icon = 'email.png'
    if session[:usertype].to_s != 'admin'
      @emails = Email.where(["(owner_id= ? or owner_id='0') and callcenter='1'", session[:user_id]])
    else
      @emails = Email.where("callcenter='1'")
    end
    @email_sending_enabled = Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
  end

  # In before filter : @email, @user
  def show_emails
    @page_title = "#{_('show_emails')}: #{@email.name}"
    @page_icon = 'email.png'
  end

  # In before filter : @email
  def list_users
    @page_title = "#{_('Email_sent_to_users')}: #{@email.name}"
    @page_icon = 'view.png'

    @page = 1
    @page = params[:page].to_i if params[:page] && params[:page].to_i > 0

    @total_pages = (Action.where(["data2 = ? AND (action = 'email_sent' or action = 'warning_balance_send')", params[:id]]).to_a.size.to_d / session[:items_per_page]).ceil

    @actions = Action.where(["data2 = ? AND (action = 'email_sent' or action = 'warning_balance_send')", params[:id]])
                     .offset((@page - 1) * session[:items_per_page])
                     .limit(session[:items_per_page]).all
  end

  # In before filter : @email
  def destroy
    if @email.destroy
      flash[:status] = _('Email_deleted')
    else
      flash_errors_for(_('Email_was_not_deleted'), @email)
    end

    if session[:user_cc_agent].to_i != 1
      redirect_to action: 'list'
    else
      redirect_to action: 'emeils_callcenter'
    end
  end

  # In before filter : @email
  def send_emails
    @page_title = _('Send_email') + ': ' + @email.name
    @page_icon = 'email_go.png'

    @email_sending_enabled = Confline.get_value('Email_Sending_Enabled', 0).to_i == 1

    if !@email_sending_enabled or @email.template != 0
      dont_be_so_smart
      redirect_to(controller: 'emails', action: 'list') && (return false)
    end

    @options = session[:emails_send_user_list_opt] || {}

    set_options_from_params(@options, params,
                            shu: 'true',
                            sbu: 'true'
    )

    @users = get_users_with_emails

    session[:emails_send_user_list_opt] = @options
    @user_id_max = User.find_by_sql('SELECT MAX(id) AS result FROM users')
    # find selected users and send email to them
    @users_list = []
    to_email = params[:to_be_sent]
    if to_email
      to_email.each do |user_id, do_it|
        if do_it == 'yes'
          user = User.find(user_id)
          user.m2_email = params[:user_m2_email][user_id]
          @users_list << user
        end
      end
      if @users_list.blank?
        flash[:notice] = _('no_users_selected')
        redirect_to action: 'list'
      else
        send_all(@users_list, @email)
      end

      # sent email to users
    end

    if @users_list.size > 0
      redirect_to action: 'list'
    end
  end

  def users_for_send_email
    @options = session[:emails_send_user_list_opt] || {}

    set_options_from_params(@options, params,
                            shu: 'true',
                            sbu: 'true'
    )

    @users = get_users_with_emails

    @user_id_max = User.find_by_sql('SELECT MAX(id) AS result FROM users')

    session[:emails_send_user_list_opt] = @options
    render layout: false
  end

  # In before filter : @email
  def send_emails_from_cc
    @page_title = _('Send_email') + ': ' + @email.name.to_s
    @page_icon = 'email_go.png'

    @search_agent = params[:agent]
    @agents = User.where('call_center_agent=1')

    @clients = CcClient.whit_main_contact(@search_agent)

    @page = 1
    @page = params[:page].to_i if params[:page]

    @total_pages = (@clients.size.to_d / session[:items_per_page].to_d).ceil
    @all_clients = @clients
    @clients = []
    @a_number = []
    iend = ((session[:items_per_page] * @page) - 1)
    iend = @all_clients.size - 1 if iend > (@all_clients.size - 1)
    (((@page - 1) * session[:items_per_page])..iend).each do |index|
      @clients << @all_clients[index]
    end

    # find selected users and send email to them
    @clients_list = []
    # my_debug params[:to_be_sent].to_yaml
    to_email = params[:to_be_sent]
    if to_email
      to_email.each do |client_id, do_it|
        if do_it == 'yes'
          client = CcClient.whit_email(client_id)
          @clients_list << client
        end
      end

      # sent email to users
      send_all(@clients_list, @email)
    end

    if @clients_list.size > 0
      redirect_to action: 'emeils_callcenter'
    end
  end

  def send_all(users, email)
    status = Email.send_email(email, users, Confline.get_value('Email_from', session[:user_id].to_i), 'send_all', owner: session[:user_id])

    email_sent = _('Email_sent')
    if status.first == email_sent
      flash[:status] = email_sent
    else
      flash[:notice] = _('Something_is_wrong_please_consult_help_link')
      flash[:notice] += "<a id='exception_info_link' href='http://wiki.ocean-tel.uk/index.php/Configuration_from_GUI#Emails' target='_blank'><img alt='Help' src='#{Web_Dir}/images/icons/help.png' title='#{_('Help')}' /></a>".html_safe
    end
  end

  # send_all
  def EmailsController::send_test(id)
    user = User.find(id)
    email = Email.where(["name = 'password_reminder' AND owner_id = ?", id]).first

    users = []
    users << user
    variables = Email.email_variables(user, nil, owner: id)

    # ticket #9050 - send test_email the same way invoices are sent
    # send_email(email, Confline.get_value("Email_from", id), users, variables)

    status = _('email_not_sent')
    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      smtp_server = Confline.get_value('Email_Smtp_Server', id).to_s.strip
      smtp_user = Confline.get_value('Email_Login', id).to_s.strip
      smtp_pass = Confline.get_value('Email_Password', id).to_s.strip
      smtp_port = Confline.get_value('Email_Port', id).to_s.strip

      smtp_connection =  "'#{smtp_server}:#{smtp_port}'"
      smtp_connection << " -xu '#{smtp_user}' -xp $'#{smtp_pass.gsub("'", "\\\\'")}'" if smtp_user.present?

      from = Confline.get_value('Email_from', id).to_s
      to = variables[:user_email]
      email_body = nice_email_sent(email, variables)
      email_subject = nice_email_sent(email, variables, 'subject')
      begin
        system_call = ApplicationController::send_email_dry(from.to_s, to.to_s, email_body, email_subject, '', smtp_connection, email[:format])

        if defined?(NO_EMAIL) && NO_EMAIL.to_i == 1
          # do nothing
        else
          status = _('Email_sent') if system(system_call)
        end
      rescue
        return status
      end
    else
      status = _('Email_disabled')
    end

    return status
  end

  def EmailsController::send_email(email, email_from, users, assigns = {})
    if Confline.get_value('Email_Sending_Enabled', 0).to_i == 1
      email_from.gsub!(' ', '_') # so nasty, but rails has a bug and doest send from_email if it has spaces in it
      status = Email.send_email(email, users, email_from, 'send_email', {assigns: assigns, owner: assigns[:owner], api: assigns[:api]})
      status.uniq.each { |index| @e = index + '<br>' }
      return @e
    else
      return _('Email_disabled')
    end
  end

  def EmailsController::nice_email_sent(email, assigns = {}, type = 'body')
    if email
      email_builder = ActionView::Base.new(nil, assigns)
      email_builder.render(
          inline: EmailsController::nice_email_body(email.try(type.to_sym)),
          locals: assigns
      ).gsub("'", '&#8216;')
    end
  end

  def EmailsController::nice_email_body(email_body)
    email = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |str| str.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$') }
    email = email.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    email.gsub(/(<%=?\s*\S+\s*%>)/) { |str| str if Email::ALLOWED_VARIABLES.include?(str.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

  def EmailsController::send_invoices(email, to, from, files = [], number = 0)

     smtp_server = Confline.get_value('Email_Smtp_Server', email[:owner_id].to_i).to_s.strip
     smtp_user = Confline.get_value('Email_Login', email[:owner_id].to_i).to_s.strip
     smtp_pass = Confline.get_value('Email_Password', email[:owner_id].to_i).to_s.strip
     smtp_port = Confline.get_value('Email_Port', email[:owner_id].to_i).to_s.strip

     begin
       files.each do |file|
         File.open('/home/mor/tmp/' + number.to_s + '_' + file[:filename].to_s.gsub(' ','_'), 'wb') {|fl| fl.write(file[:file]) }
       end

	     filenames = files.map { |file| "'/home/mor/tmp/" + number.to_s + '_' + file[:filename].to_s.gsub(' ','_') + "'" }.join(' ').to_s
       system_call = ApplicationController::send_email_dry(from.to_s, to.to_s, email.body.to_s, email.subject.to_s, "-a #{filenames}", "'#{smtp_server}:#{smtp_port}' -xu '#{smtp_user}' -xp $'#{smtp_pass.gsub("'", "\\\\'")}'", email[:format])

       if defined?(NO_EMAIL) && NO_EMAIL.to_i == 1
       # do nothing
       else
          sending = system(system_call)
       end

       files.each do |file|
         File.delete('/home/mor/tmp/' + number.to_s + '_' + file[:filename].to_s.gsub(' ','_'))
       end
     rescue
       return false
     end
    return 'true' if sending
  end

 # Sends conmirmation email for user after registration.
  def EmailsController.send_user_email_after_registration(user, device, password, reg_ip)
    if Confline.get_value('Send_Email_To_User_After_Registration').to_i == 1
      # send mail to user with device details
      email = Email.where(["name = 'registration_confirmation_for_user' AND owner_id= ?", user.owner_id]).first
      users = [user]
      variables = Email.email_variables(user, device, {login_password: password, user_ip: reg_ip})
      num = EmailsController.send_email(email, Confline.get_value('Email_from', user.owner_id), users, variables)
      #      if num
      #        #flash[:notice] = _('EMAIL_SENDING_ERROR')
      #        action = Action.new
      #        action.user_id = user.id
      #        action.action = "error"
      #        action.date = Time.now
      #        action.data = 'Cant_send_email'
      #        action.data2 = num.to_s
      #        action.save
      #      end
      return 1
    end
    return 0
  end

  # Send mail to admin with registered user details
  def EmailsController.send_admin_email_after_registration(user, device, password, reg_ip, owner_id = 0)
    if Confline.get_value('Send_Email_To_Admin_After_Registration').to_i == 1
      #
      email = Email.where(["name = 'registration_confirmation_for_admin' AND owner_id= ?", owner_id]).first
      users = [User.where(id: owner_id).first]
      variables = Email.email_variables(user, device, {user_ip: reg_ip, password: password})
      num = EmailsController.send_email(email, Confline.get_value('Email_from', owner_id), users, variables)

      #      if num
      #        #flash[:notice] = _('EMAIL_SENDING_ERROR')
      #        action = Action.new
      #        action.user_id = user.id
      #        action.action = "error"
      #        action.date = Time.now
      #        action.data = 'Cant_send_email'
      #        action.data2 = num.to_s
      #        action.save
      #      end
    end
  end

  private

  def get_users_with_emails
    cond = []

    if @options[:shu].to_s == 'false'
      cond <<  'hidden = 0'
    end

    if @options[:sbu].to_s == 'false'
      cond <<  'blocked = 0'
    end

    admin_email = User.where(id: 0).first.try(:email)
    check_admin = admin_email.blank? ? '' : "OR usertype = 'admin'"
    condition = "#{cond.size.to_i > 0 ? ' AND ' : ''} #{cond.join(' AND ')}"

    # Manager should see same stuff as admin
    owner_id = manager? ? 0 : current_user.id
    @users = User.where("(owner_id = #{owner_id} AND ( main_email IS NOT NULL OR noc_email IS NOT NULL OR billing_email IS NOT NULL OR rates_email IS NOT NULL)  AND  (main_email != '' OR noc_email != '' OR billing_email != '' OR rates_email != '') #{condition}) #{check_admin}").all
  end

  def find_email
    @email = Email.where(id: params[:id]).first
    unless @email
      flash[:notice] = _('Email_was_not_found')
      (redirect_to :root) && (return false)
    end
    check_user_for_email(@email)
  end

  def find_session_user
    @user = User.where(id: session[:user_id]).first
    unless @user
      flash[:notice] = _('User_was_not_found')
      render controller: :callc, action: :main
    end
  end

  def check_user_for_email(email)
    if email.class.to_s == 'Fixnum'
      email = Email.where(id: email).first
    end
    if email.owner_id != corrected_user_id
      dont_be_so_smart
      redirect_to(controller: :emails, action: :list) && (return false)
    end
    true
  end
end
