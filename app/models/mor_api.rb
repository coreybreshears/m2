# -*- encoding : utf-8 -*-
# MOR reused API for M2
class MorApi
  require 'builder/xmlbase'

  def MorApi.check_params_with_key(params, request)
      # Hack find user from params u and p
      user = User.where(username: params[:u].to_s).first

      ret = {}
      ret[:user_id] = params[:user_id].to_i if params[:user_id] and params[:user_id].to_s !~ /[^0-9]/ and params[:user_id].to_i >= 0
      ret[:request_hash] = params[:hash].to_s if params[:hash] and params[:hash].to_s.length == 40
      ret[:period_start] = params[:period_start].to_i if params[:period_start] and params[:period_start].to_s !~ /[^0-9]/
      ret[:period_end] = params[:period_end].to_i if params[:period_end] and params[:period_end].to_s !~ /[^0-9]/
      ret[:direction] = params[:direction].to_s if params[:direction] and (params[:direction].to_s == 'outgoing' or params[:direction].to_s == 'incoming')
      ret[:calltype] = params[:calltype].to_s if params[:calltype] and ['all', 'answered', 'busy', 'no_answer', 'failed', 'missed', 'missed_inc', 'missed_inc_all', 'missed_not_processed_inc'].include?(params[:calltype].to_s)
      ret[:device] = params[:device].to_s if params[:device] and (params[:device].to_s !~ /[^0-9]/ or params[:device].to_s == 'all')
      ret[:balance] = params[:balance] if params[:balance] and params[:balance].to_s !~ /[^0-9.\-\+]/
      ret[:users] = params[:users].to_s if params[:users] and (params[:users] =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
      ret[:block] = params[:block].to_s if params[:block] and (params[:block] =~ /true|false/)
      ret[:email] = params[:email].to_s if params[:email] and (params[:email] =~ /true|false/)
      ret[:mtype] = params[:mtype].to_s if params[:mtype] and (params[:mtype] !~ /[^0-9]/)
      ret[:tariff_id] = params[:tariff_id].to_i if params[:tariff_id] and (params[:tariff_id].to_s !~ /[^0-9]/)

      ret[:key] = Confline.get_value('API_Secret_Key', user ? user.get_correct_owner_id : 0).to_s
      string =
          ret[:user_id].to_s +
              ret[:period_start].to_s +
              ret[:period_end].to_s +
              ret[:direction].to_s+
              ret[:calltype].to_s+
              ret[:device].to_s+
              ret[:balance].to_s+
              ret[:users].to_s+
              ret[:block].to_s+
              ret[:email].to_s+
              ret[:mtype].to_s+
              ret[:key].to_s+
              ret[:callerid].to_s+
              ret[:pin].to_s

      ret[:system_hash] = Digest::SHA1.hexdigest(string)
      ret[:device] = nil if ret[:device] == 'all'
      ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
      ret[:balance] = params[:balance].to_d

    if Confline.get_value('API_Disable_hash_checking', user ? user.get_correct_owner_id : 0).to_i == 0
      unless ret[:system_hash].to_s == ret[:request_hash]
        MorApi.create_error_action(params, request, 'API : Incorrect hash')
      end
      return ret[:system_hash].to_s == ret[:request_hash], ret
    else
      return true, ret
    end
  end

  def MorApi.create_error_action(params, request, name)
    Action.create({user_id: -1, date: Time.now(), action: 'error', data: name, data2: (request ? request.url.to_s[0..255] : ''), data3: (request ? request.remote_addr : ''), data4: params.inspect.to_s[0..255]})
  end


  def MorApi.check_params_with_all_keys(params, request)
    #hack find user from params u and p
    user = User.where(username: params[:u].to_s).first

    MorLog.my_debug params.to_yaml
    hash = params[:hash].to_s

    ret = {}

    ret[:hash] = hash if hash && hash.length == 40

    user_id_param, hash_param, period_start_param, period_end_param  = params[:user_id], params[:hash], params[:period_start], params[:period_end]
    direction_param, calltype_param, device_param, balance_param = params[:direction], params[:calltype], params[:device], params[:balance]
    users_param, block_param, email_param, mtype_param, tariff_id_param = params[:users], params[:block], params[:email], params[:mtype], params[:tariff_id]

    ret[:user_id] = user_id_param.to_i if user_id_param && user_id_param.to_s !~ /[^0-9]/ && user_id_param.to_i >= 0
    ret[:request_hash] = hash_param.to_s if hash_param && hash_param.to_s.length == 40
    ret[:period_start] = period_start_param.to_i if period_start_param && period_start_param.to_s !~ /[^0-9]/
    ret[:period_end] = period_end_param.to_i if period_end_param && period_end_param.to_s !~ /[^0-9]/
    ret[:direction] = direction_param.to_s if direction_param && (direction_param.to_s == 'outgoing' || direction_param.to_s == 'incoming')
    ret[:calltype] = calltype_param.to_s if calltype_param && %w[all answered busy no_answer failed missed missed_inc missed_inc_all missed_not_processed_inc].include?(calltype_param.to_s)
    ret[:device] = device_param.to_s if device_param && (device_param.to_s !~ /[^0-9]/ || device_param.to_s == 'all')
    ret[:balance] = balance_param if balance_param && balance_param.to_s !~ /[^0-9.\-\+]/
    ret[:users] = users_param.to_s if users_param && (users_param =~ /^postpaid$|^prepaid$|^all$|^[0-9,]+$/)
    ret[:block] = block_param.to_s if block_param && (block_param =~ /true|false/)
    ret[:email] = email_param.to_s if email_param #and (params[:email] =~ /true|false/)
    ret[:mtype] = mtype_param.to_s if mtype_param && (mtype_param !~ /[^0-9]/)
    ret[:tariff_id] = tariff_id_param.to_i if tariff_id_param && (tariff_id_param.to_s !~ /[^0-9]/)

    %w[u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14
      u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28
      ay am ad by bm bd pswd user_warning_email_hour pgui pcsv ppdf
      recording_forced_enabled i4 tax4_enabled tax2_enabled accountant_type_invalid
      block_at_conditional tax3_enabled accountant_type tax1_value show_zero_calls
      warning_email_active compound_tax tax4_name allow_loss_calls tax3_name tax2_name
      credit tax1_name total_tax_name tax2_value tax4_value
      i1 tax3_value i2 i3 recording_enabled email_warning_sent_test
      own_providers a0 a1 a2 a3 a4 a5 a6 a7 a8 a9 forward_to
      state forward_to_device external_number device_callerid src_callerid custom fax_device].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:s_user] = params[:s_user] if params[:s_user] && params[:s_user].to_s !~ /[^0-9]/
    ret[:s_call_type] = params[:s_call_type] if params[:s_call_type]
    ret[:s_origination_point] = params[:s_origination_point] if params[:s_origination_point] && (params[:s_origination_point].to_s !~ /[^0-9]/ || params[:s_origination_point].to_s == 'all')
    ret[:s_termination_point] = params[:s_termination_point] if params[:s_termination_point] && (params[:s_termination_point].to_s !~ /[^0-9]/ || params[:s_termination_point].to_s == 'all')
    ret[:s_hgc] = params[:s_hgc] if params[:s_hgc] && (params[:s_hgc].to_s !~ /[^0-9]/ || params[:s_hgc].to_s == 'all')

    %w[s_destination order_by order_desc description pin type phonebook_id number name speeddial].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }
    params_dst = params[:dst]
    params_src = params[:src]
    params_message = params[:message]
    params_caller_id = params[:caller_id]
    params_device_id = params[:device_id]
    params_provider_id = params[:provider_id]
    ret[:s_user_id] = params[:s_user_id] if params[:s_user_id] && params[:s_user_id].to_s !~ /[^0-9]/
    ret[:s_from] = params[:s_from] if params[:s_from] && params[:s_from].to_s !~ /[^0-9]/
    ret[:s_till] = params[:s_till] if params[:s_till] && params[:s_till].to_s !~ /[^0-9]/
    ret[:dst] = params_dst.to_s if params_dst
    ret[:src] = params_src.to_s if params_src
    ret[:message] = params_message.to_s if params_message
    ret[:caller_id] = params_caller_id.to_s if params_caller_id
    ret[:device_id] = params_device_id.to_s if params_device_id
    ret[:provider_id] = params_provider_id.to_s if params_provider_id

    %w[s_transaction s_completed s_username s_first_name s_last_name s_paymenttype s_amount_max s_currency s_number s_pin
     p_currency paymenttype tax_in_amount amount_in_tax amount transaction payer_email shipped_at fee id quantity callerid
     status date_from date_till dst src message caller_id device_id].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    # adding send email params
    %w[server_ip device_type device_username device_password login_url login_username username first_name
     last_name full_name nice_balance warning_email_balance nice_warning_email_balance
     currency user_email company_email company primary_device_pin login_password user_ip
     date auth_code transaction_id customer_name company_name url trans_id
     cc_purchase_details payment_amount payment_payer_first_name
     payment_payer_last_name payment_payer_email payment_seller_email payment_receiver_email payment_date payment_free
     payment_currency payment_type payment_fee call_list email_name email_to_user_id caller_id device_id calldate source destination billsec calls_string].each { |key|
      ret[key.to_sym] = params[key.to_sym] if params[key.to_sym]
    }

    ret[:key] = Confline.get_value('API_Secret_Key', user ? user.get_correct_owner_id : 0).to_s
    # for future: notice - users should generate hash in same order.
    string = ''

    hash_param_order = ['user_id', 'period_start', 'period_end', 'direction', 'calltype', 'device', 'balance', 'users', 'block', 'email', 'mtype', 'tariff_id', 'u0', 'u1', 'u2', 'u3', 'u4', 'u5', 'u6', 'u7', 'u8', 'u9', 'u10', 'u11', 'u12', 'u13', 'u14', 'u15', 'u16', 'u17', 'u18', 'u19', 'u20', 'u21', 'u22', 'u23', 'u24', 'u25', 'u26', 'u27', 'u28', 'ay', 'am', 'ad', 'by', 'bm', 'bd', 'pswd', 'user_warning_email_hour', 'pgui', 'pcsv', 'ppdf', 'recording_forced_enabled', 'i4', 'tax4_enabled', 'tax2_enabled', 'accountant_type_invalid', 'block_at_conditional', 'tax3_enabled', 'accountant_type', 'tax1_value', 'show_zero_calls', 'warning_email_active', 'compound_tax', 'tax4_name', 'allow_loss_calls', 'tax3_name', 'tax2_name', 'credit', 'tax1_name', 'total_tax_name', 'tax2_value', 'tax4_value', 'i1', 'tax3_value', 'i2', 'i3', 'recording_enabled', 'email_warning_sent_test', 'own_providers', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 's_user', 's_call_type', 's_origination_point', 's_termination_point', 's_hgc', 's_destination', 'order_by', 'order_desc', 'description', 'pin', 'type', 'phonebook_id', 'number', 'name', 'speeddial', 's_user_id', 's_from', 'provider_id',
                        's_till', 's_transaction', 's_completed', 's_username', 's_first_name', 's_last_name', 's_paymenttype', 's_amount_max', 's_currency', 's_number', 's_pin',
                        'p_currency', 'paymenttype', 'tax_in_amount', 'amount', 'transaction', 'payer_email', 'fee', 'id', 'quantity', 'callerid', 'status', 'date_from', 'date_till', 'dst', 'src', 'message', "server_ip", "device_type", "device_username", "device_password", "login_url", "login_username", "username", "first_name", "last_name", "full_name", "nice_balance", "warning_email_balance", "nice_warning_email_balance", "currency", "user_email", "company_email", "company", "primary_device_pin", "login_password", "user_ip", "date", "auth_code", "transaction_id", "customer_name", "company_name", "url", "trans_id", "cc_purchase_details", "payment_amount", "payment_payer_first_name", "payment_payer_last_name", "payment_payer_email", "payment_seller_email", "payment_receiver_email", "payment_date", "payment_free",
                        "payment_currency", "payment_type", "payment_fee", "call_list", 'email_name', 'email_to_user_id', 'caller_id', 'device_id', "calldate", "source", "destination", "billsec", 'calls_string', 'forward_to',
                        'state', 'forward_to_device', 'external_number', 'device_calerid', 'src_callerid', 'custom', 'fax_device']
    [hash_param_order, ret, params]
  end

  def self.compare_system_and_hashes(hash_params, ret, params, request, current_user = nil)
    user = current_user
    controller_name = params[:controller].to_s

    if controller_name != 'api' && user.blank?
      user = if params[:u].present?
               User.where(username: params[:u].to_s).first
             elsif params[:id].present? && controller_name.to_s != 'test'
               User.where(uniquehash: params[:id].to_s).first
             else
               User.first
             end
    end

    owner_id = user ? user.get_correct_owner_id_for_api : 0
    ret[:no_user] = true if user.blank?
    string = ''

    # For backwards compatibility we do not include u = admin in to the hash,
    # but all others u are included for security reasons
    hash_params = [] if (ret[:action] == 'quickstats_get' || (ret[:api_path].present? &&
      ret[:api_path].include?('quickstats_get'))) && ret[:u] == 'admin'

    hash_params.each { |key|
      MorLog.my_debug key if ret[key.to_sym]
      string << ret[key.to_sym].to_s
    }

    api_is_allowed = Confline.get_value('Allow_API', user.try(:get_correct_owner_id_for_api).to_i).to_i == 1
    if (api_is_allowed)
      ret[:key] = Confline.get_value('API_Secret_Key', owner_id).to_s
      string << ret[:key]
      ret[:system_hash] = Digest::SHA1.hexdigest(string) if ret[:key].present?
    end

    ret[:device] = nil if ret[:device] == 'all'
    ret[:calltype] = 'no answer' if ret[:calltype] == 'no_answer'
    ret[:balance] = params[:balance].to_d
    hashes_match = (ret[:system_hash].present? && ret[:system_hash].to_s == ret[:hash].to_s)

    if (api_is_allowed &&
        Confline.get_value('API_Disable_hash_checking', owner_id).to_i == 1)
      [true, ret, hash_params]
    else
      if ret[:key].present?
        unless hashes_match
          MorApi.create_error_action(params, request, 'API : Incorrect hash')
        end
      else
        MorApi.create_error_action(params, request, 'API : API must have Secret key')
      end
      [hashes_match, ret, hash_params]
    end
  end


