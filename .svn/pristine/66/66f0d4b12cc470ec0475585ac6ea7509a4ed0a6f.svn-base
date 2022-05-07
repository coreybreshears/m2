# -*- encoding : utf-8 -*-
module M2InvoicesHelper
  def m2_link(nice_user, user_id)
    link_to nice_user, {controller: :users, action: :edit, id: user_id}
  end

  def nice_invoice_amount(amount, m2_invoice, options_exchange_rate, delimiter = '')
    currency, currency_exchange_rate = [m2_invoice.currency.to_s, m2_invoice.currency_exchange_rate.to_d]
    curr = (currency and currency.upcase == session[:show_currency].to_s.upcase) ? currency_exchange_rate : options_exchange_rate
    amount = amount.blank? ? '' : amount * curr
    amount = amount.to_s.gsub(/[\,\.\;]/, delimiter.to_s) if delimiter.present?

    amount
  end

  def select_period_start
    period_starts = ActiveRecord::Base.connection.select_all("SELECT DISTINCT DATE_FORMAT(period_start, '%Y-%m-%d') AS period_start FROM m2_invoices #{sql_good_period} OR issue_date IS NULL")
    options_for_select([['', '']] + period_starts.map { |per_st| per_st['period_start'] }.sort { |date_first, date_sec| date_sec <=> date_first }, @options[:s_period_start])
  end

  def select_period_end
    period_ends = ActiveRecord::Base.connection.select_all("SELECT DISTINCT DATE_FORMAT(period_end, '%Y-%m-%d') AS period_end FROM m2_invoices #{sql_good_period} OR issue_date IS NULL")
    options_for_select([['', '']] + period_ends.map { |per_e| per_e["period_end"] }.sort { |date_first, date_sec| date_sec <=> date_first }, @options[:s_period_end])
  end

  def select_issue_date
    issue_dates = ActiveRecord::Base.connection.select_all("SELECT DISTINCT DATE_FORMAT(issue_date, '%Y-%m-%d') AS issue_date FROM m2_invoices #{sql_good_period}")
    options_for_select([['', '']] + issue_dates.map { |iss_date| iss_date['issue_date'] }.sort { |date_first, date_sec| date_sec <=> date_first }, @options[:s_issue_date])
  end

  def select_status(status)
    statuses = ActiveRecord::Base.connection.select_all('SELECT DISTINCT status FROM m2_invoices')
    options_for_select([[_('All'), '']] + statuses.map { |stats| stats['status'].to_s }.sort, status)
  end

  def select_status_for_edit(status)
    statuses = ['In process', 'Sent through Email', 'Sent Manually', 'Accepted', 'Protested', 'Paid', 'Closed', 'Deleted', 'Changed']
    options_for_select(statuses.map { |stats| stats.to_s }.sort, status)
  end

  def select_currency
    currencies = ActiveRecord::Base.connection.select_all('SELECT DISTINCT currency FROM m2_invoices')
    options_for_select([[_('All'), '']] + currencies.map { |curr| curr['currency'].to_s.upcase }.sort, @options[:s_currency])
  end

  def sql_good_period
    "WHERE issue_date BETWEEN '1970-01-01' AND '2030-12-31'"
  end

  def customer_invoices_json(m2_invoices_in_page, float_digits)
    result = []
    m2_invoices_in_page.try(:each) do |m2_invoice|
      result << {
        id: m2_invoice.id,
        user_id: m2_invoice.user_id.to_i,
        user_name: nice_user(User.where(id: m2_invoice.user_id.to_i).first),
        number: m2_invoice.number.to_s,
        status: m2_invoice.status.to_s,
        period_start: m2_invoice.period_start ? m2_invoice.period_start.strftime('%Y-%m-%d %H:%M:%S') : '',
        period_end: m2_invoice.period_end ? m2_invoice.period_end.strftime('%Y-%m-%d %H:%M:%S') : '',
        issue_date: m2_invoice.issue_date ? m2_invoice.issue_date.strftime('%Y-%m-%d %H:%M:%S') : '',
        timezone: m2_invoice.timezone.to_s,
        total_amount: nice_number_round(m2_invoice.exchanged_total_amount, float_digits),
        total_amount_with_taxes: nice_number_round(m2_invoice.exchanged_total_amount_with_tax, float_digits),
        currency: m2_invoice.currency.to_s.upcase,
        xlsx_name: 'XLSX',
        pdf_name: 'PDF',
        details: 'DETAILS',
        delete: 'DELETE',
        checkbox: false
      }
    end
    raw result.to_json
  end
end
