# -*- encoding : utf-8 -*-
require 'application_helper'
require 'pdf_gen/prawn'
include ApplicationHelper

module PdfGen
  module Generate

    def Generate.call_list_to_pdf_header_basic
      [_('date'), _('called_from'), _('called_to'), _('duration'), _('hangup_cause')]
    end


    def Generate.call_list_to_pdf_header(pdf, direction, current_user, i, options)
      column_options = options[:column_options]
      top_options = {
          rowspan: 2
      }

      headers = [{text: _('Date')}.merge(top_options),
                 {text: "#{_('called_from')} (#{_('Source')})"}.merge(top_options),
                 {text: "#{_('called_to')} (#{_('Destination')})"}.merge(top_options),
                 {text: _('Billsec')}.merge(top_options),
                 {text: _('duration')}.merge(top_options),
                 {text: _('hangup_cause')}.merge(top_options) ]


      headers.delete_if { |header| (current_user.usertype == 'user' && header[:text] == _('Billsec')) || (!column_options[:show_duration] && header[:text] == _('duration')) }

      headers2 = [{text:'', colspan: headers.length + options[:additional_number].to_i}]

      if options[:pdf_last_calls].to_i == 1
        if %w(admin manager).include?(current_user.usertype)

          headers << {text: _('Answer_time')}.merge(top_options) if column_options[:show_answer_time]
          headers << {text: _('End_Time')}.merge(top_options) if column_options[:show_end_time]
          headers << {text: _('PDD'), align: :right}.merge(top_options) if column_options[:show_pdd]
          headers << {text: _('Terminated_by')}.merge(top_options) if column_options[:show_terminated_by]

          if current_user.is_manager?
            provider_colspan = 1
            provider_colspan += 1 unless current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_rate)
            provider_colspan += 1 unless current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_price)
          else
            provider_colspan = 3
          end

          headers << {text: _('Provider'), colspan: provider_colspan}
          headers2 << {text: _('Name')}
          if !current_user.is_manager? || (current_user.is_manager? && !current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_rate))
            headers2 << {text: _('Rate')}
          end
          if !current_user.is_manager? || (current_user.is_manager? && !current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_price))
            headers2 << {text: _('Price')}
          end

          # headers << headers2
          headers << {text: _('User')}
          # --------------------- rate price name
          headers2 << {text: _('Name')}
          headers2 << {text: _('Rate')}
          headers2 << {text: _('Price')}
          # headers << headers2
        end
        if current_user.usertype == 'user'
          headers << {text: _('Prefix_used')}.merge(top_options)
          headers << {text: _('Price')}.merge(top_options)
        end
      else
        if current_user.usertype == 'admin'
          if direction == 'incoming'
            headers << {text: _('Provider')}.merge(top_options)
            headers << {text: _('Incoming')}.merge(top_options)
            headers << {text: _('Owner')}.merge(top_options)
            headers << {text: _('Profit')}.merge(top_options)
          else
            headers << {text: _('sell_price')}.merge(top_options)
            headers << {text: _('buy_price')}.merge(top_options)
            headers << {text: _('Profit')}.merge(top_options)
            headers << {text: _('Margin')}.merge(top_options)
            headers << {text: _('Markup')}.merge(top_options)
          end
        end

        if current_user.usertype == 'user'
          # if direction != "incoming"
          headers << {text: _('Price')}.merge(top_options)
          # end
        end
      end

      return headers, headers2
    end

=begin rdoc

