# -*- encoding : utf-8 -*-
# An application programming interface methods.
class ApiController < ApplicationController
  skip_before_filter :verify_authenticity_token

  session :off, except: [:login, :user_login, :login_form]

  include SqlExport

  require 'builder/xmlbase'
  skip_before_filter :set_current_user, :set_charset, :set_timezone
  before_filter :check_allow_api, except: [:invoice_xlsx_generate]
  before_filter :check_send_method, except: [:user_simple_balance_get, :user_balance_get, :invoice_xlsx_generate]
  # no_such_api hides some api methods, #12203
  before_filter :no_such_api, only: [
      :financial_statements_get, :device_create, :device_delete,
      :user_details_update, :system_version_get, :email_send
  ]
  before_filter :log_access
  before_filter :find_current_user_for_api, only: [
      :personal_payments, :user_rates, :user_devices, :main_page, :user_logout, :payments_get,
      :financial_statements_get, :quickstats_get, :payment_create, :exchange_rate_update, :aggregate_get
  ]
  before_filter :check_api_params_with_hash, only: [
      :financial_statements_get, :user_logout, :user_details_get, :user_details_update,
      :user_balance_get, :user_balance_update, :tariff_rates_get, :tariff_wholesale_update, :device_create,
      :device_delete, :devices_get, :payments_get, :email_send, :system_version_get, :device_details_get,
      :quickstats_get, :payment_create, :exchange_rate_update, :aggregate_get, :user_login
  ]
  before_filter :check_elastic_status, only: [:quickstats_get]
  before_action :prepare_doc, only: %i(exchange_rate_update)

  require 'xmlsimple'

  def method_missing(method_name)
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.error {
      doc.type('Undefined method')
      doc.name(method_name.to_s)
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  # Logins user to the system
  def user_login
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8', standalone: 'yes'
    check_user_for_login(params[:u].to_s.strip, params[:p].to_s.strip)

    remote_address = request.env['REMOTE_ADDR'].to_s
    login_ok = false
    if @user
      add_action(@user.id, 'log', remote_address)
      @user.update_attributes(logged: 1)
      if Confline.get_value('API_Login_Redirect_to_Main').to_i.zero?
        doc = MorApi.loggin_output(doc, @user)
      else
        login_ok = true
        renew_session(@user)
        # Session is synced with the last password change
        if Confline.get_value('logout_on_password_change').to_i == 1
          session.merge!(session_token: @user.password_changed_at)
        end
        session[:login_ip] = request.remote_ip
      end
    else
      add_action_second(0, 'bad_login', params[:u].to_s + '/' + params[:p].to_s, remote_address)
      doc = MorApi.failed_loggin_output(doc, remote_address)
    end

    session[:login] = login_ok
    if Confline.get_value('API_Login_Redirect_to_Main').to_i == 1 && login_ok
      bad_psw = (params[:p].to_s == 'admin' and @user.id == 0) ? _('ATTENTION!_Please_change_admin_password_from_default_one_Press')+ " <a href='#{Web_Dir}/users/edit/0'> #{_('Here')} </a> " + _('to_do_this') : ''
      store_url
      flash[:notice] = bad_psw if !bad_psw.blank?
      flash[:status] = _('login_successfully')
      redirect_to(:root) && (return false)
    else
      send_xml_data(out_string, params[:test].to_i)
    end
  end

  # Logout user from the system.
  def user_logout

    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8', standalone: 'yes'

    username = params[:u]

    if username.length > 0 && user = User.where(username: username).first
      add_action(@current_user.id, 'logout', '')
      user.update_attributes(logged: 0)
      doc = MorApi.logout_output(doc)
    else
      doc = MorApi.failed_logout_output(doc)
    end
    send_xml_data(out_string, params[:test].to_i)
  end


=begin  Needs rework with m2_invoices
 # Retrieves list of invoices in selected time period.
 # Returns invoices for selected user in selected period
 # * +file+ - return file or plain response. Values - [true, false]  Default : true
  def invoices_get
    MorLog.my_debug("INVOICES")

    opts = {}
    ["true", "false"].include?(params[:file].to_s) ? opts[:file] = params[:file] : opts[:file] = "true"

    username = params[:u]
    from = params[:from]
    till = params[:till]

    username = "" if not username
    from = 0 if not from
    till = 0 if not till

    from_t = Time.at(from.to_i)
    till_t = Time.at(till.to_i)

    from_nice = nice_date(from_t, 0)
    till_nice = nice_date(till_t, 0)

    user = User.where(:username => username).first

    if user
      User.current = user
      cond = ""
      cond =  case user.usertype.to_s
              when "admin"
                " AND users.owner_id = #{user.id}"
              when "user"
                " AND invoices.user_id = #{user.id}"
              end
      invoices = Invoice.select("invoices.*").joins("JOIN users on (users.id = invoices.user_id)").where(["period_start >= ? AND period_end <= ? AND users.generate_invoice != 0 #{cond}", from_nice, till_nice])

      if !invoices.blank? or invoices.size != 0
        doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
        doc.Invoices("from" => from_nice, "till" => till_nice) {
          for inv in invoices
            iuser = inv.user
            doc.Invoice("user_id" => inv.user_id, "agreementnumber" => iuser.agreement_number, "clientid" => iuser.clientid, "number" => inv.number) {
              for invdet in inv.invoicedetails
                doc.Product {
                  doc.Name(invdet.name)
                  doc.Quantity(invdet.quantity)
                  doc.Price(nice_number(invdet.read_attribute(:price) * (inv.invoice_currency.present? ? inv.invoice_exchange_rate.to_d : User.current.currency.exchange_rate.to_d)))
                  doc.Date_added((inv.payment ? nice_date(inv.payment.date_added, 0) : ''))
                  doc.Issue_date(nice_date(inv.issue_date, 0))
                }
              end
            }
          end
        }
      else
        doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
        doc.Error("no invoices found")
      end
    else
      doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
      doc.Error("user not found")
    end

    # return out_string
    if opts[:file] == "true"
      if confline("XML_API_Extension").to_i == 0
        send_data(out_string, :type => "text/xml", :filename => "mor_api_response.xml")
      else
        send_data(out_string, :type => "text/html", :filename => "mor_api_response.html")
      end
    else
      render :text => out_string
    end
  end
=end

  def login_form
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8', standalone: 'yes'
    check_user(params[:u])

    if @user
      @user.mark_logged_in
    end

    doc.page {
      doc.pagename('Login page')
      doc.language("#{I18n.locale}")
      doc.error_msg('')
      doc.aval_languages {
      }
    }

    send_xml_data(out_string, params[:test].to_i)
  end

  def payment_create
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
      doc.page {
        if Confline.get_value('API_Allow_payments_ower_API').to_i == 1
          user = User.where(id: @values[:user_id], owner_id: @current_user.id).first if @values[:user_id]
          if user
            amount = @values[:amount]
            if amount
              currency = Currency.get_by_name(@values[:currency])
              if currency
                if @values[:amount_in_tax].to_i == 1
                  amount_with_tax = gross = @values[:amount].to_d
                  amount_with_no_tax = amount = user.get_tax.count_amount_without_tax(gross).to_d
                else
                  amount_with_no_tax = amount = @values[:amount].to_d
                  amount_with_tax = gross = user.get_tax.apply_tax(amount).to_d
                end

                exchange_rate = params[:exchange_rate].to_d > 0 && currency.id != 1 ? params[:exchange_rate].to_d : Currency.count_exchange_rate(Currency.get_default.name, currency.name)

                comment = params[:comment].to_s if params[:comment]

                if params[:payment_to_provider].to_i == 1
                  amount_with_tax = 0 - amount_with_tax
                  amount_with_no_tax = 0 - amount_with_no_tax
                end

                paym = M2Payment.create(user_id: user.id, amount: amount_with_no_tax.to_d,
                                  amount_with_tax: amount_with_tax.to_d, currency_id: currency.id,
                                  exchange_rate: exchange_rate.to_d, comment: comment,
                                  date: Time.now())

                tax = paym.amount_with_tax - paym.amount

                doc.response {
                  doc.status('ok')
                  doc.payment('currency' => currency.name) {
                  doc.payment_id(paym.id)
                  doc.tax(nice_number(tax))
                  doc.amount(nice_number(amount_with_no_tax))
                  doc.gross(nice_number(amount_with_tax))
                  }
                }

                Action.add_action_hash(paym.user_id,
                                {action: 'payment: from_api',
                                 data: 'User successfully paid using from_api',
                                 data3: "#{paym.amount} #{currency.name} | tax: #{paym.amount_with_tax - paym.amount} #{currency.name} | sent: #{paym.amount_with_tax} #{currency.name}",
                                 data2: "payment id: #{paym.id}"
                                })
              else
                doc.error(_('Currency_was_not_found'))
              end
            else
              doc.error(_('Amount_was_not_found'))
            end
          else
            doc.error(_('Dont_be_so_smart'))
          end
        else
          doc.error(_('Payments_are_not_allow_from_api'))
        end
      }
    send_xml_data(out_string, params[:test].to_i)
  end

  def payments_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8', standalone: 'yes'
    params_from_s = params[:from_s]
    params_till_s = params[:till_s]
    from = params_from_s ? Time.at(params_from_s.to_i).to_s(:db) : Time.mktime(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0).to_s(:db)
    till = params_till_s ? Time.at(params_till_s.to_i).to_s(:db) : Time.mktime(Time.now.year, Time.now.month, Time.now.day, 23, 59, 59).to_s(:db)

    cond = ['date BETWEEN ? AND ?']
    cond_param = [from, till]

    if @current_user.usertype == 'user'
      # Simple user can access only his own payments
      user_id = @current_user.id
    else
      user_id_s = params[:user_id_s]
      user_id = user_id_s if user_id_s =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/ && user_id_s
    end

    if user_id
      cond << 'user_id = ?'
      cond_param << user_id
    end

    amount_min = params[:amount_min_s]
    amount_max = params[:amount_max_s]

    cond << "amount >= '#{amount_min}' " if amount_min && amount_min =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/
    cond << "amount <= '#{amount_max}' " if amount_max && amount_max =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/


    %w[username first_name last_name].each { |col|
      add_contition_and_param(params["#{col}_s".to_sym], params["#{col}_s".intern].to_s + '%', "users.#{col} LIKE ?", cond, cond_param) }

    if params[:currency_s]
      currency = Currency.get_by_name(params[:currency_s])
        if currency.present?
          cond << 'm2_payments.currency_id = ?'
          cond_param << currency.id
        end
    end

    @payments = M2Payment.select("m2_payments.*, m2_payments.user_id as 'user_id', users.username, users.first_name, users.last_name").
        joins('left join users on (m2_payments.user_id = users.id)').
        where([cond.join(' AND ')] + cond_param)

    if @payments.present?
      doc.page {
        doc.pagename("#{_('Payments_list')}")
        doc.payments {
          @payments.each { |payment|
            doc.payment {
              user = User.where(id: payment.user_id).first if !payment.user_id.blank?
              currency = Currency.where(id: payment.currency.id).first
              doc.user(nice_user(user).to_s) if user
              doc.date(nice_date_time payment.date.to_s)
              doc.user_balance_before_payment(nice_number(payment.user_balance_before).to_s)
              doc.user_balance_after_payment(nice_number(payment.user_balance_after).to_s)
              doc.amount(nice_number(payment.amount).to_s)
              doc.amount_with_tax(nice_number(payment.amount_with_tax).to_s)
              doc.comment(payment.comment.to_s)
              doc.currency(currency.name.to_s)
            }
          }
        }
      }
    else
      doc.error(_('Payments_were_not_found'))
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def main_page
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    check_user(params[:u])

    if @user
      @user.mark_logged_in
      today = Time.now.strftime('%Y-%m-%d')
      @missed_calls = @user.calls('missed_inc', today, today)
      @missed_calls_today = @missed_calls.size
      @not_processed_calls_today = @user.calls('missed_not_processed_inc', today, today).size
      @not_processed_calls_total = @user.calls('missed_not_processed_inc', '2000-01-01', today).size
      month_t = Time.now.year.to_s + '-' + good_date(Time.now.month.to_s)
      last_day = last_day_of_month(Time.now.year.to_s, good_date(Time.now.month.to_s))
      day_t = month_t + '-' + good_date(Time.now.day.to_s)

      if @current_user.usertype == 'admin'
        @callsm = Call.where("calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59' AND disposition = 'ANSWERED'")
        @callsd = Call.where("calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59' AND disposition = 'ANSWERED'")
      else
        @callsm = Call.where("calls.user_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59' AND disposition = 'ANSWERED'")
        @callsd = Call.where("calls.user_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59' AND disposition = 'ANSWERED'")
        if @current_user.usertype == 'reseller'
          @callsm = Call.where("calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{month_t}-01 00:00:00' AND '#{month_t}-#{last_day} 23:59:59' AND disposition = 'ANSWERED'")
          @callsd = Call.where("calls.reseller_id = '#{@current_user.id}' AND calls.calldate BETWEEN '#{day_t} 00:00:00' AND '#{day_t} 23:59:59' AND disposition = 'ANSWERED'")
        end
      end

      @total_durationm = 0
      @total_call_pricem = 0
      @total_call_selfpricem = 0
      @total_callsm = 0

      @total_durationd = 0
      @total_call_priced = 0
      @total_call_selfpriced = 0
      @total_callsd = 0

      if @current_user.usertype == 'reseller'
        @callsm.each do |call|
          @total_callsm = @total_callsm + 1
          @total_durationm += (call.billsec).to_i
          @total_call_pricem += (call.user_price).to_d
          @total_call_selfpricem += (call.reseller_price).to_d
        end
      else
        @callsm.each do |call|
          @total_callsm= @total_callsm + 1
          @total_durationm += (call.billsec).to_i
          if call.reseller_id == 0
            @total_call_pricem = @total_call_pricem + (call.user_price).to_d
          else
            @total_call_pricem = @total_call_pricem + (call.reseller_price).to_d
          end
          @total_call_selfpricem = @total_call_selfpricem + (call.provider_price).to_d
        end
      end


      if @current_user.usertype == 'reseller'
        @callsd.each do |call|
          @total_callsd=@total_callsd + 1
          @total_durationd += (call.billsec).to_i
          @total_call_priced += (call.user_price).to_d
          @total_call_selfpriced += (call.reseller_price).to_d
        end
      else
        @callsd.each do |call|
          @total_callsd=@total_callsd+1
          @total_durationd += (call.billsec).to_i
          if call.reseller_id == 0
            @total_call_priced = @total_call_priced + (call.user_price).to_d
          else
            @total_call_priced = @total_call_priced + (call.reseller_price).to_d
          end
          @total_call_selfpriced = @total_call_selfpriced + (call.provider_price).to_d
        end
      end

      @total_profitm = @total_call_pricem - @total_call_selfpricem
      @total_profitd = @total_call_priced - @total_call_selfpriced

      doc.page {
        doc.pagename("#{_('Main_page')}")
        doc.username("#{params[:u]}")
        doc.userid("#{@current_user.id}")
        doc.language("#{I18n.locale}")
        doc.stats {
          doc.missed_calls {
            doc.missed_today("#{@missed_calls_today}")
            doc.missed_total("#{@not_processed_calls_total}")
          }
          doc.call_history {
            doc.calls {
              doc.call_counts("#{@total_callsm}")
              doc.period("#{_('Month')}")
              doc.call_duration("#{ nice_time @total_durationm}")
              if @current_user.usertype == 'reseller' or @current_user.usertype == 'admin'
                doc.call_profit("#{@total_profitm}")
              end
            }
            doc.calls {
              doc.call_counts("#{@total_callsd}")
              doc.period("#{_('Day')}")
              doc.call_duration("#{nice_time @total_durationd}")
              if @current_user.usertype == 'reseller' or @current_user.usertype == 'admin'
                doc.call_profit("#{@total_profitd}")
              end
            }
          }
        }
      }

    else
      doc.page {
        doc.pagename("#{_('Main_page')}")
        doc.language('en')
        doc.error_msg('')
        doc.aval_languages {
          doc.language("#{tr.short_name}")

        }
      }

    end

    send_xml_data(out_string, params[:test].to_i)
  end

   # Returns user personal information.
   #
   # *Post*/*Get* *params*:
   # * user_id - User ID
   # * hash - SHA1 hash

  def user_details_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    #a bit nasty, huh? there are some issues after disabling session.
    #if current user is set then currency would be converted to logged
    #in user's currency, but tests say it should be default currency and
    #no conversion, hence no User.current should be set
    User.current = nil

    username = params[:u].to_s

    @user_logged = User.where(username: username).first
    if @user_logged
      user_id = @values[:user_id]
      username_param = @values[:username]
      cond = []
      cond_param = []
      if %w(admin reseller).include? @user_logged.usertype
        if user_id
          cond << 'id = ?'
          cond_param << user_id
        end

        if username_param
          cond << 'username = ?'
          cond_param << username_param
        end

        if @user_logged.usertype == 'reseller'
          if user_id
            logged_user_id = @user_logged.id
            owner = logged_user_id.to_i == user_id.to_i ? 0 : logged_user_id
            cond << 'owner_id = ?'
            cond_param << owner.to_i
          end
        end
        @user = User.where([cond.join(' AND ')] + cond_param).first
      else
        @user = User.where(username: username).first
      end

      if @user
        @address = @user.address
        @country = Direction.where(id: @user.taxation_country).first
        doc.page {
          doc.pagename("#{_('Personal_details')}")
          doc.language('en')
          doc.userid("#{@user.id}")
          doc.details {
            doc.main_detail {
              doc.balance("#{nice_number @user.balance } #{Currency.get_default.name}")
              #ticket #4913, there's a rumor that api wil be rewriten, thats the only viable
              #reason to add these elements, cause this mess wil be thrown away soon
              doc.balance_number(@user.balance.to_s)
              doc.balance_currency(Currency.get_default.name)
              doc.hide_non_answered_calls(@user.hide_non_answered_calls.to_s) if @user.is_user?
            }
            doc.other_details {
              doc.username("#{@user.username}")
              doc.first_name("#{@user.first_name}")
              doc.surname("#{@user.last_name}")
              doc.personalid("#{@user.clientid}")
              doc.agreement_number("#{@user.agreement_number}")
              ad = @user.agreement_date
              ad= Time.now if !ad
              doc.agreement_date("#{nice_date(ad, 0)}")
              doc.taxation_country("#{@country.name[0, 22]}") if @country
              doc.vat_reg_number("#{@user.vat_number}")
              doc.vat_percent("#{@user.vat_percent}")
            }
            if @address
              doc.registration {
                doc.reg_address("#{@address.address}")
                doc.reg_postcode("#{@address.postcode}")
                doc.reg_city("#{@address.city}")
                doc.reg_country("#{@address.county}")
                doc.reg_state("#{@address.state}")
                doc.reg_direction("#{@user.main_email}")
                doc.reg_phone("#{@address.phone}")
                doc.reg_mobile("#{@address.mob_phone}")
                doc.reg_fax("#{@address.fax}")
                doc.reg_email("#{@user.main_email}")
              }
            end
          }
        }
      else
        doc.error('User was not found')
      end
    else
      doc.error('Access Denied')
      MorApi.create_error_action(params, request, 'API : User not found by login and password')
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def user_devices
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    check_user(params[:u])

    if @user
      @user.mark_logged_in
      @devices = @user.devices

      doc.page {
        doc.pagename("#{_('Devices')}")
        doc.language("#{I18n.locale}")
        doc.userid("#{@current_user.id}")
        doc.devices {
          for dev in @devices
            doc.device {
              doc.acc("#{dev.id}")
              doc.description("#{dev.description}")
              doc.type("#{dev.device_type}")
              doc.extension("#{dev.extension}")
              doc.username("#{dev.name}")
              doc.password("#{dev.secret}")
              doc.cid("#{dev.callerid}")
              doc.last_time_registered("#{nice_date_time(Time.at(dev.regseconds))}")
            }
          end
        }
      }

    else
      doc.page {
        doc.pagename("#{_('Devices')}")
        doc.language('en')
        doc.error_msg('')
        doc.aval_languages {

          doc.language("#{tr.short_name}")

        }
      }

    end

    send_xml_data(out_string, params[:test].to_i)
  end

  def user_rates
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)

    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    check_user(params[:u])
    if @user
      @user.mark_logged_in
      @tariff = User.where(id: @current_user.id).first.tariff
      @dgroups = Destinationgroup.all.order("name ASC")
      @vat = 0.to_d
      @rates_cur2 = []

      sql = "SELECT rates.* FROM rates, destinations, directions WHERE rates.tariff_id = #{@tariff.id} AND rates.destination_id = destinations.id AND destinations.direction_code = directions.code ORDER by directions.name ASC;"
      rates = Rate.find_by_sql(sql)

      exrate = Currency.count_exchange_rate(@tariff.currency, @current_user.currency.name)
      for rate in rates
        get_provider_rate_details(rate, exrate)
        @rates_cur2[rate.id]=@rate_cur
      end

      @currency = Currency.get_active

      doc.page {
        doc.pagename("#{_('Payments')}")
        doc.language("#{I18n.locale}")
        doc.userid("#{@current_user.id}")
        doc.currency("#{@current_user.currency.name}")
        doc.vat_percent("#{@vat}")
        doc.aval_currencies {
          @currency.each {|curr| doc.currency("#{curr.name}")}
        }
        doc.rates {
          rates.each do |rate|
            doc.rate {
              doc.ratename("#{rate.destination.direction.name}")
              doc.rateicon("#{rate.destination.prefix}")
              doc.ratecost("#{nice_number @rates_cur2[rate.id]}")
              doc.rate_vat_cost("#{nice_number(@rates_cur2[rate.id] * (100 + @vat) / 100)}")
            }
          end
        }
      }
    else
      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language('en')
        doc.error_msg('')
        doc.aval_languages {
        }
      }

    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def tariff_rates_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    check_user(params[:u])
      doc.page {
        doc.status {
          if @user
            usertype = @user.usertype
            unless usertype == 'manager' && !authorize_manager_permissions({controller: :tariffs, action: :list, no_redirect_return: 1, user: @user})
              tariff_id_value = @values[:tariff_id]
              device_id_value = @values[:device_id]
              if tariff_id_value || device_id_value
                if device_id_value
                  array = Device.where(id: device_id_value).pluck(:op_tariff_id, :tp_tariff_id)
                  device_tariff_id = array[0]
                  if device_tariff_id
                    op_tariff_id = device_tariff_id[0].to_i
                    tp_tariff_id = device_tariff_id[1].to_i
                    if op_tariff_id > 0
                      tariff = Tariff.where(id: op_tariff_id).first
                    elsif op_tariff_id == 0 && tp_tariff_id > 0
                      tariff = Tariff.where(id: tp_tariff_id).first
                    end
                  else
                    device_not_found = true
                  end
                elsif tariff_id_value
                  tariff = Tariff.where(id: tariff_id_value).first
                end

                unless device_not_found
                  if tariff
                    unless (usertype == 'user' && !@user.tariff_belongs_to_user?(tariff))
                      beginning = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><page><status><pagename>#{_('Tariff')}</pagename> "\
                                  "<tariff_name>#{tariff.name.to_s}</tariff_name> <purpose>#{tariff.purpose}</purpose> "\
                                  "<currency>#{tariff.currency}</currency> <rates>"
                      ending = '</rates></status></page>'

                      result = tariff.tariffs_api_wholesale

                      out_string = beginning + result + ending
                    else
                      doc.error(_('Dont_be_so_smart'))
                    end
                  else
                    doc.error('No tariff found')
                  end
                else
                   doc.error(_('Device_Was_Not_Found'))
                end
              else
                doc.error('device_id or tariff_id was not found')
              end
            else
              doc.error('You are not authorized to manage tariffs')
            end
          else
            doc.error('Bad login')
          end
        }
      }
    send_xml_data(out_string, params[:test].to_i, "get_tariff_#{Time.now.to_i}.xml", true)
  end

  def tariff_belongs_to_user?(user, tariff)
    # Lets check if tariff belongs to one of the users devices
    user.devices.pluck(:op_tariff_id, :tp_tariff_id).flatten!.include?(tariff.id)
  end

  def get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.where(rate_id: rate.id.to_s).order('rate DESC')
    if @rate_details.size > 0
      @rate_increment_s=@rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({exrate: exrate, prices: [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    @rate_details
  end


  def dg_list_user_destinations

    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)

    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    check_user(params[:u])
    if @user
      @user.mark_logged_in
      @destgroup = Destinationgroup.where(:id => params[:dest_gr_id]).first
      @destinations = @destgroup.destinations

      doc.page {
        doc.pagename("#{_('Destinations')}")
        doc.language("#{I18n.locale}")
        doc.groupname("#{@destgroup.name}")
        doc.groupicon("#{@destgroup.flag}")
        doc.directions {
          for destination in @destinations
            doc.direction {
              doc.details("#{destination.direction.name} #{destination.name}")
              doc.prefix("#{destination.prefix}")
            }
          end
        }
      }

    else

      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language('en')
        doc.error_msg('')
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end


  def personal_payments
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    check_user(params[:u])
    if @user
      @user.mark_logged_in
      @payments = @user.payments
      doc.page {
        doc.pagename("#{_('Payments')}")
        doc.language("#{I18n.locale}")
        doc.userid("#{@current_user.id}")
        doc.payments {
          for payment in @payments
            completed = _('_Yes')
            if  payment.completed.to_i == 0
              completed = _('_No')
              completed += ' (' + payment.pending_reason + ')' if payment.pending_reason
            end
            doc.payment {
              doc.payment_date("#{nice_date_time payment.date_added}")
              doc.confirmed_date("#{nice_date_time payment.shipped_at}")
              doc.payment_type("#{payment.paymenttype.capitalize}")
              pa = payment.amount
              doc.amount("#{nice_number pa}")
              doc.vat("#{@user.vat_percent}")
              awv = payment.amount
              doc.amount_vat("#{nice_number awv}")
              doc.currency("#{payment.currency}")
              doc.completed("#{completed}")
            }
          end
        }
      }
    else

      doc.page {
        doc.pagename("#{_('Call_State')}")
        doc.language('en')
        doc.error_msg('')
        doc.aval_languages {
        }
      }
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  # Needs rework with m2_invoices
  #   def user_invoices
  #     doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
  #
  #     doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
  #
  #     check_user(params[:u], params[:p])
  #     if @user
  #       @user.mark_logged_in
  #       @user.postpaid.to_i == 1 ? type = "postpaid" : type = "prepaid"
  #       @invoices = @user.invoices(:include => [:tax, :user])
  #
  #       doc.page {
  #         doc.pagename("#{_('Invoices')}")
  #         doc.language("#{I18n.locale}")
  #         doc.userid("#{@current_user.id}")
  #         doc.invoices {
  #           for inv in @invoices
  #             doc.invoice {
  #               user = inv.user
  #               doc.user("#{user.first_name + " " + user.last_name}")
  #               doc.inv_number("#{inv.number}")
  #               doc.period_start("#{inv.period_start}")
  #               doc.period_end("#{inv.period_end}")
  #               doc.issue_date("#{inv.issue_date}")
  #               doc.paid("#{inv.paid}")
  #               doc.paid_date("#{nice_date_time inv.paid_date if inv.paid == 1 }")
  #               doc.price("#{nice_invoice_number(inv.price, type)}")
  #               doc.price_vat("#{nice_invoice_number(inv.price_with_tax(:precision => nice_invoice_number_digits(type)), type)}")
  #             }
  #           end
  #         }
  #       }
  #     else
  #       doc.page {
  #         doc.pagename("#{_('Call_State')}")
  #         doc.language("en")
  #         doc.error_msg("")
  #         doc.aval_languages {
  #         }
  #       }
  #     end
  #     send_xml_data(out_string, params[:test].to_i)
  #   end

  #  *Post*/*Get* *params*:
  #  *s_direction - "outgoing"
  #  * period_start - calls period starting date.
  #    Default - Today 00:00
  #  * period_end - calls period ending date.
  #    Default - Today 23:59
  #  *s_call_type -"all",
  #  *s_device=>"all",
  #  *s_provider=>"all",
  #  *s_hgc=>0,
  #  *s_user => "all",
  #  *user => nil,
  #  *s_destination => "",
  #  *order_by => "time",
  #  *order_desc => 0,
  #  *s_country=>''
  #  * Hash - SHA1 hash

  def user_calls_get
    api_name = params[:api_name] ||= ''
    allow, values = MorApi.hash_checking(params, request, api_name)
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    if allow == true

      username = params[:u].to_s
      password = params[:p].to_s

      @user_logged = check_user(username)
      if @user_logged
        @options = last_calls_stats_parse_params
        if @user_logged.usertype.to_s == 'user'
          user = @user_logged
          device = @user_logged.devices.visible.origination_points.where(id: @options[:s_origination_point]).first if @options[:s_origination_point] != 'all' && !@options[:s_origination_point].blank?
        end

        if @user_logged.is_admin?
          user = User.where(id: @options[:s_user]).first if @options[:s_user] =~ /^[0-9]+$/
          device = Device.visible.origination_points.where(id: @options[:s_origination_point]).first if @options[:s_origination_point] != 'all' && !@options[:s_origination_point].blank?
          hgc = Hangupcausecode.where(id: @options[:s_hgc]).first if @options[:s_hgc].to_i > 0
          provider = Device.visible.termination_points.where(id: @options[:s_termination_point]).first if @options[:s_termination_point].to_i > 0
        end

        if user or @options[:s_user] == 'all'

          time_now = Time.now
          time_now_year = Time.now.year
          time_now_month = Time.now.month
          time_now_day = Time.now.day
          @options[:from] = values[:period_start] ? Time.at(values[:period_start]).to_s(:db) : Time.mktime(time_now_year, time_now_month, time_now_day, 0, 0, 0).to_s(:db)
          @options[:till] = values[:period_end] ? Time.at(values[:period_end]).to_s(:db) : Time.mktime(time_now_year, time_now_month, time_now_day, 23, 59, 59).to_s(:db)
          @options[:exchange_rate] = 1 # Exchange_rate
          options = last_calls_stats_set_variables(@options, {user: user, origination_point: device, hgc: hgc, current_user: @user_logged, termination_point: provider})
          options[:current_user] = @user_logged

          calls, test_content = Call.last_calls_csv(options.merge({pdf: 1, api: 1}))
          @user_logged.hide_destination_end = @user_logged.hide_destination_end

          doc.page {
            doc.pagename('Calls')
            doc.language('en')
            doc.error_msg("#{}")
            doc.userid(@user_logged.id)
            doc.username(@user_logged.username)
            doc.total_calls("#{calls.size}")
            doc.currency(Currency.where(id: 1).first.name)
            doc.calls_stat {
              doc.period {
                doc.period_start(@options[:from])
                doc.period_end(@options[:till])
              }
              doc.show_user(@options[:s_user])
              doc.show_origination_point(@options[:s_origination_point])
              doc.show_status(@options[:s_call_type])
              doc.show_termination_point(@options[:s_termination_point]) if !@options[:s_termination_point].blank?
              doc.show_hgc(((@options[:s_hgc].to_i > 0) ? @options[:s_hgc].to_i : 'all')) if !@options[:s_hgc].blank?
              doc.show_destination(@options[:s_destination]) if !@options[:s_destination].blank?
              if calls and calls.size.to_i > 0
                doc.calls {
                  for call in calls
                    doc.call {
                      # This Pulls out uniqueid to be last
                      uniqueid = call.uniqueid
                      sorted_calls = call.attributes.reject {|key, value| key == 'uniqueid' || key.blank? }.sort
                      sorted_calls << ['uniqueid', uniqueid]
                      sorted_calls.each {|key, value|
                        case key.to_s
                          when 'calldate2'
                            doc.tag!(key, nice_date_time(value, 0))
                            doc.timezone(time_now.strftime("GMT %:z"))
                          when 'dst'
                            doc.tag!(key, hide_dst_for_user(@user_logged, "gui", value))
                          when 'nice_billsec'
                            doc.tag!(key, call[key].round)
                          else
                            doc.tag!(key, call[key])
                        end
                      }
                    }
                  end
                }
              end
            }
          }
        else
          doc.error('User was not found')
        end
      else
        doc.error(_('Dont_be_so_smart'))
        MorApi.create_error_action(params, request, 'API : User not found by login and password')
      end
    else
      doc.error('Incorrect hash')
    end

    send_xml_data(out_string, params[:test].to_i)
  end

  def user_simple_balance_get
    if Confline.get_value('Devices_Check_Ballance').to_i == 1
      @user = User.where(uniquehash: params[:id]).first if params[:id]
      if @user
        if Currency.where(name: params[:currency]).first # in case valid currency was supplied return balance in that currency
          user_balance = @user.read_attribute(:balance) * Currency.count_exchange_rate(Currency.get_default.name, params[:currency])
        else # in case invalid or no currency value was supplied, return currency in system's currency
          user_balance = @user.read_attribute(:balance)
        end
        render text: nice_number(user_balance).to_s
      else
        render text: _('User_Not_Found')
      end
    else
      render text: _('Feature_Disabled')
    end
  end

  def user_balance_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page do
      if Confline.get_value('Devices_Check_Ballance').to_i == 1
        user = User.where(username: params[:username]).first
        if user
          currency = params[:currency].to_s.strip
          user_currency = params[:user_currency].to_i == 1
          currency = user.currency.name if currency.upcase == 'USER' || user_currency
          user_balance = user.read_attribute(:balance)
          if Currency.where(name: currency).first || user_currency
            user_balance *= Currency.count_exchange_rate(Currency.get_default.name, currency)
          end
          doc.balance nice_number(user_balance).to_s
          if user_currency # in case user_currency = 1 param was send, return balance in user_currency with new line <currency>
            doc.currency(currency)
          end
        else
          doc.error _('User_Not_Found')
        end
      else
        doc.error _('Feature_Disabled')
      end
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  # *Post*/*Get* *params*:
  # * user_id - User id
  # * balance - balance.
  # * Hash - SHA1 hash

  def user_balance_update
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        user_b = User.where(id: @values[:user_id], owner_id: @user.id).first if @values[:user_id]
        if user_b
          old_balance = user_b.balance.to_d
          if @values[:balance]
            user_b.balance = user_b.balance + @values[:balance].to_d
            if user_b.save
              Action.add_action_hash(@user, {target_id: user_b.id, target_type: 'User', action: 'User balance changed from API', data: old_balance, data2: user_b.balance, data3: request.env['REMOTE_ADDR'].to_s})
              doc.page {
                doc.status('User balance updated')
                doc.user {
                  doc.username(user_b.username)
                  doc.id(user_b.id)
                  doc.balance(user_b.balance)
                }
              }
            else
              Action.add_action_hash(@user, {target_id: user_b.id, target_type: 'User', action: 'User balance not changet from API', data: request['REQUEST_URI'].to_s[0..255], data2: request['REMOTE_ADDR'].to_s, data3: params.inspect.to_s[0..255], data4: user_b.errors.to_yaml})
              doc.error('User balance not updeted')
              #doc.notice("User balance not updeted")
            end
          else
            Action.add_action_hash(@user, {target_id: user_b.id, target_type: 'User', action: 'User balance not changet from API', data: request['REQUEST_URI'].to_s[0..255], data2: request['REMOTE_ADDR'].to_s, data3: params.inspect.to_s[0..255], data4: user_b.errors.to_yaml})
            doc.error('User balance not updeted')
          end
        else
          doc.error('User was not found')
        end
      else
        doc.error('Bad login')
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def user_details_update
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        if @user.usertype == 'user'
          doc.error(_('Dont_be_so_smart'))
        else
          owner_id = @user.id
          if @user.usertype == 'reseller'
            user_u = User.where(id: @values[:user_id], owner_id: owner_id).first if @values[:user_id]
            user_u = @user if @values[:user_id] == owner_id
          else
            user_u = User.where(id: @values[:user_id], owner_id: owner_id).first if @values[:user_id]
          end
          if user_u

            params[:address] = {}
            ['address', 'city', 'postcode', 'county', 'mob_phone', 'fax', 'direction_id', 'phone', 'email',
              'state'].each_with_index { |symbol, index|
              params[:address][symbol.to_sym] = params["a#{index}"] if params["a#{index}"]
            }

            params[:user] = {}
            ['vat_number', 'warning_email_hour', 'hide_destination_end', 'currency_id', 'tariff_id',
              'warning_email_balance', 'language', 'username', 'warning_balance_call',
              'acc_group_id', 'generate_invoice', 'usertype', 'taxation_country', 'blocked', 'quickforwards_rule_id',
              'last_name', 'call_limit', 'clientid', 'recording_hdd_quota', 'cyberplat_active', 'recordings_email',
              'first_name', 'warning_balance_sound_file_id', 'postpaid', 'accounting_number', 'agreement_number',
              'hidden'].each_with_index { |symbol, index|
              params[:user][symbol.to_sym] = params["u#{index}"] if params["u#{index}"]
            }

            params[:hide_non_answered_calls] = params[:u30] if params[:u30] && (@user.is_admin? || @user.is_reseller?)

            params[:agr_date] = {}
            params[:agr_date][:year] = params[:ay]
            params[:agr_date][:day] = params[:ad]
            params[:agr_date][:month] = params[:am]


            params[:block_at_date] = {}
            params[:block_at_date][:year] = params[:by]
            params[:block_at_date][:day] = params[:bd]
            params[:block_at_date][:month] = params[:bm]

            params[:password] = {}
            params[:password][:password] = params[:pswd] if params[:pswd]


            params[:date] = {}
            params[:date][:user_warning_email_hour] = params[:user_warning_email_hour]

            params[:privacy] = {}
            params[:privacy][:gui] = params[:pgui]
            params[:privacy][:csv] = params[:pcsv]
            params[:privacy][:pdf] = params[:ppdf]

            #paramas += pp
            MorLog.my_debug @user.usertype

            notice, par = user_u.validate_from_update(@user, params, 1)

            if notice.blank?
              tax = {'tax1_enabled' => 1}
              [:tax2_enabled, :tax3_enabled, :tax3_enabled, :compound_tax].each do |param|
                tax.merge!({ param => params[param].to_i }) if params[param]
              end
              [:tax1_name, :tax2_name, :tax3_name, :tax4_name, :total_tax_name].each do |param|
                tax.merge!({ param => params[param].to_s}) if params[param].to_s.present?
              end

              [:tax1_value, :tax2_value, :tax3_value, :tax4_value].each do |param|
                tax.merge!({ param => params[param].to_d}) if params[param]
              end

              user_u.update_from_edit(par, @user, tax, 1)

              if user_u.address.valid? and user_u.save
                if user_u.usertype == 'reseller'
                  user_u.check_default_user_conflines
                end
                user_u.address.save
                doc.status('User was updated')
              else
                doc.error('User was not updated')
                unless user_u.address.valid?
                  user_u.address.errors.each { |key, value|
                    doc.message(_(value))
                  } if user_u.address.respond_to?(:errors)
                else
                  user_u.errors.each { |key, value|
                    doc.message(_(value))
                  } if user_u.respond_to?(:errors)
                end
              end
            else
              doc.error(notice)
            end
          else
            doc.error('User was not found')
          end
        end
      else
        doc.error('Bad login')
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def device_delete
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        device = Device.where(id: params[:device]).first
        if device
          if check_owner_for_device(device.user_id, 0, @user)
            notice = device.validate_before_destroy(@user)
            if !notice.blank?
              doc.error(notice)
            else
              device.destroy_all
              doc.status('Device was deleted')
            end
          else
            dont_be_so_smart(@user.id)
            doc.error(_('Dont_be_so_smart'))
          end
        else
          doc.error('Device was not found')
        end
      else
        doc.error('Bad login')
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def split_number(number)
    number_array = []
    number = number.to_s.gsub(/\D/, "")
    number.size.times { |index| number_array << number[0..index] }
    return number_array
  end

  # HACK: laikinas metodas pritaikantis xmlsimple parse formata prie parasyto funcionalumo
  # TO DO: reikia patvarkyti kad veiktu be sito!!!
  def transition_hash(hash)
    def clean_keys(hash)
      nh = {}
      hash.each_pair do |key, value|
        value_first = value
        if value.is_a?(Array) && value.first.is_a?(String)
          nh[key.to_sym] = value.first.strip
        elsif value_first.is_a?(Array)
          nh[key.to_sym] = []
          value_first.each { |index| nh[key.to_sym] << clean_keys(index) }
        end
      end
      nh
    end

    # get one level down
    hash.each_pair do |key, value|
      if value.is_a?(Array) && value.first.is_a?(Hash) && value.first.keys.size == 1
        value = value.first[value.first.keys.first]
        hash[key] = value
      end
    end

    clean_keys(hash)
  end

  def tariff_wholesale_update
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user and (@user.is_admin? or @user.is_reseller?)
        tariff_id = params[:id].to_i
        if tariff_id == 0
          tariff = Tariff.new({
            name: params[:name].try(:to_s),
            currency: params[:currency].try(:to_s),
            purpose: 'user_wholesale',
            owner: @user
          }.reject{|key, val| !val})
          if tariff.save
            doc.status('ok')
            doc.tariff_id(tariff.id)
          else
            doc.error {
              tariff.errors.each { |key, value|
                doc.message(_(value))
              } if tariff.respond_to?(:errors)
            }
          end
        else
          tariff = Tariff.where(id: tariff_id, owner_id: @user.id, purpose: 'user_wholesale').first
          if tariff
            tariff.assign_attributes({
              name: params[:name].try(:to_s),
              currency: params[:currency].try(:to_s)
            }.reject{|key, val| !val})
            if tariff.save
              doc.status('ok')
            else
              doc.error {
                tariff.errors.each { |key, value|
                  doc.message(_(value))
                } if tariff.respond_to?(:errors)
              }
            end
          else
            doc.error('Tariff not found')
          end
        end
      else
        doc.error('Bad login')
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def device_create
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        if check_owner_for_device(params[:user_id], 0, @user)
          coi = @user.id
          user_u = User.where(id: @values[:user_id], owner_id: coi).first if @values[:user_id]
          if user_u
            params[:device] = {}
            params[:device][:description] = params[:description]
            params[:device][:device_type] = params[:type]
            params[:device][:pin] = params[:pin] if  params[:pin]
            params[:device][:caller_id] = params[:caller_id] if params[:caller_id]
            params[:device][:ipaddr] = params[:ip_address] if params[:ip_address]

            az, av = @user.alow_device_types_dahdi_virt

            notice, params2 = Device.validate_before_create(@user, user_u, params, az, av)

            if !params[:caller_id].to_s.strip.blank?
              callerid = "<#{params[:caller_id].to_s.strip}>"
              notice = "CallerID_must_be_numeric" unless (!!Float(params[:caller_id].to_s.strip) rescue false)
            end

            if !notice.blank?
              doc.error(_(notice).gsub('_', ' '))
            else
              if !params2[:device][:device_type] or params2[:device][:device_type].blank?
                params2[:device][:device_type] = Confline.get_value('Default_device_type', @user.id).to_s
              end
              if params2[:device][:device_type].blank?
                params2[:device][:device_type] = 'SIP'
              end
              params2[:device][:pin] = new_device_pin if !params2[:device][:pin]
              device = user_u.create_default_device({device_ip_authentication_record: params2[:ip_authentication].to_i, description: params2[:device][:description], device_type: params2[:device][:device_type], secret: random_password(12), pin: params2[:device][:pin]})
              device.callerid = callerid if callerid
              if device.save
                Thread.new { configure_extensions(device.id, {api: 1, current_user: @user}); ActiveRecord::Base.connection.close }
                doc.status(_('device_created'))
                doc.id(device.id)
                doc.username(device.username)
                doc.password(device.secret)
              else
                doc.error('Device was not created')
                device.errors.each { |key, value|
                  doc.message(_(value))
                } if device.respond_to?(:errors)
              end
            end
          else
            doc.error('User was not found')
          end
        else
          dont_be_so_smart(@user.id)
          doc.error(_('Dont_be_so_smart'))
        end
      else
        doc.error('Bad login')
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  # Valid date range is mandatory parameter. Dates has to be supplied as unix timestamps.
  # Every user may flter by status. Valid statuses are - paid, unpaid, 'all'. if not
  # supplied defaults to 'all'.
  #
  # For instance some posible api commands are:
  # /api/financial_statements?u=admin&p=admin&date_from=1231453&date_till=23452&hash=234234
  # /api/financial_statements?u=admin&p=admin&status=all&date_from=1231453&date_till=23452&hash=234234
  # /api/financial_statements?u=admin&p=admin&status=paid&date_from=1231453&date_till=23452$hash=234234
  # /api/financial_statements?u=admin&p=admin&user_id=3&date_from=1231453&date_till=23452$hash=23453
  # /api/financial_statements?u=admin&p=admin&status=all&user_id=5&date_from=1231453&date_till=23452&hash=354234

  def financial_statements_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      if @values[:date_from] and @values[:date_till]
        date_from = Time.at(@values[:date_from].to_i).to_date.to_s(:db)
        date_till = Time.at(@values[:date_till].to_i).to_date.to_s(:db)
      end
      date_from = Date.today.to_s(:db) if !date_from
      date_till = Time.now.tomorrow.to_s(:db) if !date_till
      status = %w(paid unpaid all).include? @values[:status] ? @values[:status] : 'all'

      if @current_user.usertype == 'user'
        user_id = @current_user.id
        ordinary_user = @current_user.is_user?
      elsif @values[:user_id] and @values[:user_id].to_i > 0
        user_id = @values[:user_id].to_i
      end
      owner_id = @current_user.is_admin? ? 0 : @current_user.id

      if !@current_user.is_user?
        coi = @current_user.id
        user = User.where(id: @values[:user_id], owner_id: coi).first if @values[:user_id]
      else
        user = @current_user
      end

      if user || !@values[:user_id]

        financial_statements = {}
        default_currency_name = Currency.get_default.name
        financial_statements['payments'] = Payment.financial_statements(owner_id, user_id, status, date_from, date_till, ordinary_user, default_currency_name)

        doc.financial_statement('currency' => default_currency_name) {
          financial_statements.each { |type, statements|
            statements.each { |data|
              doc.statement('type' => type) {
                doc.status(data.status)
                doc.count(data.count)
                if type == 'payments'
                  doc.price(nice_number(data.price))
                  doc.price_with_vat(nice_number(data.price_with_vat))
                else
                  doc.price(nice_number(data.price * count_exchange_rate(@current_user.currency.name, default_currency_name)))
                  doc.price_with_vat(nice_number(data.price_with_vat * count_exchange_rate(@current_user.currency.name, default_currency_name)))
                end
              }
            }
          }
        }
      else
        doc.error(_('Dont_be_so_smart'))
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  # *Params*
  # +amount+ - float. If amount is not supplied it defaults to 0, and no payment will be added.

  def system_version_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        version = Confline.get_value('Version', 0).to_s.gsub('MOR ','')
        doc.version(version)
      else
        flash_status(doc, _('Dont_be_so_smart'))
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def email_send
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        if @user.usertype == 'admin' || @user.usertype == 'reseller'
          email = Email.where(name: params[:email_name], owner_id: @user.get_corrected_owner_id).first
          if email
            if @user.email
              if !params[:email_to_user_id].blank?
                user = User.where(id: params[:email_to_user_id]).first
              else
                user = @user
              end
              if user
                variables = Email.map_variables_for_api(params)
                if params[:test_body].to_i == 1
                  email_body = nice_email_sent(email, variables).gsub("'", '&#8216;')
                  doc.email_sending_status(email_body)
                else
                  users = [user]  # hack
                  num = EmailsController.send_email(email, @user.email, users, variables.merge({owner: @user.owner_id, api: 1}))
                  doc.email_sending_status(num.to_s.gsub('<br>', ''))
                end
              else
                doc = MorApi.return_error('User not found', doc)
              end
            else
              doc = MorApi.return_error('Your email not found', doc)
            end
          else
            doc = MorApi.return_error('Email not found', doc)
          end
        else
          doc = MorApi.return_error(_('Dont_be_so_smart'), doc)
        end
      else
        doc = MorApi.return_error('Bad login', doc)
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def devices_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page {
      check_user(params[:u])
      if @user
        if !@user.is_manager? || !(@user.is_manager? && !authorize_manager_permissions({controller: :devices, action: :devices_all, no_redirect_return: 1, user: @user}))
          user_id = params[:user_id].to_s.strip
          owner_id = (@user.is_manager? ? 0 : @user.id)
          user = User.where(id: user_id).first
          if user && user.owner_id != owner_id
            doc.error(_('Dont_be_so_smart'))
          elsif user && !user_id.blank?
            if user.devices.blank?
              doc.error('Device not found')
            else
              doc.devices {
                user.devices.map do |device|
                  doc.device {
                    doc.device_id device.id
                    doc.device_type device.device_type
                    doc.ipaddr device.ipaddr
                    doc.port device.port
                  }
                end
              }
            end
          else
            user_id.blank? ? doc.error('user_id is empty') : doc.error('User not found')
          end
        else
          doc.error('You are not authorized to manage devices')
        end
      else
        doc.error('Bad login')
      end
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def device_details_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    error = validate_device_details_get
    doc.page {
      doc.status {
      if error.blank?
        doc.devices{
          doc.device{
          MorApi.list_device_content(doc, @device)
          MorApi.list_codecs(doc, @device)
          }
        }
      else
        doc.error(error)
      end
      }
    }
    send_xml_data(out_string, params[:test].to_i)
  end

  def quickstats_get
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'

    if @current_user.present?
      time_now = Time.now.in_time_zone(@user.time_zone)
      year = time_now.year.to_s
      month = time_now.month.to_s
      day = time_now.day.to_s
      last_day = last_day_of_month(year, month)
      day_t = "#{year}-#{good_date(month)}-#{good_date(day)}"

      is_user = @current_user.is_user?
      quick_stats = @user.quick_stats('', last_day, day_t)
      doc.page do
        doc.quickstats do
          %w(today month).each_with_index do |period, index|
            index *= 6
            doc.tag!(period) do
              doc.calls(quick_stats[index + 0])
              doc.duration(quick_stats[index + 1].to_i)
              if @current_user.hide_financial_data_in_quick_stats.to_i == 0 || !is_user
                doc.tag!(is_user ? 'price' : 'revenue', quick_stats[index + 3])
              end
              unless is_user
                doc.self_cost(quick_stats[index + 2])
                doc.profit(quick_stats[index + 4])
                doc.margin(quick_stats[index + 5])
              end
            end
          end
          if !is_user || Confline.get_value('Show_Active_Calls_for_Users').to_i == 1
            doc.active_calls do
              doc.total(@user.active_calls_count(hide_active_calls_longer_than))
              doc.answered_calls(@user.active_calls_count(hide_active_calls_longer_than, true))
            end
          end
          if is_user && @current_user.hide_financial_data_in_quick_stats.to_i == 0
            doc.balance(@current_user.raw_balance)
          end
        end
      end
    else
      doc.error('Access Denied')
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def invoice_xlsx_generate
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
    doc.page do
      require 'templateXL/templateXL/templates/m2_invoice_template'
      invoice_by_id = M2Invoice.where(id: params[:invoice_id]).first
      if invoice_by_id.present?
        invoice_user = invoice_by_id.user
        template_path, invoice_cells_confline_owner_id = invoice_user.custom_invoice_xlsx_template_preparation
        m2_invoice_number = invoice_by_id.number
        file_path, file_name = ["/tmp/m2/invoices/#{m2_invoice_number}.xlsx", "#{m2_invoice_number}.xlsx"]

        m2_invoice_template = TemplateXL::M2InvoiceTemplate.new(template_path, file_path, invoice_cells_confline_owner_id)
        m2_invoice_template.m2_invoice, m2_invoice_template.m2_invoice_lines = invoice_by_id.copy_for_xslx
        m2_invoice_template.generate
        m2_invoice_template.save

        if Confline.get_value('convert_xlsx_to_pdf').to_i == 1
          system("rm -rf /tmp/m2/invoices/#{m2_invoice_number}.pdf")
          convert_xlsx_to_pdf('/tmp/m2/invoices', m2_invoice_number)
        end

        doc.success('XLSX file successfully created')
      else
        doc.error('Invoice was not found')
      end
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  def exchange_rate_update
    @doc.page do
      @doc.status do
        if can_manage_currencies?
          @doc = MorApi.exchange_rate_update(@doc, params.slice(:currency, :rate))
        else
          @doc.error(current_is_manager? ? 'You are not authorized to use this functionality' : 'Access Denied')
        end
      end
    end
    send_xml_data(@out_string, params[:test].to_i)
  end

  def aggregate_get
    params[:dst] = params[:a_dst]
    params[:src] = params[:a_src]
    doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
    doc.page do
      if current_is_admin?
        @options = {}
        from = params[:from]
        till = params[:till]
        params_curr = params[:a_currency]
        currency = params_curr if Currency.where(name: params_curr, active: 1).present?
        currency ||= Currency.get_default.name.to_s
        date_today = Date.today
        from ||= date_today.strftime('%Y-%m-%d %H:%M:%S').to_time.to_i
        till ||= date_today.strftime('%Y-%m-%d 23:59:59').to_time.to_i
        from_t = Time.at(from.to_i).strftime('%Y-%m-%dT%H:%M:%S')
        till_t = Time.at(till.to_i).strftime('%Y-%m-%dT%H:%M:%S')
        # if originator or terminator id present, method format_options need string to search.
        params[:s_originator] = 'OK' if params[:s_originator_id].present?
        params[:s_terminator] = 'OK' if params[:s_terminator_id].present?
        @options = EsAggregates.format_options(params, from_t, till_t, @current_user)
        data = MorApi.aggregate_data_format(params, @options).merge(currency: currency)
        data = EsAggregates.get_data(data)
        doc = MorApi.aggregate_data_output(data, doc, @user)
      else
        doc.error('Access Denied')
      end
    end
    send_xml_data(out_string, params[:test].to_i)
  end

  private

  def prepare_doc
    @doc = Builder::XmlMarkup.new(target: @out_string = '', indent: 2)
    @doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
  end

  def current_is_admin?
    @current_user.try(:is_admin?)
  end

  def current_is_manager?
    @current_user.try(:is_manager?)
  end

  def can_manage_currencies?
    current_is_admin? || (current_is_manager? && authorize_manager_permissions(
                              controller: :currencies,
                              action: :currencies,
                              no_redirect_return: 1,
                              user: @current_user
                            )
                          )
  end

  # Checks if API is allowed.

  def check_allow_api
    if Confline.get_value('Allow_API').to_i != 1
      send_xml_data(MorApi.return_error('API Requests are disabled'), params[:test].to_i)
    end
  end

 # Checks if GET method is allowed.
 # *Returns*
 # Error message if method is GET and it is not allowed

  def check_send_method
    if request.get? and Confline.get_value('Allow_GET_API').to_i != 1
      send_xml_data(MorApi.return_error('GET Requests are disabled'), params[:test].to_i)
    end
  end

 # Sends XML or HTML data. Checks confline XML_API_Extension to determin whitch should be sent.

  def send_xml_data(out_string, test = 0, name = 'mor_api_response.xml', zip = false)
    xml_api_Extension = Confline.get_value('XML_API_Extension', 0).to_i == 1
    if test.to_i == 1
      MorLog.my_debug out_string
      if xml_api_Extension
        render :xml => out_string and return false
      else
        render :text => out_string and return false
      end
    else
      if !zip # or out_string.length.to_i < Confline.get_value('Api_response_size').to_i
        if xml_api_Extension
          send_data(out_string, type: 'text/xml', filename: name)
        else
          send_data(out_string, type: 'text/html', filename: 'mor_api_response.html')
        end
      else
        file_name = xml_api_Extension ? 'mor_api_response.xml' : 'mor_api_response.html'
        path = '/tmp'
        `rm -rf #{path}/#{file_name}`
        ff = File.open('/tmp/' + file_name, 'wb')
        ff.write(out_string)

        ff.close
        `rm -rf #{path}/#{file_name}.zip`
        `cd #{path}; zip #{file_name}.zip #{file_name}`
        `rm -rf #{path}/#{file_name}`
        fsrc = "#{path}/#{file_name}.zip"
        send_data(File.open(fsrc).read, filename: fsrc, type: 'application/zip')
      end
    end
  end

  def check_user(login = '')
    @user = User.where(username: login.to_s).first

    User.current = @user if @user

    @user
  end

  def check_user_for_login(username = nil, password = nil)
    @user = User.where(username: username.to_s, password: Digest::SHA1.hexdigest(password.to_s)).first

    User.current = @user if @user

    @user
  end

  # Log method. Used for all API requests.
  def log_access
    MorLog.my_debug(" ********************** API ACCESS : #{params[:action]} **********************", 1)
    MorLog.my_debug request.url.to_s
    MorLog.my_debug request.remote_addr.to_s
    MorLog.my_debug request.remote_ip
  end

  def last_calls_stats_set_variables(options, values)
    options.merge(values.reject { |key, value| !value })
  end

  def last_calls_stats_parse_params
    default = {
        s_direction: 'outgoing',
        s_call_type: 'all',
        s_origination_point: 'all',
        s_termination_point: 'all',
        s_hgc: 0,
        s_user: 'all',
        user: nil,
        s_destination: '',
        order_by: 'time',
        order_desc: 0,
        s_country: ''
    }

    options = default
    default.each { |key, value| options[key] = params[key] if params[key] }

    options[:order_by_full] = options[:order_by] + (options[:order_desc] == 1 ? ' DESC' : ' ASC')
    options[:order] = Call.calls_order_by(params, options)
    options[:direction] = options[:s_direction]
    options[:call_type] = options[:s_call_type]
    options[:destination] = (options[:s_destination].to_s.strip.match(/\A[0-9%]+\Z/) ? options[:s_destination].to_s.strip : '')
    options[:column_dem] = '.'

    options
  end

  def find_current_user_for_api
    @current_user = check_user(params[:u])
    unless @current_user
      send_xml_data(MorApi.return_error('Bad login'), params[:test].to_i)
      return false
    end

    begin
      Time.zone = @current_user.time_zone if @current_user
    rescue => error
    end
  end

  def check_api_params_with_hash
    params_action = params[:action]
    allow, @values = MorApi.hash_checking(params, request, params_action, @user)

    unless allow
      error_string = (@values[:key] == '') ? 'API must have Secret Key' : 'Incorrect hash'
      send_xml_data(MorApi.return_error(error_string), params[:test].to_i)
      return false
    end
  end

  def check_elastic_status
    errors = false

    begin
      es = Elasticsearch.search_m2_calls
    rescue SocketError
      errors = true
    rescue Errno::ECONNREFUSED
      errors = true
    rescue Errno::EHOSTUNREACH
      errors = true
    end

    if es.try(:[], 'error').present?
      errors = true
    end

    if errors
      send_xml_data(MorApi.return_error('Cannot connect to Elasticsearch'), params[:test].to_i)
      return false
    end
  end

  def flash_status(doc, msg, success = nil)
    doc.status { success ? doc.success(msg) : doc.error(msg) }
  end

  def find_dg(prefix)
    return nil if prefix.empty?
    destination = Destination.where(prefix: prefix).first
    if destination
      destination_group = destination.destinationgroup
      return destination_group if destination_group
    end
    find_dg(prefix[0...-1])
  end

  def validate_device_details_get
    @user = User.where(username: params[:u]).first
    @device = Device.where(id: params[:device_id]).first

    error = if !@user
              'Access Denied'
            elsif !can_view_device_details(@user)
              'You are not authorized to view this page'
            elsif @user.usertype == 'manager' && !authorize_manager_permissions({controller: :devices, action: :devices_all, no_redirect_return: 1, user: @user})
              'You are not authorized to manage devices'
            elsif !@device
              'Device was not found'
            end
    error
  end

  def can_view_device_details(user)
    !user.is_user?
  end

  # Before filter to hide some api methods #12203
  def no_such_api
    send_xml_data(MorApi.return_error('There is no such API'), params[:test].to_i)
  end
end