=begin
  This is THE method to add error string to xml object.

  *Params*
  +string+ - error message
  +xml_object+ - xml object to return with error message.

  *Returns*
  +xml+
  or
  +xml object+
=end
  def MorApi.return_error(string, doc = nil)
    if doc
      doc.status { doc.error(string) }
      return doc
    else
      doc = Builder::XmlMarkup.new(target: out_string = '', indent: 2)
      doc.instruct! :xml, version: '1.0', encoding: 'UTF-8'
      doc.status { doc.error(string) }
      return out_string
    end
  end

  def MorApi.list_device_content(doc, device)
    m2_device_excluded_settings = %w[location_id regseconds voicemail_active primary_did_id works_not_logged forward_to
      record transfer disallow allow deny permit nat qualify fullcontact canreinvite
      devicegroup_id dtmfmode callgroup pickupgroup fromuser fromdomain trustrpid sendrpid
      progressinband videosupport istrunk cid_from_dids pin tell_balance tell_time
      tell_rtime_when_left repeat_rtime_every t38pt_udptl regserver ani promiscredir
      process_sipchaninfo temporary_id lastms faststart h245tunneling latency recording_to_email
      recording_keep recording_email record_forced fake_ring save_call_log mailbox enable_mwi
      authuser requirecalltoken language use_ani_for_cli calleridpres reg_status forward_did_id
      anti_resale_auto_answer qf_tell_balance qf_tell_time time_limit_per_day control_callerid_by_cids
      callerid_advanced_control transport subscribemwi encryption block_callerid tell_rate trunk
      proxy_port timerb defaultuser useragent type remotesecret directmedia useclientcode
      setvar amaflags callcounter busylevel allowoverlap allowsubscribe maxcallbitrate
      rfc2833compensate session-timers session-expires session-minse session-refresher context
      t38pt_usertpsource regexten defaultip rtptimeout rtpholdtimeout outboundproxy
      callbackextension timert1 qualifyfreq constantssrc contactpermit contactdeny usereqphone
      textsupport faxdetect buggymwi auth fullname trunkname cid_number callingpres
      mohinterpret mohsuggest parkinglot hasvoicemail vmexten autoframing rtpkeepalive
      call-limit g726nonstandard ignoresdpversion allowtransfer dynamic extension md5secre]

    Device.columns.each do |column_object|
      # Exclude non M2 settings
      unless m2_device_excluded_settings.include? column_object.name
        column = column_object.name
        add_tag(doc, column, device[column].to_s)
      end
    end
  end

  def self.hash_checking(params, request, params_action, current_user = nil)
    if ApiRequiredParams.method_is_defined_in_required_params_module(params_action)
      hash_params, ret = [ApiRequiredParams.get_required_params_for_api_method(params_action), params]
    else
      hash_params, ret, params = self.check_params_with_all_keys(params, request)
    end
    self.compare_system_and_hashes(hash_params, ret, params, request, current_user)
  end

  def MorApi.list_codecs(doc, device)
    device_codecs = device.codecs
    # lambda which checks if codecs are available for device
    active = lambda { |codec| codec if device_codecs.include?(codec) }

    # lambda that creates [audio/video] xml tag
    list = lambda do |codec_type|
      codecs =  device.codecs_order(codec_type).select(&active)
      # web browsers do not escape 'video' tag, so that it is necessary to change it to 'video_codecs'
      tag_name = codec_type + '_codecs'
      add_tag(doc, tag_name, codecs.map(&:name).join(', '))
    end

    doc.codecs{ ['audio'].each(&list) }
  end

  def MorApi.add_tag(doc, name, content)
    doc.tag!(name){
      doc.text!(content)
    }
  end


  def MorApi.loggin_output(doc, user)
    doc.action {
      doc.name('login')
      doc.status('ok')
      doc.user_id("#{user.id.to_s}")
      doc.status_message('Successfully logged in')
    }
    return doc
  end

  def MorApi.failed_loggin_output(doc, remote_address)
    doc.action {
      doc.name('login')
      doc.status('failed')
      if Action.disable_login_check(remote_address).to_i == 0
        doc.status_message('Please wait 10 seconds before trying to login again')
      else
        doc.status_message('Login failed')
      end
    }
    return doc
  end

  def MorApi.logout_output(doc)
    doc.action {
      doc.name('logout')
      doc.status('ok')
    }
    return doc
  end

  def MorApi.failed_logout_output(doc)
    doc.action {
      doc.name('logout')
      doc.status('failed')
    }
    return doc
  end

  def MorApi.error_fro_callback(params)
    username = params[:u].to_s
    user = User.where(username: username).first

    if username.length <= 0 || !user
      return 'Not authenticated'
    else
      device = Device.where(id: params[:device]).first

      if !params[:device] || !device || (device.user_id != user.id)
        return 'Bad device'
      elsif !params[:src] || (params[:src].length <= 0)
        return 'No source'
      end

      return nil
    end
  end

  def MorApi.find_legs(device, src)
    legA = Confline.get_value('Callback_legA_CID', 0)
    legB = Confline.get_value('Callback_legB_CID', 0)
    custom_legA = Confline.get_value2('Callback_legA_CID', 0)
    custom_legB = Confline.get_value2('Callback_legB_CID', 0)

    legA_cid = (legA == 'device' ? device.callerid_number : (legA == 'custom' ? custom_legA : src))
    legB_cid = (legB == 'device' ? device.callerid_number : (legB == 'custom' ? custom_legB : src))

    legA_cid = src if legA_cid.blank?
    legB_cid = src if legB_cid.blank?

    return legA_cid, legB_cid
  end

  def self.exchange_rate_update(doc, params)
    # Only Currencies that are not updated automatically can be used in this API
    curr = Currency.find_by(name: params[:currency].to_s, curr_update: 0)
    return doc.error 'Currency was not found' unless curr

    curr.exchange_rate = params[:rate]
    return doc.error 'Exchange rate is invalid' unless curr.save

    doc.success 'Currency successfully updated'
  end

  def MorApi.aggregate_data_format(params, options)
    checkboxes = %i(price_orig_show price_term_show billed_time_orig_show billed_time_term_show
                    duration_show acd_show calls_answered_show asr_show calls_total_show group_by_originator
                    group_by_op group_by_terminator group_by_tp group_by_dst_group group_by_dst pdd_show)
    group_params = %i(group_by_originator group_by_op
                      group_by_terminator group_by_tp group_by_dst_group group_by_dst)

    default = group_params.none? { |group| params[group].to_i == 1 }

    checkboxes.each do |check|
      options[check] = if default
                         %i(group_by_op group_by_tp group_by_dst).member?(check) ? 0 : 1
                       else
                         group_params.member?(check) ? params[check].to_i : 1
                       end
    end
    options
  end

  def MorApi.aggregate_data_output(data, doc, user)
    data_table_rows = data[:table_rows]
    group_by_originator = data[:options][:group_by].include?(:originator)
    if data_table_rows.present?
      doc.aggregates do
        data_table_rows.each do |val|
          doc.aggregate do
            val.each do |key, value|
              key = key.to_s
              if key.include?('duration') || key == 'acd'
                value = value.ceil
              end
              doc_tag = doc.tag!(key, value)
              if key == 'billed_originator_with_tax'
               doc_tag if group_by_originator
             else
              doc_tag
            end
          end
        end
      end
    end
    doc.totals do
      data[:table_totals].each do |total_key, value|
        total_key = total_key.to_s
        if total_key.include?('duration') || total_key == 'acd'
          time_format = Confline.get_value('time_format', user.id)
          if time_format == '%M:%S'
            min, sec = value.split(':')
            value = min.to_i * 60 + sec.to_i
          else
            hour, min, sec = value.split(':')
            value = hour.to_i * 3600 + min.to_i * 60 + sec.to_i
          end
        end
        doc_tag = doc.tag!(total_key, value)
        if total_key == 'billed_originator_with_tax'
          doc_tag if group_by_originator
        else
          doc_tag unless total_key == 'pdd_counter'
        end
      end
    end
    else
      doc.error('No data found')
    end
    return doc
  end
end
