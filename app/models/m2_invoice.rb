# M2 invoice model
class M2Invoice < ActiveRecord::Base

  extend UniversalHelpers
  require 'pdf_gen/prawn'

  attr_accessible :id, :number, :user_id, :status, :status_changed, :created_at, :updated_at, :issue_date, :period_start,
                  :period_end, :due_date, :timezone, :client_name, :client_details1, :client_details2, :client_details3,
                  :client_details4, :client_details5, :client_details6, :client_details7, :currency, :currency_exchange_rate, :total_amount,
                  :total_amount_with_taxes, :comment, :mailed_to_user, :confirmed_to_send_to_user, :notified_admin, :notified_manager, :nice_user,
                  :grace_period

  belongs_to :user
  has_many :m2_invoice_lines, dependent: :destroy
  belongs_to :m2_payment, foreign_key: 'manual_payment_id'
  after_destroy :cleanup_generated_files

  def validates_dates_from_update(params)
    if !params[:issue_date_system_tz].blank?
      if params[:issue_date_system_tz] < period_end
        errors.add(:m2_invoice, _('issue_date_must_be_later_than_period_end'))
      end

      if params[:due_date_system_tz] < params[:issue_date_system_tz]
        errors.add(:m2_invoice, _('date_due_must_be_later_than_issue_date'))
      end
    end

    return errors.size > 0 ? false : true
  end

  def self.order_by(options, fpage, items_per_page)
    order_by, order_desc = [options[:order_by], options[:order_desc]]
    order_string = ''

    if not order_by.blank? and not order_desc.blank?
      order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}" if M2Invoice.accessible_attributes.member?(order_by)
    end

    selection = M2Invoice.order(order_string)
    selection = options[:csv].to_i.zero? ? selection.limit("#{fpage}, #{items_per_page}").all : selection.all
  end

  def self.filter(options, show_currency)
    where, min_amount, max_amount = self.where_conditions(options, show_currency)
    clear_search = !where.blank?

    if [min_amount, max_amount].any? {|var| (/^(?!0\d)\d*(\.\d+)?$/ !~ var and var.present?)}
      return M2Invoice.none, clear_search
    end

    options_exchange_rate = options[:exchange_rate].to_d
    show_currency_upcase = show_currency.upcase
    selection = M2Invoice.select('m2_invoices.*,' + SqlExport.nice_user_sql).
                          joins('LEFT JOIN users ON users.id = m2_invoices.user_id').
                          where(where.join(' AND '))

    return selection, clear_search
  end

  def exchanged_total_amount_with_tax
    currency_exchange_rate * total_amount_with_taxes
  end

  def exchanged_total_amount
    currency_exchange_rate * total_amount
  end

  def nice_total_amount_with_tax
    if do_not_include_currencies.to_i == 1
      sprintf('%0.2f', total_amount_with_taxes).to_d if total_amount_with_taxes.is_a?(BigDecimal)
    else
      "#{nice_currency} #{Application.nice_value(total_amount_with_taxes)}"
    end
  end

  def nice_total_amount
    if do_not_include_currencies.to_i == 1
      sprintf('%0.2f', total_amount).to_d if total_amount.is_a?(BigDecimal)
    else
      "#{nice_currency} #{Application.nice_value(total_amount)}"
    end
  end

  def do_not_include_currencies
    Confline.get_value('Do_not_include_currencies')
  end

  def exchange_rate
    currency_exchange_rate
  end

  def nice_currency
    currency.to_s.upcase
  end

  # xslx Is generated Directly from object values, so exchange rates have to be set before passing object to generator
  # New object is created, just in case somebody tries to save changes to this object
  def copy_for_xslx
    self.total_amount = exchanged_total_amount
    self.total_amount_with_taxes = exchanged_total_amount_with_tax
    inv_lines = if Confline.get_value('Invoice_Group_By').to_i == 1 && Confline.get_value('Invoice_Group_By_Destination').to_i == 1
                  invoice_group_by_destination_group
                else
                  invoice_group_by
                end

    inv_lines.each do |line|
      line['rate'] = line['rate'].to_d * currency_exchange_rate.to_d
      line['price'] = line['price'].to_d * currency_exchange_rate.to_d
    end
    return self, inv_lines
  end

  def recalculate_invoice(user)
    user_nice_name = user.first_name.present? || user.last_name.present? ?
        "#{user.try(:first_name)} #{user.try(:last_name)}".strip :
        user.username.to_s

    self.client_name = user_nice_name
    self.client_details1 = user.address.address.to_s
    self.client_details2 = user.address.city.to_s
    self.client_details3 = user.address.postcode.to_s
    self.client_details4 = user.address.state.to_s
    self.client_details5 = user.address.direction_id.to_i
    self.client_details6 = user.address.phone.to_s
    self.save
  end

  def self.invoice_numbers_by_owner_id(owner_id)
    select('number').
        joins('JOIN users ON users.id = m2_invoices.user_id').
        where("users.owner_id = #{owner_id}").
        pluck(:number)
  end

  def self.send_selected_email(invoices_ids)
    invoices_id = invoices_ids.split(' ')
    invoices_id.each { |id|
      m2_invoice = self.where(id: id).first
      if m2_invoice
        m2_invoice.mailed_to_user = 0
        m2_invoice.confirmed_to_send_to_user = 1
        m2_invoice.save
      end
    }
  end

  def self.xlsx_template_cells
    %w[invoice_number invoice_issue_date invoice_period_start invoice_period_end invoice_due_date invoice_timezone
      invoice_client_name invoice_client_details1 invoice_client_details2 invoice_client_details3
      invoice_client_details4 invoice_client_details5 invoice_client_details6 invoice_client_details7
      invoice_lines_destination invoice_lines_name invoice_lines_rate invoice_lines_calls invoice_lines_nice_total_time
      invoice_lines_nice_price invoice_lines_destination_number invoice_nice_total_amount
      invoice_nice_total_amount_with_tax invoice_exchange_rate invoice_comment invoice_grace_period]
  end

  def cleanup_generated_files
    File.delete("/tmp/m2/invoices/#{number}.xlsx") if File.exist?("/tmp/m2/invoices/#{number}.xlsx")
    File.delete("/tmp/m2/invoices/#{number}.pdf") if File.exist?("/tmp/m2/invoices/#{number}.pdf")
  end

  def invoice_group_by
    self.m2_invoice_lines.select('id, m2_invoice_id,' \
      ' destination, name, rate, sum(price) AS price, sum(calls) AS calls,' \
      ' sum(total_time) AS total_time').group(self.grouped_string)
  end

  def grouped_string
    inv_group_by = Confline.get_value('Invoice_Group_By').to_i == 1
    show_rate = Confline.get_value('Show_Rates').to_i == 1
    group_string = "#{inv_group_by ? 'name' : 'destination'} #{', rate' if show_rate}"
  end

  def invoice_group_by_destination_group
    show_rate = Confline.get_value('Show_Rates').to_i == 1
    select_string = "m2_invoice_lines.id as id, m2_invoice_id, destination, IFNULL(destinationgroups.name, 'Unassigned Destinations') as name,
                     rate, sum(price) AS price, sum(calls) AS calls,
                     sum(total_time) AS total_time"
    self.m2_invoice_lines.select(select_string)
                         .joins('LEFT JOIN destinations ON destinations.prefix = m2_invoice_lines.destination')
                         .joins('LEFT JOIN destinationgroups ON destinationgroups.id = destinations.destinationgroup_id')
                         .group("destinationgroups.name #{', rate' if show_rate}")
  end

  def set_client_details(user)
    user_nice_name = user.first_name.present? || user.last_name.present? ?
        "#{user.try(:first_name)} #{user.try(:last_name)}".strip :
        user.username.to_s

    self.client_name = user_nice_name
    self.client_details1 = user.address.address.to_s
    self.client_details2 = user.address.city.to_s
    self.client_details3 = user.address.postcode.to_s
    self.client_details4 = user.address.state.to_s
    self.client_details5 = user.address.direction_id.to_i
    self.client_details6 = user.address.phone.to_s
  end

  private

  def self.where_conditions(options, show_currency)
    nice_user, number, period_start, period_end, issue_date, status, min_amount, max_amount, currency = options[:s_nice_user],
                                                                                                        options[:s_number],
                                                                                                        options[:s_period_start],
                                                                                                        options[:s_period_end],
                                                                                                        options[:s_issue_date],
                                                                                                        options[:s_status],
                                                                                                        options[:s_min_amount],
                                                                                                        options[:s_max_amount],
                                                                                                        options[:s_currency]
    options_exchange_rate = options[:exchange_rate].to_d
    current_user = options[:current_user]
    show_currency_upcase = show_currency.upcase
    where = []
    where << "users.responsible_accountant_id = '#{current_user.id}'" if current_user.show_only_assigned_users?
    where << "(users.username LIKE '#{nice_user}' or users.first_name LIKE '%#{nice_user}%' or users.last_name LIKE '%#{nice_user}%')" if nice_user.present?
    where << "number LIKE '#{number}'" if number.present?
    where << "period_start >= '#{period_start} 00:00:00'" if period_start.present?
    where << "period_end <= '#{period_end} 23:59:59'" if period_end.present?
    where << "issue_date BETWEEN '#{issue_date}' AND '#{(issue_date.to_time + 1.days).to_s}'" if issue_date.present?
    where << "status LIKE '#{status}'" if status.present?
    where << "(total_amount * IF((UPPER(m2_invoices.currency) = '#{show_currency_upcase}'),(m2_invoices.currency_exchange_rate),(#{options_exchange_rate}))) >= #{min_amount}" if min_amount.present?
    where << "(total_amount * IF((UPPER(m2_invoices.currency) = '#{show_currency_upcase}'),(m2_invoices.currency_exchange_rate),(#{options_exchange_rate}))) <= #{max_amount}" if max_amount.present?
    where << "currency LIKE '#{currency}'" if currency.present?
    if options[:s_issue_date].present?
      separate_date_time = options[:s_issue_date].split(' ')
      options[:s_issue_date] = separate_date_time[0]
    end
    return where, min_amount, max_amount
  end
end

