# Paypal payment
class PaypalController < ApplicationController
  require 'digest'
  require 'uri'
  require 'net/http'
  require 'json'
  require 'active_support/core_ext'

  def payment
    begin
      client_id = Confline.get_value('paypal_client_id')
      secret_key = Confline.get_value('secret_paypal_key')
      order_url = 'https://api.paypal.com/v2/checkout/orders/'

      order_id = params[:id]
      user_id = current_user_id

      url = URI(order_url + order_id)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(url)
      request.basic_auth(client_id, secret_key)

      response = http.request(request)
      result = JSON.parse(response.body)

      approval = (current_user.paypal_need_approval == 1) ? 1 : 0

      if response.code == '200' && result['status'] == 'COMPLETED'
        data = result['purchase_units'][0]
        payment_info = data['payments']['captures'][0]['seller_receivable_breakdown']
        amount = payment_info['net_amount']['value'].to_s.to_d
        entered_amount = data['amount']['value'].to_d

        credited_amount = get_credited_amount(amount, entered_amount)
        currency_name = data['amount']['currency_code'].to_s
        currency = Currency.get_by_name(currency_name)

        payment = M2Payment.new_by_attributes(
          user_id: user_id, amount: credited_amount, currency_id: currency[:id],
          exchange_rate: currency[:exchange_rate], credited_amount: credited_amount, entered_amount: entered_amount,
          approved: approval
        )

        payment.save
        flash[:status] = _('Paypal_Payment_has_been_successful')
        Action.add_action_hash(user_id,
                             {action: 'payment: paypal',
                              data: 'User successfully paid using paypal',
                              data3: "#{amount} #{currency_name}",
                              data2: "payment id: #{payment.id}"
                             })
        payment.send_confirmation_email_to_admin if approval == 1
      else
        flash[:notice] = _('Paypal_Payment_is_not_completed')
        MorLog.my_debug('Paypal Payment was not completed.', true)
      end
    rescue => ex
      flash[:notice] = _('Something_is_wrong_with_paypal_configuration')
      MorLog.my_debug(_('Something_is_wrong_with_paypal_configuration') + ex.to_s, true)
    end
    redirect_to(:root) && (return false)
  end

  private

  def get_credited_amount(net_amount, entered_amount)
    pp_credit_selection = current_user.paypal_credit_selection.to_i
    pp_fee_selection = current_user.paypal_fee_selection.to_i

    fee = (pp_fee_selection == 0) ? current_user.paypal_charge_fee_on_entered_amount.to_d : current_user.paypal_charge_fee_on_net_amount.to_d

    return entered_amount - ((fee/100) * entered_amount) if pp_credit_selection == 0 && pp_fee_selection == 0
    return entered_amount - ((fee/100) * net_amount) if pp_credit_selection == 0 && pp_fee_selection == 1
    return net_amount - ((fee/100) * entered_amount) if pp_credit_selection == 1 && pp_fee_selection == 0
    return net_amount - ((fee/100) * net_amount) if pp_credit_selection == 1 && pp_fee_selection == 1
  end
end
