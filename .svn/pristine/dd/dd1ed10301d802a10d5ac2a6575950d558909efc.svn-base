# -*- encoding : utf-8 -*-
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include SqlExport
  include UniversalHelpers
  #    def ApplicationHelper::reset_values
  #      @nice_number_digits = nil
  #    end

  def tooltip(title, text, options = {})
    raw "onmouseover=\"Tip(\'#{text.to_s.gsub('"', '&quot;').gsub("'", '&#92;&#39;')}\', WIDTH, -600, TITLE, '#{title}', TITLEBGCOLOR, '#494646', FADEIN, 200, FADEOUT, 200, ESCAPEHTML, #{options[:escape_html] ? options[:escape_html] : false} )\" onmouseout = \"UnTip()\"".html_safe
  end

  def tooltip_with_wrap(text, options = {})
    raw "onmouseover=\"Tip(\'<div style = &quot;white-space: initial;&quot>#{text.to_s.gsub('"', '&quot;').gsub("'", '&#92;&#39;')}</div>\', WIDTH, -600, FADEIN, 200, FADEOUT, 200, ESCAPEHTML, #{options[:escape_html] ? options[:escape_html] : false} )\" onmouseout = \"UnTip()\"".html_safe
  end

  def link_tooltip(title, text)
    {
      onmouseover: "Tip(' #{text.to_s.gsub('"', '&quot;').gsub("'", '&#92;&#39;')} ', WIDTH, -600, TITLE, '#{title}', TITLEBGCOLOR, '#494646', FADEIN, 200, FADEOUT, 200 )",
      onmouseout: 'UnTip()'
    }
  end

  def draw_flag(country_code)
    image_tag('/images/flags/' + country_code.to_s.downcase + '.jpg', style: 'border-style:none', title: country_code.to_s.upcase) if country_code.present?
  end

  def draw_flag_by_code(flag)
    image_tag('/images/flags/' + flag + '.jpg', style: 'border-style:none', title: flag.upcase) if flag.present?
  end

  def nice_time2(time)
    format = if user?
               '%H:%M'
             else
               session[:time_format].to_s.presence || '%H:%M:%S'
             end

    nice_time = time.respond_to?(:strftime) ? time : ('2000-01-01 ' + time.to_s).to_time
    nice_time.strftime(format.to_s) if time
  end

  def nice_date_time(time, options = {})
    if time
      format = if options
                 options[:date_time_format].to_s.presence || '%Y-%m-%d %H:%M:%S'
               else
                 session[:date_time_format].to_s.presence || '%Y-%m-%d %H:%M:%S'
               end
      time = time.respond_to?(:strftime) ? time : time.to_time
      date = time.strftime(format.to_s)
    end
    date
  end

  def nice_user_time_string(user)
    user_zone = ActiveSupport::TimeZone.new(user.time_zone.to_s)
    "(GMT#{user_zone.now.formatted_offset}) #{user_zone.name}" if user_zone.present?
  end

  def nice_system_time_string
    Time.now.zone.include?('(GMT') ? ActiveSupport::TimeZone[Time.now.zone] : "(GMT#{Time.now.formatted_offset}) #{Time.now.zone}"
  end

  def nice_date(date, options = {})
    if date
      format = if options
                 options[:date_format].to_s.presence || '%Y-%m-%d'
               else
                 session[:date_format].to_s.presence || '%Y-%m-%d'
               end
      time = date.respond_to?(:strftime) ? date : date.to_time
      if format.to_s.include?('H')
        @date = format.to_s.split(' ')
        format = (@date[0] == '00:00:00') ? @date[1].to_s : @date[0].to_s
      end
      n_date = time.strftime(format.to_s)
    end
    n_date
  end

  def nice_number(number, options = {})
    number = nil unless number.to_f.finite? # infinity -> nil
    n = '0.00'
    if options[:nice_number_digits]
      n = sprintf("%0.#{options[:nice_number_digits]}f", number.to_d.round(options[:nice_number_digits])) if number
      if options[:change_decimal]
        n = n.gsub('.', options[:global_decimal])
      elsif defined?(session) && session[:change_decimal]
        n = n.gsub('.', session[:global_decimal])
      end
    else
      nice_number_digits = (session && session[:nice_number_digits]) || Confline.get_value('Nice_Number_Digits')
      nice_number_digits = 2 if nice_number_digits.blank?
      n = sprintf("%0.#{nice_number_digits}f", number.to_d.round(nice_number_digits)) if number
      n = n.gsub('.', session[:global_decimal]) if session && session[:change_decimal]
    end
    n
  end

  def long_nice_number(number)
    numb = ''
    numb = sprintf('%0.6f', number) if number
    numb = numb.gsub('.', session[:global_decimal]) if session[:change_decimal]
    numb
  end

  def nice_bytes(bytes = 0, sufix_stop = '')
    bytes = bytes.to_d
    sufix_pos = 0
    sufix = %w[b Kb Mb Gb Tb]
    if sufix_stop == '' || sufix.exclude?(sufix_stop)
      while bytes >= 1024
        bytes /= 1024
        sufix_pos += 1
      end
    else
      while sufix[sufix_pos] != sufix_stop
        bytes /= 1024
        sufix_pos += 1
      end
    end
    session[:nice_number_digits] ||= Confline.get_value('Nice_Number_Digits').to_i
    session[:nice_number_digits] ||= 2
    bytes = 0 unless bytes
    num = sprintf("%0.#{session[:nice_number_digits]}f", bytes.to_d) + ' ' + sufix[sufix_pos].to_s
    num = num.gsub('.', session[:global_decimal]) if session[:change_decimal]
    num
  end

  def nice_number_currency(number, exchange_rate = 1)
    number *= exchange_rate.to_d if number
    num = ''
    num = sprintf("%0.#{session[:nice_number_digits]}f", number) if number.present?
    num = num.gsub('.', session[:global_decimal]) if session[:change_decimal]

    num
  end

  def nice_currency(number, exchange_rate = 1, options = {})
    number *= exchange_rate.to_d
    session[:nice_currency_digits] ||= Confline.get_value('Nice_Currency_Digits', 0, 2).to_i
    digits = session[:nice_currency_digits]
    num = sprintf("%0.#{digits}f", number.to_d.round(digits))
    num = num.gsub('.', session[:global_decimal]) if session[:change_decimal]
    options[:show_symb] ? nice_currency_symb(num) : num
  end

  def nice_currency_symb(number)
    currency = session[:show_currency]
    case currency
      when 'USD'
        "$ #{number}"
      when 'EUR'
        "#{number} €"
      else
        "#{number} #{currency}"
    end
  end

  # shows nice
  def nice_src(call, options = {})
    value = Confline.get_value('Show_Full_Src')
    srt = call.clid.split(' ')
    name = srt[0..-2].join(' ').to_s.delete('"')
    number = call.src.to_s
    session[:show_full_src] ||= value if options[:pdf].to_i == 0
    (value.to_i == 1 && !name.empty?) ? "#{number} (#{name})" : number.to_s
  end

  # converting caller id like "name" <11> to 11
  def cid_number(cid)
    if cid && cid.index('<') && cid.index('>')
      cid = cid[cid.index('<') + 1, cid.index('>') - cid.index('<') - 1]
    else
      cid = ''
    end
    cid
  end

  def session_from_date
    sfd = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s)
  end

  def session_till_date
    sfd = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s)
  end

  def session_from_datetime
    sfd = session[:year_from].to_s + '-' + good_date(session[:month_from].to_s) + '-' + good_date(session[:day_from].to_s) + ' ' + good_date(session[:hour_from].to_s) + ':' + good_date(session[:minute_from].to_s) + ':00'
  end

  def session_till_datetime
    sfd = session[:year_till].to_s + '-' + good_date(session[:month_till].to_s) + '-' + good_date(session[:day_till].to_s) + ' ' + good_date(session[:hour_till].to_s) + ':' + good_date(session[:minute_till].to_s) + ':59'
  end

  def nice_month_name(month_number)
    {
      '1' => _('January'),
      '2' => _('February'),
      '3' => _('March'),
      '4' => _('April'),
      '5' => _('May'),
      '6' => _('June'),
      '7' => _('July'),
      '8' => _('August'),
      '9' => _('September'),
      '10' => _('October'),
      '11' => _('November'),
      '12' => _('December')
    }[month_number.to_s].to_s
  end

  # ================ BUTTONS - ICONS =============
  def b_comment_edit(title)
    image_tag('icons/comment_edit.png', title: title) + ' '
  end

  def b_sort_desc
    image_tag('icons/bullet_arrow_down.png') + ' '
  end

  def b_sort_asc
    image_tag('icons/bullet_arrow_up.png') + ' '
  end

  def b_invoice_details
    image_tag('icons/arrow_right.png') + ' ' + _('Invoice_details')
  end

  def b_server
    image_tag('icons/server.png') + ' '
  end

  def b_arrow_down_blue
    image_tag('icons/arrow_down_blue.png') + ' '
  end

  def b_arrow_up_blue
    image_tag('icons/arrow_up_blue.png') + ' '
  end

  def b_add
    image_tag('icons/add.png', title: _('Add')) + ' '
  end

  def b_delete(options = {})
    opts = {title: _('Delete')}.merge(options)
    image_tag('icons/delete.png', title: opts[:title]) + ' '
  end

  def b_unassign(options = {})
    opts = {title: _('Unasssign user')}.merge(options)
    # TODO: get sutable icon, maybe user_delete
    image_tag('icons/user_delete.png', title: opts[:title]) + ' '
  end

  def b_hangup
    image_tag('icons/delete.png', title: _('Hangup')) + ' '
  end

  def b_edit
    image_tag('icons/edit.png', title: _('Edit')) + ' '
  end

  def b_back
    image_tag('icons/back.png', title: _('Back')) + ' '
  end

  def b_view
    image_tag('icons/view.png', title: _('View')) + ' '
  end

  def b_details(txt = ' ')
    image_tag('icons/details.png', title: _('Details')) + txt
  end

  def b_user
    image_tag('icons/user.png', title: _('User')) + ' '
  end

  def b_reseller
    image_tag('icons/user_gray.png', title: _('Reseller')) + ' '
  end

  def b_user_gray(options = {})
    opts = {title: _('User')}.merge(options)
    image_tag('icons/user_gray.png', title: opts[:title]) + ' '
  end

  def b_chart_bar(options = {})
    opts = {title: _('Info')}.merge(options)
    image_tag('icons/chart_bar.png', title: opts[:title]) + ' '
  end

  def b_info(options = {})
    opts = {title: _('Info')}.merge(options)
    image_tag('icons/information.png', title: opts[:title]) + ' '
  end

  def b_info_dark(options = {})
    opts = {title: _('Info')}.merge(options)
    image_tag('icons/information_dark.png', title: opts[:title]) + ' '
  end

  def b_forward
    image_tag('icons/forward.png', title: '') + ' '
  end

  def b_play
    image_tag('icons/play.png', title: _('Play')) + ' '
  end

  def b_download
    image_tag('icons/download.png', title: _('Download')) + ' '
  end

  def b_record
    image_tag('icons/music.png', title: _('Recording')) + ' '
  end

  def b_device
    image_tag('icons/device.png', title: _('Connection_Points')) + ' '
  end

  def b_arrow_out(options = {})
    image_tag('icons/arrow_out.png', title: options[:title])
  end

  def b_check(options = {})
    options[:id] = 'icon_chech_' + options[:id].to_s if options[:id]
    image_tag('icons/check.png', {title: 'check'}.merge(options)) + ' '
  end

  def b_copy(options = {})
    options[:id] = 'icon_chech_' + options[:id].to_s if options[:id]
    image_tag('icons/page_copy.png', {title: _('copy')}.merge(options)) + ' '
  end

  def b_csv
    image_tag('icons/excel.png', title: _('CSV')) + ' '
  end

  def b_xlsx(options = {})
    options[:title] = _('XLSX') unless options.has_key?(:title)
    image_tag('icons/excel.png', title: options[:title]) + ' '
  end

  def b_pdf
    image_tag('icons/pdf.png', title: _('PDF')) + ' '
  end

  def b_cross(options = {})
    options[:id] = 'icon_cross_' + options[:id].to_s if options[:id]
    image_tag('icons/cross.png', {title: 'cross'}.merge(options)) + ' '
  end

  def b_cross_disabled(options = {})
    options[:id] = 'icon_cross_' + options[:id].to_s if options[:id]
    image_tag('icons/cross_disabled.png', {title: 'disabled'}.merge(options)) + ' '
  end

  # temporarily commented functionality

  # def b_bullet_white(title='')
  #   image_tag('icons/bullet_white.png', :title => title) + " "
  # end

  # def b_bullet_red(title='')
  #   image_tag('icons/bullet_red.png', :title => title) + " "
  # end

  # def b_bullet_yellow(title='')
  #   image_tag('icons/bullet_yellow.png', :title => title) + " "
  # end

  # def b_bullet_black(title='')
  #   image_tag('icons/bullet_black.png', :title => title) + " "
  # end

  # def b_bullet_green(title='')
  #   image_tag('icons/bullet_green.png', :title => title) + " "
  # end

  def b_help_grey
    image_tag('icons/help_grey.png', title: '') + ' '
  end

  def b_help
    image_tag('icons/help.png', title: '') + ' '
  end

  def b_money
    image_tag('icons/money.png', title: _('Add_manual_payment')) + ' '
  end

  def b_groups
    image_tag('icons/groups.png', title: _('Groups')) + ' '
  end

  def b_rates
    image_tag('icons/coins.png', title: _('Rates')) + ' '
  end

  def b_actions(options = {})
    image_tag('icons/actions.png', {title: _('termination_point')}.merge(options)) + ' '
  end

  def b_dial_peers_action(options = {})
    image_tag('icons/actions.png', {title: _('dial_peers')}.merge(options)) + ' '
  end

  def b_undo
    image_tag('icons/undo.png', title: _('Undo')) + ' '
  end

  def b_providers
    image_tag('icons/provider.png', title: _('Providers')) + ' '
  end

  def b_provider_ani
    image_tag('icons/provider_ani.png', title: _('Provider_with_ANI')) + ' '
  end

  def b_date
    image_tag('icons/date.png', title: '') + ' '
  end

  def b_call
    image_tag('icons/call.png', title: _('calls')) + ' '
  end

  def b_call_info
    image_tag('icons/information.png', title: _('Call_Info')) + ' '
  end

  def b_trunk
    image_tag('icons/trunk.png', title: _('Trunk')) + ' '
  end

  def b_trunk_ani
    image_tag('icons/trunk_ani.png', title: _('Trunk_with_ANI')) + ' '
  end

  def b_rates_delete
    image_tag('icons/coins_delete.png', title: _('Rates_delete')) + ' '
  end

  def b_provider
    image_tag('icons/provider.png', title: _('Provider')) + ' '
  end

  def b_currency
    image_tag('icons/money_dollar.png', title: _('Currency')) + ' '
  end

  def b_testing
    image_tag('icons/lightning.png', title: _('Testing')) + ' '
  end

  def b_exclamation(options = {})
    image_tag('icons/exclamation.png', options) + ' '
  end

  def b_extlines
    image_tag('icons/asterisk.png', title: _('Extlines')) + ' '
  end

  def b_online
    image_tag('icons/status_online.png', title: _('Logged_in_to_GUI')) + ' '
  end

  def b_offline
    image_tag('icons/status_offline.png', title: _('Not_Logged_in_to_GUI')) + ' '
  end

  def b_search(options = {})
    opts = {title: _('Search')}.merge(options)
    image_tag('icons/magnifier.png', opts) + ' '
  end

  def b_rules
    image_tag('icons/page_white_gear.png', title: _('Provider_rules')) + ' '
  end

  def b_login_as(options = {})
    opts = {title: _('Login_as')}.merge(options)
    image_tag('icons/application_key.png', opts) + ' '
  end

  def b_call_tracing
    image_tag('icons/lightning.png', title: _('Call_Tracing')) + ' '
  end

  def b_test
    image_tag('icons/lightning.png', title: _('Test')) + ' '
  end

  def b_primary_device
    image_tag('icons/star.png', title: _('Primary_device')) + ' '
  end

  def b_email_send
    image_tag('icons/email_go.png', title: _('Send')) + ' '
  end

  def b_email(options = {})
    opts = {title: _('Email')}.merge(options)
    image_tag('icons/email_grey.png', opts) + ' '
  end

  def b_refresh
    image_tag('icons/arrow_refresh.png', title: _('Refresh')) + ' '
  end

  def b_arrow_switch_bright_red
    image_tag('icons/arrow_switch_bright_red.png')
  end

  def b_arrow_switch_grey
    image_tag('icons/arrow_switch_grey.png')
  end

  def b_arrow_switch_light_green
    image_tag('icons/arrow_switch_light_green.png')
  end

  def b_hide
    image_tag('icons/contrast.png', title: _('Hide')) + ' '
  end

  def b_unhide
    image_tag('icons/contrast.png', title: _('Unhide')) + ' '
  end

  def b_logins
    image_tag('icons/chart_pie.png', title: _('Logins')) + ' '
  end

  def b_call_stats
    image_tag('icons/chart_bar.png', title: _('Call_Stats')) + ' '
  end

  def b_fix
    image_tag('icons/wrench.png', title: _('Fix')) + ' '
  end

  def b_virtual_device
    image_tag('icons/virtual_device.png', title: _('Virtual_Device')) + ' '
  end

  def b_cog
    image_tag('icons/cog.png') + ' '
  end

  def b_book
    image_tag('icons/book.png', title: _('Phonebook')) + ' '
  end

  def b_restore
    image_tag('icons/database_refresh.png', title: _('Restore')) + ' '
  end

  def b_download
    image_tag('icons/database_go.png', title: _('Download')) + ' '
  end

  def b_user_log
    image_tag('icons/report_user.png', title: _('User_log')) + ' '
  end

  def b_unreachable
    image_tag('unreachable.png', class: 'b_unreachable')
  end

  def b_blocked
    image_tag('blocked.png', class: 'b_blocked')
  end

  def currency_selector(diff = nil)
    currs = Currency.get_active
    out = "<table width='100%' class='simple'><tr><td align='right'>"
    currs.each do |curr|
      out += '<b>' if curr.name == session[:show_currency]
      #        if !diff
      #          out += "<a href='#{params[:action]}/#{curr.name}'>#{curr.name}</a>"
      #        else
      #          out += "<a href='?currency=#{curr.name}'>#{curr.name}</a>"
      #        end
      out += link_to(curr.name.to_s, currency: curr.name, search_on: params[:search_on])
      out += '</b>' if curr.name == session[:show_currency]
    end
    out += '</td></tr></table>'
    out
  end

  def print_tech(tech)
    if tech
      tech = Confline.get_value('Change_dahdi_to') if tech.downcase == 'dahdi' && Confline.get_value('Change_dahdi').to_i == 1
    else
      tech = ''
    end
    tech
  end

  # draws correct picture of device
  def nice_device_pic(device, options = {})
    dev = ''
    dev = b_device if device.device_type == 'SIP'
    dev = b_trunk if device.istrunk == 1 && device.ani && device.ani == 0
    dev = b_trunk_ani if device.istrunk == 1 && device.ani && device.ani == 1
    dev.html_safe
  end

  def nice_device(device, options = {})
    opts = {
      image: true,
      tech: true
    }.merge(options)
    dev = ''
    if device
      if device.description.present?
        dev << device.description.to_s
      else
        dev << "#{nice_user(User.where(id: device.user_id).first)}/#{device.host}"
      end
    end

    dev.html_safe
  end

  def nice_device_dp(device, options = {})
    opts = {
      image: true,
      tech: true
    }.merge(options)
    dev = ''
    if device
      if device.description.present?
        dev << truncate("#{nice_user(User.where(id: device.user_id).first)} - #{device.description}", length: 60)
      else
        dev << "#{nice_user(User.where(id: device.user_id).first)}/#{device.host}"
      end
    end

    dev.html_safe
  end

  def nice_device_no_pic(device)
    dev_desc = ''
    if device
      if device.description.present?
        dev_desc << device.description.to_s
      else
        dev_desc << "#{nice_user(User.where(id: device.user_id.to_i).first)}/#{device.host}"
      end
    end
    dev_desc
  end

  def nice_device_from_data(dev_type, dev_name, dev_extension, dev_istrunk, dev_ani, options = {})
    dev = ''
    unless options[:device_no_pic]
      dev = b_device if dev_type == 'SIP'
      dev = b_trunk if dev_istrunk == 1 && dev_ani == 0
      dev = b_trunk_ani if dev_istrunk == 1 && dev_ani == 1
    end
    device = Device.where(id: options[:device_id].to_i).first
    if device
      if device.description.present?
        dev << device.description.to_s
      else
        dev << "#{nice_user(User.where(id: device.user_id.to_i).first)}/#{device.host}"
      end
    end

    if options[:link] == true && options[:device_id].to_i > 0
      dev = link_to dev, controller: 'devices', action: 'device_edit', id: options[:device_id].to_i
    end
    dev
  end

  def link_nice_device(device)
    if device.user_id != -1
      raw link_to nice_device(device).html_safe, controller: 'devices', action: 'device_edit', id: device.id
    end
  end

  def link_nice_device_user(device)
    if device
      user = device.user
      if (device.user_id == session[:user_id]) || (user.owner_id == (manager? ? 0 : session[:user_id]))
        return link_nice_user(user)
      else
        owner = user.owner
        return link_user_gray(owner,
                              {title: _('This_user_belongs_to_Reseller') + ': ' + nice_user(owner)}
        ) + nice_user(user)
      end
    end
  end

  def to_utf(str = nil)
    if str
      str.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') if str.is_a? String
    else
      self.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') if self.is_a? String
    end
  end

  def nice_user_by_id(user_id)
    user = User.where(id: user_id).first
    nice_user(user)
  end

  def link_nice_user_if_own(user)
    user = User.where(id: user).first if user.class != User
    if user
      (user.owner_id == correct_owner_id && user.usertype != 'admin') ? link_nice_user(user) : nice_user(user)
    else
      ''
    end
  end

  def link_nice_user(user, options = {}, html_options = {})
    raw link_to nice_user(user).html_safe, {controller: 'users', action: 'edit', id: user.id}.merge(options), html_options
  end

  def link_nice_dial_peer(dial_peer)
    link_to(dial_peer.name, controller: :dial_peers, action: :edit, id: dial_peer.id)
  end

  def link_routing_group(routing_group)
    link_to(routing_group.name, controller: :routing_groups, action: :edit, id: routing_group.id)
  end

  def link_rgroup_dpeers(routing_group, rgdp = nil)
    name = routing_group.name
    name += " (#{rgdp})" if rgdp
    out = "<b style='margin-left:4px;'>#{b_details} #{_('Dial_peers_list')}: </b>"
    out << link_to(name.to_s, controller: :routing_groups, action: :rgroup_dpeers_list, id: routing_group.id)
    out << '<br/><br/>'
  end

  def link_nice_user_by_id(user_id)
    user = User.where(id: user_id).first
    link_nice_user(user)
  end

  def link_user_gray(user, options = {})
    link_to b_user_gray({title: options[:title]}), {controller: 'users', action: 'edit', id: user.id}.merge(options.except(:title))
  end

  # temporarily commented functionality

  # def nice_server_from_data(server, options = {})
  #   ns = h(server.to_s)
  #   if options[:link] and options[:server_id].to_i > 0
  #     ns = link_to ns, :controller => :servers, :action => :edit, :id => options[:server_id].to_i
  #   end
  #   ns
  # end

  def nice_server(server)
    if server
      _('Server') + '_' + server.id.to_s + ': ' + server.server_ip.to_s + '|' + server.hostname.to_s
    end
  end

  def confline(name, id = 0)
    MorLog.my_debug('confline from application_helper.rb is deprecated. Use Confline.get_value')
    MorLog.my_debug("Called_from :: #{caller[0]}")
    Confline.get_value(name, id)
  end

  def flag_list
    fl = ''
    if session[:tr_arr] && session[:tr_arr].size > 1
      session[:tr_arr].each do |tr|
        title = tr.name
        title += "/#{tr.native_name}" if !tr.native_name.empty?
        fl += "<a href='?lang=" + tr.short_name + "'> " + image_tag("/images/flags/#{tr.flag}.jpg", style: 'border-style:none', title: title) + '</a>'
      end
    end
    fl
  end

  def device_code(code)
    name = 'Default_device_codec_' + code.to_s
    Confline.get_value(name, corrected_user_id)
  end

  # ================ DEBUGGING =============

  # put value into file for debugging
  def my_debug(msg)
    File.open(Debug_File, 'a') do |file|
      file << msg.to_s
      file << "\n"
    end
  end

  # Helper tha formats call debug info to be shown on a tooltip.
  def format_debug_info(hash)
    debug_text = 'PeerIP: ' + hash['peerip'].to_s + '<br>'
    debug_text += 'RecvIP: ' + hash['recvip'].to_s + '<br>'
    debug_text += 'SipFrom: ' + hash['sipfrom'].to_s + '<br>'
    debug_text += 'URI: ' + hash['uri'].to_s + '<br>'
    debug_text += 'UserAgent: ' + hash['useragent'].to_s + '<br>'
    debug_text += 'PeerName: ' + hash['peername'].to_s + '<br>'
    debug_text += 'T38Passthrough: ' + hash['t38passthrough'].to_s + '<br>'
    debug_text
  end

  def clean_value(value)
    # cv = value
    # remove columns from start and end
    # cv = cv[1..cv.length] if cv[0,1] == "\""
    # cv = cv[0..cv.length-2] if cv[cv.length-1,1] == "\""
    cv = value.to_s.gsub("\"", '')
    cv
  end

  def clean_value_all(value)
    cv = value.to_s
    while cv[0, 1] == "\"" || cv[0] == "'" do
      cv = cv[1..cv.length]
    end
    while cv[cv.length - 1, 1] == "\"" || cv[cv.length - 1, 1] == "'" do
      cv = cv[0..cv.length - 2]
    end
    cv
  end

  # Returns HangupCauseCode message by code
  def get_hangup_cause_message(code)
    if session["hangup#{code.to_i}".intern]
      return session["hangup#{code.to_i}".intern].html_safe
    else
      line = Hangupcausecode.where(code: code).first
      if line
        session["hangup#{code.to_i}".intern] = line.description.html_safe
      else
        session["hangup#{code.to_i}".intern] = ('<b>' + _('Unknown_Error') + '</b><br />').html_safe
      end
      return session["hangup#{code.to_i}".intern].html_safe
    end
  end

  def calls_dc_name(dc)
    if dc.to_i < 200
      'ISDN'
    elsif dc.to_i < 800
      'SIP'
    elsif dc.to_i < 900
      'Core'
    else
      'Proxy'
    end
  end

  def get_dc_code_message(code)
    if code.to_i == 200
      return ('<b>' + _('Ok') + '</b><br />').html_safe
    elsif code.to_i < 200
      return get_hangup_cause_message(code)
    else
      code_hash = "dc_reason_#{code}".intern
      if session[code_hash]
        return session[code_hash]
      elsif (reason = DisconnectCode.where(dc_group_id: 1, code: code.to_i).first.try(:reason)).present?
        session[code_hash] = ('<b> '+ code.to_s + ' - ' + reason.to_s + '</b><br/> ').html_safe
      else
        session[code_hash] = ('<b>' + _('Unknown_Code') + '</b><br />').html_safe
      end
      return session[code_hash]
    end
  end

  # Creates link with arrow image representing table sort header.
  #
  # *Params*
  #
  # * <tt>true_col_name</tt> - true field name of sql order by. E.g. users.first_name.
  # * <tt>col_header_name</tt> - String to name the field in link. "User".
  # * <tt>options</tt> - options hash
  #
  # * <tt>options[:order_desc]</tt> - 1 : order descending     2 : order ascending
  # * <tt>options[:order_by]</tt> - string simmilar to true_col_name.
  # *Returns*
  #
  # link_to with params for ordering.

  def sortable_list_header(true_col_name, col_header_name, options)
    link_to(
        ((b_sort_desc if options[:order_by].to_s == true_col_name.to_s && options[:order_desc].to_i == 1).to_s +
            (b_sort_asc if options[:order_by].to_s == true_col_name.to_s && options[:order_desc].to_i == 0).to_s +
            col_header_name).html_safe, action: params[:action], search_on: 1, order_by: true_col_name.to_s, order_desc: (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc].to_i : 1))
  end

  def remote_sortable_list_header(true_col_name, col_header_name, options)
    # x5 rework needed
    # Previous prototype helper code that used to generate pretty much the same.
    # {:update => options[:update],
    # :url => {:controller => options[:controller].to_s, :action => options[:action].to_s, :order_by => true_col_name.to_s, :order_desc => (options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1)},
    # :loading => "Element.show('spinner');",
    # :complete => "Element.hide('spinner');"}
    raw link_to_function(
        (b_sort_desc.html_safe if options[:order_by].to_s == true_col_name.to_s && options[:order_desc] == 1).to_s.html_safe +
        (b_sort_asc.html_safe if options[:order_by].to_s == true_col_name.to_s && options[:order_desc] == 0).to_s.html_safe +
        col_header_name.html_safe,
        "new Ajax.Updater('#{options[:update]}',
                          '#{Web_Dir}/#{options[:controller].to_s}/#{options[:action].to_s}',
                          {asynchronous:true, evalScripts:true, onComplete:function(request){Element.hide('spinner');},
                          onLoading:function(request){Element.show('spinner');},
                          parameters:'order_by=#{true_col_name.to_s}&order_desc=#{options[:order_by].to_s == true_col_name ? 1 - options[:order_desc] : 1}'}
        );
        return false;",
        {class: 'sortable_column_header'}).html_safe
  end

  def nice_list_order(user_col_name, col_header_name, options, params_sort = {})
    order_dir = (options[:order_desc].to_i == 1) ? 0 : 1
    raw link_to(
            ((b_sort_desc if options[:order_desc].to_i == 1 && user_col_name.downcase == options[:order_by].to_s).to_s.html_safe +
                (b_sort_asc if options[:order_desc].to_i== 0 && user_col_name.downcase == options[:order_by].to_s).to_s.html_safe +
                col_header_name.to_s.html_safe).html_safe, {action: params[:action], order_by: user_col_name, order_desc: order_dir, search_on: params[:search_on]}.merge(params_sort), {id: "#{user_col_name}_#{order_dir}"})
  end

  def link_nice_tariff_if_own(tariff)
    if tariff
      (tariff.owner_id == correct_owner_id) ? link_nice_tariff_simple(tariff) : nice_tariff(tariff)
    else
      ''
    end
  end

  def nice_tariff(tariff)
    tariff.name
  end

  def link_nice_tariff_simple(tariff)
    if (tariff.purpose == 'user_wholesale') || (tariff.purpose == 'provider') || (tariff.purpose == 'user_custom')
      link_to tariff.name, controller: 'tariffs', action: 'rates_list', id: tariff.id, st: 'A'
    end
  end

  def link_nice_tariff(tariff, rates = nil)
    name = tariff.name
    name += " (#{rates})" if rates
    out = "#{b_details} <b>#{_('Tariff')}: </b>"
    out << link_to(name.to_s, controller: 'tariffs', action: 'rates_list', id: tariff.id, st: 'A')
  end

  def sanitize_to_id(name)
    name.to_s.gsub(']', '').gsub(/[^-a-zA-Z0-9:.]/, '_')
  end

  def ordered_list_header(true_col_name, user_col_name, col_header_name, options)
    raw link_to(
      (b_sort_desc if options[:order_by].to_s == true_col_name.to_s && options[:order_desc] == 1).to_s.html_safe +
      (b_sort_asc if options[:order_by].to_s == true_col_name.to_s && options[:order_desc] == 0).to_s.html_safe +
      _(col_header_name.to_s.html_safe), action: params[:action], search_on: 1, order_by: user_col_name.to_s,
      order_desc: (options[:order_by].to_s == true_col_name ? (1 - options[:order_desc].to_i) : 1)).html_safe
  end

 #  Generic settings group line. Can hold any helpers or HTML.
 # *Params*
 # +block+

  def settings_group_line(name, prop_name = '', tip = '', &block)
    "<div class='input-row' #{tip}><div class='label-col'><label for='#{prop_name}'>#{name}</label></div><div class='input-col'>#{block.call}</div></div>"
  end

  def settings_group_line_check(name, prop_name = '', tip = '', &block)
    "<div class='input-row' #{tip}><div class='label-col'><label for='#{prop_name}'>#{name}</label></div><div class='input-col checkbox-marg'>#{block.call}</div></div>"
  end

 # name -      text that will be dislpayed near checkbox
 # prop_name - form variable name
 # conf_name - name of confline that will be represented by checkbox.

  def setting_boolean(name, prop_name, conf_name, owner_id = 0, html_options = {}, checked = false)
    if checked && Confline.where(name: conf_name.to_s, owner_id: owner_id).first.blank?
      Confline.new_confline(conf_name.to_s, 1, owner_id)
    end
    settings_group_line_check(name, prop_name, [:tip]) {
      check_box_tag(prop_name.to_s, '1', Confline.get_value(conf_name.to_s, owner_id).to_i == 1, html_options)
    }
  end

  def settings_field(type, name, owner_id = 0, html_options = {})
    case type
      when :boolean then
        setting_boolean(_(name), name.downcase, name, owner_id, html_options)
      else
        settings_group_line('UNKNOWN TYPE', html_options[:tip]) {}
    end
  end

  # name -      text that will be dislpayed near text field
  # prop_name - form variable name
  # conf_name - name of confline that will be represented by text field.

  def settings_string(name, prop_name, conf_name, owner_id = 0, options = {})
    settings_group_line(name, prop_name, options[:html][:tip]) {
      text_field_tag(prop_name.to_s, Confline.get_value(conf_name.to_s, owner_id, options[:default]).to_s, {class: 'input', size: '35', maxlength: '50'}.merge(options[:html] || {}))
    }
  end

  def icon(name, options = {})
    opts = {class: 'icon ' + name.to_s.downcase}.merge(options)
    content_tag(:span, '', opts)
  end

  def active_call_bullet(call)
    # MorLog.my_debug(call)
    if call.class == Call
      call.answer_time.blank? ? icon('bullet_yellow') : icon('bullet_green')
    else
      call['answer_time'].blank? ? icon('bullet_yellow') : icon('bullet_green')
    end
  end

  def can_view_forgot_password?
    Confline.get_value('Email_Sending_Enabled', 0).to_i == 1 && Confline.get_value('Email_Smtp_Server', 0).to_s.present? && Confline.get_value('Show_forgot_password', session[:owner_id].to_i).to_i == 1
  end

  def link_show_devices_if_own(user, options = {})
    options[:text] ||= nice_user(user)
    if user.owner_id == correct_owner_id
      link_to(options[:text], controller: :devices, action: :show_devices, id: user.id)
    else
      options[:text]
    end
  end

  # Optional parameter `currency` should be supplied if you want to convert users credit
  # to some particular currency. Note that currency is actualy currency name, not currency object
  def nice_credit(user, currency = nil)
    if user.credit && user.postpaid?
      if user.credit_unlimited?
        credit = _('Unlimited')
      else
        exchange_rate = currency ? Currency.count_exchange_rate(user.currency.name, currency) : 1
        credit = nice_number(exchange_rate * user.credit)
      end
    else
      credit = 0
    end
    credit
  end

  # if not user returns nil
  # if user returns tooltip that contains information about user tariff, credit,,
  # country and city.
  # referencial integrity may be broken hence if user.address
  def nice_user_tooltip(user)
    if user
      user_details = raw "<b>#{_('Tariff')}:</b> #{user.try(:tariff_name)} <br> <b>#{_('Credit')}:</b> #{nice_credit(user)}".html_safe
      address_details = raw "<br> <b>#{_('Country')}:</b> #{user.try(:county)}<br> <b>#{_('City')}:</b> #{user.try(:city)}".html_safe
      tooltip('User details', (user_details + address_details).html_safe)
    end
  end

  def nice_rates_tolltip(rate)
    string = ''
    rate.ratedetails.each do |rr|
      string << "#{rate.prefix} : #{nice_time2 rr.start_time} - #{nice_time2 rr.end_time} => #{rr.rate} (#{rate.tariff.currency}) <br />"
    end
    tooltip(rate.tariff.name, string)
  end

  def device_reg_status(device)
    out = ''
    icon = ''
    device.reg_status = device.reg_status.to_s

    return out if device.reg_status.empty?

    if device.reg_status[0..1] == 'OK'
      icon = 'icons/bullet_green.png'
      title = _('Device_Status_Ok')
    end

    if device.reg_status == 'Unmonitored'
      icon = 'icons/bullet_white.png'
      title = _('Device_Status_Unmonitored')
    end

    if device.reg_status == 'UNKNOWN'
      icon = 'icons/bullet_black.png'
      title = _('Device_Status_Unknown')
    end

    if device.reg_status[0..5] == 'LAGGED'
      icon = 'icons/bullet_yellow.png'
      title = _('Device_Status_Lagged')
    end

    if device.reg_status == 'UNREACHABLE'
      icon = 'icons/bullet_red.png'
      title = _('Device_Status_Unreachable')
    end

    out = image_tag(icon, title: title)
    out
  end

  def hide_gui_dst?
    settings = current_user.hide_destination_end.to_i
    (!admin? && [1, 3, 5, 7].member?(settings.to_i)) ? true : false
  end

  def local_variables_for_partial(object)
    other_variables = [:@view_renderer, :@current_user, :@page_title, :@page_icon, :@view_flow, :@output_buffer, :@virtual_path, :@asset_paths, :@javascript_include]
    Hash[object.instance_variables.delete_if{|var| var.to_s.include?('@_') || other_variables.member?(var)}.collect{|var| [var.to_s.sub('@', '').downcase.to_sym, eval(var.to_s)]}]
  end

  def currency_by_id(currency_id)
    currency = Currency.where(id: currency_id).first
    return currency.name.to_s
  end

  def nice_separator(value)
    @separator ||= Confline.get_value('Global_Number_Decimal')
    @separator = '.' if @separator.blank?
    value.to_s.try(:sub, /[\,\.\;]/, @separator)
  end

  def nice_number_with_sep(value)
    nice_separator(nice_number(value))
  end

  # Renders email for current user
  def render_email(email_to_render, user)
    bin = binding()
    Email.email_variables(user).each { |key, value| Kernel.eval("#{key} = '#{value.gsub("'", "&#8216;")}'", bin) }
    ERB.new(email_to_render.body).result(bin).to_s
  end


  # find path of current action
  #   controller  - current controller
  #   action      - current action
  #   spec_name   - last path element is object and this is its name
  def find_path(controller, action, spec_name = nil, position = nil)
    out = []
    paths = user? ? YAML::load(File.open("#{Rails.root}/config/user_menu_path.yml")) : YAML::load(File.open("#{Rails.root}/config/admin_menu_path.yml"))
    path_action = paths.try(:[], controller).try(:[], action)

    if path_action
      if spec_name.present? && position.blank?
        out << "#{spec_name}"
        path_parent = {"controller" => controller, "action" => action}
      else
        if path_action['first_link'].present?
          first_url = "#{Web_Dir}/#{path_action['first_link']}"
          out << "<a href=\"#{first_url}\" style=\"color: #565759;\" id=\"#{path_action['name'].to_s.downcase}\">#{path_action['name']}</a>".html_safe
        else
          out << "#{path_action['name']}"
        end
        path_parent = path_action['parent']
      end

      parent = {controller: controller, action: action}

      while path_parent.present? do
        parent_action = paths[path_parent['controller']][path_parent['action']]
        parent_action_link = parent_action['link']
        link = if parent_action_link.present?
                 "#{Web_Dir}/#{parent_action_link}"
               else
                 '#'
               end

        out << "<a href=\"#{link}\" id=\"#{parent_action['name'].to_s.downcase}\">#{parent_action['name']}</a>".html_safe if parent_action['name'].present?
        parent = {controller: path_parent['controller'], action: path_parent['action']}
        path_parent = parent_action['parent']

        if path_parent.try(:[], 'not_showing')
          parent = {controller: path_parent['controller'], action: path_parent['action']}
          break
        end
      end
      out = params[:options_for_path_links][:out] if params[:options_for_path_links] &&
          params[:options_for_path_links][:out].present?
      return out.reverse, parent
    end

    rescue => exception
    MorLog.my_debug("ERROR: #{exception.inspect}")
    ''
  end

  def clear_button_tag(name, html_options = {})
    submit_tag name.presence || _('clear'), class: 'clear', name: 'clear', type: 'button', id: html_options[:id] || '', style: html_options[:style] || '',
      onClick: html_options[:disable_onclick] ? '' : "#{html_options[:onClick_prefix]}this.disabled=true; this.value='Processing'; jQuery('#search-form').append('<input type=\"hidden\" name=\"clear\" value=\"#{html_options[:hidden_input_value] || 'clear'}\" />').submit();"
  end

  def clear_button_tag_create_form(name, html_options = {})
    submit_tag _('clear'), class: 'clear', name: 'clear', type: 'button',
      onClick: "this.disabled=true; this.value='Processing'; $('#create-form').append('<input type=\"hidden\" name=\"clear\" value=\"clear\" />').submit();"
  end

  def submit_button_tag(name, html_options = {})
    submit_tag name,
               id: html_options[:id],
               style: html_options[:style] || '',
               disabled: html_options[:disabled] || false,
               onClick: "#{html_options[:onClick_prefix]}this.disabled=true; this.value='Processing'; jQuery('#'+this.form.id).append('<input type=\"hidden\" name=\"commit\" value=\"#{name}\" />'); this.form.submit();"
  end

  def show_search
    show_object('show_search')
  end

  def show_manage
    show_object('show_manage')
  end

  def show_create
    show_object('show_create')
  end

  def show_object(object_name)
    session.try(:[], params[:controller]).try(:[], params[:action]).try(:[], object_name.to_sym).to_i == 1
  end

  def formatted_date_in_user_tz(date)
    format = session[:date_format].to_s.blank? ? '%Y-%m-%d' : session[:date_format].to_s
    format_datetime_in_user_tz(date, format)
  end

  def formatted_time_in_user_tz(time)
    format = '%H:%M'
    format_datetime_in_user_tz(time, format)
  end

  def format_datetime_in_user_tz(datetime, format)
    datetime = datetime.to_time unless datetime.respond_to?(:strftime)
    datetime.in_time_zone(user_tz).strftime(format)
  end

  def formatted_date_as_given(date)
    format = session[:date_format].to_s.blank? ? '%Y-%m-%d' : session[:date_format].to_s
    date = date.to_time unless date.respond_to?(:strftime)
    date.strftime(format)
  end

  def formatted_time_as_given(time)
    time = time.to_time unless time.respond_to?(:strftime)
    time.strftime('%H:%M')
  end

  def nice_column(text, text_length)
    out = ''
    if text.length > text_length
      out << "<span title='#{text}'>"
      out << text[0..text_length-1]
      out << '</span>'
    else
      out << text
    end
    out.html_safe
  end

  def nice_alert(alert)
    name = (alert.name.to_s.length > 0) ? alert.name : 'Alert_' + alert.id.to_s
    return link_to(name, controller: 'alerts', action: 'alert_edit', id: alert.id)
  end

  def show_quick_form?(model)
    model.changed?
  end

  def nice_hgc(hgc)
    return hgc.description.sub('<b>', '').sub('</b>', '').sub('<br />', '<br>').sub('<br/>', '<br>').split('<br>')[0]
  end

  def nice_hgc_description(description)
    return description.sub('<b>', '').sub('</b>', '').sub('<br />', '<br>').sub('<br/>', '<br>').split('<br>')[0]
  end

  def is_hebrew?(string)
    string[/[\u0591-\u06FF]+/]
  end

  def fix_hebrew(string)
    regex = /[\u0591-\u06FF]+([\"\'\;\.\,\?\!\@\$\%\^\&\*\(\)\-\_\+\=\\\/ ]*[\u0591-\u06FF]+)*/
    hebrew = string.match(regex)
    start, the_end = hebrew.begin(0), hebrew.end(0)

    (start.zero? ? '' : string[0..start-1]) + hebrew.to_s.reverse! + (the_end.eql?(string.to_s.length - start) ? '' : string[the_end..-1])
  end

  def include_cell_editor(cells_to_update, update_action)
    "<script src='#{Web_Dir}/assets/cells_editor.js'></script>
    <script>
      var cells_to_update = \"#{cells_to_update}\";
      var update_action = \"#{update_action}\";
    </script>".html_safe
  end

  def calls_column_exists?(column)
    session[:calls_column_exist] ||= {}

    return session[:calls_column_exist][column] if session[:calls_column_exist].key?(column)

    session[:calls_column_exist][column] = ActiveRecord::Base.connection.column_exists?(:calls, column.to_sym)
  end

  def js_date_format
    frmt = session[:date_format]
    return 'yyyy-MM-dd' if frmt.blank?
    frmt.gsub('%', '').sub('Y', 'yyyy').sub('d', 'dd').sub('m', 'MM')
  end

  def get_periodic_check_status(periodic_check, alive)
     status = {
       tooltip_title: _('Periodic_check_status'),
       explanation: true
     }

     if periodic_check == 1 && alive == 0
       status[:color] = '#B10000'
       status[:bold] = (m4_functionality? ? 'font-weight: bold;' : '')
       status[:tooltip_description] = _('Connection_point_unreachable')
     elsif periodic_check == 1 && alive == 1
       status[:tooltip_description] = _('Connection_point_reachable')
       status[:color] = '#089D4B'
     else
       status[:explanation] = false
     end
     status
  end

  def get_number_pools
    NumberPool.order(:name).all.to_a
  end

  def proxy_server_active?
    Server.proxy_server_active
  end

  def single_fs_server_active?
    Server.single_fs_server_active
  end

  def break_tooltip_text(tooltip_text)
    return tooltip_text if tooltip_text.to_s.length < 80
    tooltip_text.scan(/.{80}/).join('<br/>')
  end

  def nice_disposition(call)
    return '' if call.blank?
    call_disposition = call.disposition.to_s
    hangupcause_code = call.hangupcause
    return_value = call_disposition

    if hangupcause_code.to_s == '312'
      return_value = 'CANCEL'
    elsif hangupcause_code
      return_value = "#{call_disposition} (#{hangupcause_code})"
    end

    return_value
  end

  def white_label_logo_present?(user_id = 0)
    Confline.get_value('White_Label_Logo_Present', user_id).to_i == 1
  end

  def white_label_favicon_present?(user_id = 0)
    Confline.get_value('White_Label_Favicon_Present', user_id).to_i == 1
  end

  def correct_logo_css
    return '' unless m4_functionality?
    white_label_logo_present? ? '-white_label' : '-m4'
  end

  def correct_favicon_css
    return '' unless m4_functionality?
    white_label_favicon_present? ? '_white_label' : '_m4'
  end

  def correct_favicon_folder
    return '' unless m4_functionality?
    white_label_favicon_present? ? 'white_label/' : ''
  end

  def hidden_email(email)
    spliited_email = email.to_s.split('@')
    spliited_email[0] = spliited_email[0][0] + ('*' * (spliited_email[0].length - 1))
    spliited_email.join('@')
  end

  def v3_codecs_exists?
    calls_column_exists?(:op_codec) && calls_column_exists?(:tp_codec) && m4_functionality?
  end

  def get_tp_codec(call)
    call.get_tp_codec(v3_codecs_exists?)
  end

  def get_op_codec(call)
    call.get_op_codec(v3_codecs_exists?)
  end

  def unknown_codecs?(call)
    get_tp_codec(call) == 'unknown' && get_op_codec(call) == 'unknown'
  end

  def one_codec_is_unknown?(call)
    call.one_codec_is_unknown?(v3_codecs_exists?)
  end
end