=end

    def Generate.providers_calls_to_pdf_header
      headers = call_list_to_pdf_header_basic
      headers << _('User_price')
      headers << _('Provider_price')
      headers << _('Profit')

      headers
    end

    def Generate.providers_calls_to_pdf(provider, calls, options)

      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true

      ###### Generate PDF ########
      pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
      pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

      pdf.text(_('CDR_Records') + ": #{provider.name}", {:left => 40, :size => 10})
      pdf.text(_('Call_type') + ": " + options[:call_type], {:left => 40, :size => 10})
      pdf.text(_('Period') + ": " + options[:date_from] + "  -  " + options[:date_till], {:left => 40, :size => 8})
      pdf.text(_('Currency') + ": #{options[:currency]}", {:left => 40, :size => 8})
      pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

      total_price = 0
      total_billsec = 0
      exrate = Currency.count_exchange_rate(options[:default_currency], options[:currency])

      items = []
      for call in calls
        item = []
        rate_cur, rate_cpr = Rate.get_provider_rate(call, options[:direction], exrate)
        item << call.calldate.strftime("%Y-%m-%d %H:%M:%S")
        item << call.src
        item << call.dst

        if @direction == "incoming"
          billsec = call.did_billsec
        else
          billsec = call.billsec
        end

        if billsec == 0
          item << "00:00:00"
        else
          pitem << nice_time(billsec)
        end
        item << call.disposition
        item << nice_number(rate_cur, {:nice_number_digits => options[:nice_number_digits]})
        item << nice_number(rate_cpr, {:nice_number_digits => options[:nice_number_digits]})
        user_price = 0
        user_price = rate_cur if call.user_price
        provider_price = 0
        provider_price = rate_cpr if provider_price
        item << nice_number(user_price - provider_price, {:nice_number_digits => options[:nice_number_digits]})


        total_price +=rate_cur if call.user_price
        total_billsec += call.billsec
        items << item
      end
      item = []
      item << _('Profit')
      if total_billsec == 0
        item << "00:00:00"
      else
        item << nice_time(total_billsec)
      end
      item << nice_number(total_price, options)

      items << item

      headers = Generate.providers_calls_to_pdf_header

      pdf.table(items,
                :width => 550, :border_width => 0,
                :font_size => 6,
                :headers => headers) do
      end

      string = "<page>/<total>"
      opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
      pdf.number_pages string, opt

      pdf

    end


    # ******************************************** Rates ###############################################################

    def Generate.generate_personal_wholesale_rates_pdf(pdf, rates, tariff, options)
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true

      exrate = Currency.count_exchange_rate(tariff.currency, options[:currency])

      items = []
      items << [' ', '', '', '', '', '']

      for rate in rates
        item = []
        rate_details, rate_cur = Rate.get_provider_rate_details(rate, exrate)
        if rate.destination && rate.destination.direction
          item << rate.destination.direction.name
          item << {:text => rate.destination.prefix.to_s, :align => :left}
        else
          item << " "
          item << " "
        end
        if rate_details.size > 0
          rate_cur = rate_details.size > 1 ? nice_number(rate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd}).to_s + " *" : nice_number(rate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << rate_cur
          item << rate_details[0]['connection_fee']
          item << rate_details[0]['increment_s']
          item << rate_details[0]['min_time']
        else
          item << nice_number(0.0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(0.0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << 0
        end

        items << item

        if rate_details.size > 1
          items << [{:text => _('*_Maximum_rate'), :colspan => 6}]
          items << [' ', '', '', '', '', '']
        end

      end


      pdf.table(items,
                :width => 550, :border_width => 0,
                :font_size => 9,
                :headers => [_('Destination'), _('Prefix'), _('Rate'), _('Connection_Fee'), _('Increment'), _('Min_Time')],
                :align_headers => {0 => :left, 1 => :left, 2 => :right, 3 => :right, 4 => :right, 5 => :right}) do
        column(0).style(:align => :left)
        column(1).style(:align => :left)
        column(2).style(:align => :right)
        column(3).style(:align => :right)
        column(4).style(:align => :right)
        column(5).style(:align => :right)
      end

      string = "<page>/<total>"
      opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
      pdf.number_pages string, opt

      pdf
    end

=begin rdoc

=end

  end


  # 8********************************* rates *************************************


  def Generate.generate_rates_header(options)
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf.text(options[:pdf_name], {:left => 40, :size => 23})
    pdf.text(_('Name') + ": #{options[:name]}", {:left => 40, :size => 12}) if !options[:hide_tariff]
    pdf.text(_('Currency') + ": " + options[:currency], {:left => 40, :size => 10})
    pdf
  end


  private

  def Generate.generate_last_calls_pdf(calls, total_calls, current_user, main_options={})
    digits = Confline.get_value('Nice_Number_Digits').to_i
    gnd = Confline.get_value('Global_Number_Decimal').to_s
    cgnd = gnd.to_s == '.' ? false : true
    additional_collumns = main_options[:column_options]

    usertype = current_user.usertype
    #options
    options = {}
    options = options.merge({pdf_last_calls: 1, column_options: additional_collumns})

    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    pdf.text(_('Period') + ": " + main_options[:date_from] + "  -  " + main_options[:date_till], {:left => 40, :size => 10})
    pdf.text(_('Currency') + ":#{main_options[:show_currency]}", {:left => 40, :size => 8})
    pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

    options[:total_calls] = calls.size
    options[:calls_per_page] = options[:calls_per_page_first]

    items = []

    usertype_admin = %w(admin manager).include?(usertype)

    additional_number = 0
    additional_collumns.each {|column, show| additional_number += 1 if show}
    options[:additional_number] = additional_number



    h, h2 = call_list_to_pdf_header(pdf, main_options[:direction], current_user, 0, options)
    items << h2 if current_user.usertype.to_s != 'user'
    for call in calls
      item = []
      #calldate2 - because something overwites calldate when changing date format
      item << call.calldate2.to_s

      item << {:text => nice_src(call, {:pdf => 1}).to_s, :align => :left}
      item << {:text => hide_dst_for_user(current_user, "pdf", call.dst.to_s).to_s, :align => :left}
      item << nice_time(call['nice_billsec'])
      item << nice_time(call['duration']) if usertype_admin && additional_collumns[:show_duration]
      item << call.dispod.to_s

      if usertype_admin
        # item << call.server_id.to_s
        item << nice_date_time(call['answer_time']).to_s if additional_collumns[:show_answer_time]
        item << nice_date_time(call['end_time']).to_s if additional_collumns[:show_end_time]
        item << nice_number(call['pdd'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd}) if additional_collumns[:show_pdd]
        item << call['terminated_by'].to_s.capitalize if additional_collumns[:show_terminated_by]
        item << call['provider'].to_s

        if !current_user.is_manager? || (current_user.is_manager? && !current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_rate))
          item << nice_number(call['provider_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end

        if !current_user.is_manager? || (current_user.is_manager? && !current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_price))
          item << nice_number(call['provider_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end

        item << call['user'].to_s

        item << nice_number(call['user_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
      else
        if current_user.show_billing_info == 1
          if usertype == 'user'

            item << call['prefix'].to_s
            item << nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          end
        end
      end
      items << item
    end

    item = []

    #Totals

    item << {:text => _('Total'), :colspan => 3}
    item << nice_time(total_calls[:total_billsec])
    item << nice_time(total_calls[:total_duration]) if usertype_admin && additional_collumns[:show_duration]

    colspan_number = (usertype_admin && additional_collumns[:show_duration]) ? 3 + additional_number : 2

    if !current_user.is_manager? || (current_user.is_manager? && current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_rate))
      colspan_number -= 1
    end

    item << {:text => ' ', :colspan => colspan_number }
    if usertype_admin
      if !current_user.is_manager? || (current_user.is_manager? && !current_user.authorize_manager_fn_permissions(fn: :reports_calls_list_hide_vendors_price))
        item << nice_number(total_calls[:total_provider_price], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
      end
      item << {:text => '', :colspan => 2}
      item << nice_number(total_calls[:total_user_price], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
    end
    if usertype == 'user'
      item << nice_number(total_calls[:total_user_price], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
    end
    items << item
    pdf.table(items,
              :width => 540, :border_width => 0,
              :font_size => 4, :padding => 1,
              :headers => h) do
    end


    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt

    pdf
  end
end
