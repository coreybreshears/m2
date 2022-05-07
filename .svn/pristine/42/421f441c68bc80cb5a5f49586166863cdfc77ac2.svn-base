# M2InvoiceLinesHelper module
module M2InvoiceLinesHelper
  def nice_invoice_amount(amount, m2_invoice, options_exchange_rate, delimiter = '')
    currency = m2_invoice.currency.to_s
    currency_exchange_rate = m2_invoice.currency_exchange_rate.to_d
    curr = (currency && currency.upcase == session[:show_currency].to_s.upcase) ? currency_exchange_rate : options_exchange_rate
    amount = amount.blank? ? '' : amount * curr
    amount = amount.to_s.gsub(/[\,\.\;]/, delimiter.to_s) if delimiter.present?

    amount
  end
end
