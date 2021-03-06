# M2 Payment model
class M2Payment < ActiveRecord::Base
  PAYMENT_TO_PROVIDER = 1

  attr_accessible :id, :user_id, :comment, :date, :amount, :amount_with_tax, :currency_id, :exchange_rate,
                  :payment_destination, :hidden, :user_balance_before, :user_balance_after, :entered_amount,
                  :credited_amount, :approved

  belongs_to :user
  belongs_to :currency
  has_one :m2_invoice, foreign_key: 'manual_payment_id'

  before_create { exchange_currency }
  after_create do
    add_action('payment_created')
    update_user_balance unless self.comment == 'Initial balance' || user.paypal_need_approval == 1
  end
  after_destroy { add_action('payment_deleted') }

  validates :amount,
            numericality: {
                message: _('amount_must_be_numerical'),
                if: -> { amount.present? }
            }
  validates :amount_with_tax,
            numericality: {
                message: _('amount_with_tax_must_be_numerical'),
                if: -> { amount_with_tax.present? }
            },
            presence: {
                message: _('amount_or_amount_with_tax_must_be_present'),
                if: -> { amount.blank? }
            }
  validate :amounts_equal_to_zero?

  validates_numericality_of :exchange_rate,
                            greater_than: 0.0,
                            message: _('Exchange_rate_must_be_greater_than_zero')

  def self.new_by_attributes(attributes)
    default_attributes = {
      date: Time.now,
      amount: nil,
      amount_with_tax: nil
    }

    attributes = default_attributes.merge(attributes)
    m2_payment = M2Payment.new(attributes)

    if m2_payment.valid?
      m2_payment.apply_taxes
      if m2_payment.payment_destination == PAYMENT_TO_PROVIDER
        m2_payment.invert_amounts
      end
    end

    m2_payment
  end

  def self.order_by(options, current_user)
    order_by, order_desc = [options[:order_by], options[:order_desc]]

    [options[:s_amount_min], options[:s_amount_max]].each do |amount|
      amount.to_s.try(:sub!, /[\,\.\;]/, '.').try(:strip!)
    end

    search_where, search_where_date, invalid_search = M2Payment.search_options(options, current_user)

    clear_search = !search_where.blank?

    if !invalid_search
      order_string = ''

      if order_by.present? && order_desc.present? && M2Payment.accessible_attributes.member?(order_by)
        order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}"
      end

      # Join is nescescary only when checking if user is hidden
      # Not very pretty however saves a few seconds in case join is not needed
      if options[:hide_hidden_users]
        payments = M2Payment.joins(:user)
      else
        payments = M2Payment
      end
      selection_all = payments.order(order_string)
                              .where(search_where.join(" AND "))
                              .where(search_where_date).all
    end

    return  selection_all, clear_search, invalid_search
  end

  def self.search_options(options, current_user)
    user_id, amount_min, amount_max, currency_id, date_from, date_till, not_default_date, hide_hidden_users = options[:s_user_id], options[:s_amount_min],
                                                                                                              options[:s_amount_max], options[:s_currency_id],
                                                                                                              options[:s_date_from], options[:s_date_till],
                                                                                                              options[:not_default_date], options[:hide_hidden_users]

    search_where = []
    search_where << "m2_payments.user_id = #{user_id}" if user_id.present?
    search_where << "ROUND(m2_payments.amount * m2_payments.exchange_rate, #{options[:decimal_digits]}) >= '#{amount_min}'" if amount_min.present?
    search_where << "ROUND(m2_payments.amount * m2_payments.exchange_rate, #{options[:decimal_digits]}) <= '#{amount_max}'" if amount_max.present?
    search_where << "m2_payments.currency_id = #{currency_id}" if currency_id.present?
    search_where << 'users.hidden = 0' if hide_hidden_users

    if current_user.usertype == 'manager' && current_user.show_only_assigned_users?
      search_where << "users.responsible_accountant_id = '#{current_user.id}'"
    end

    if not_default_date
      search_where << "date BETWEEN '#{date_from}' AND '#{date_till}'"
    else
      search_where_date = "date BETWEEN '#{date_from}' AND '#{date_till}'"
    end

    invalid_search = !M2Payment.amounts_are_numeric(amount_min, amount_max)

    return search_where, search_where_date, invalid_search
  end

  def self.currency_by_id(currency_id)
    Currency.where(id: currency_id).first.try(:name).to_s
  end

  def payment_destination=(value)
    @payment_destination = value
  end

  def payment_destination
    @payment_destination.to_i
  end

  def invert_amounts
    self.amount = 0 - amount
    self.amount_with_tax = 0 - amount_with_tax
  end

  def apply_taxes
    user_tax = user.get_tax
    if self.amount.to_d != 0
      new_amount_with_tax = user_tax.apply_tax(amount)
      new_amount_with_tax = amount if new_amount_with_tax.zero?
      self.amount_with_tax = new_amount_with_tax
    else
      new_amount = user_tax.count_amount_without_tax(amount_with_tax)
      new_amount = amount_with_tax if new_amount.zero?
      self.amount = new_amount
    end
  end

  def update_user_balance
    update_attribute(:user_balance_before, user.raw_balance)
    user.update_balance(amount.to_d)
    update_attribute(:user_balance_after, user.raw_balance)
  end

  def update_denied_balance
    update_attribute(:user_balance_before, user.raw_balance)
    update_attribute(:user_balance_after, user.raw_balance)
  end

  def amount_with_tax_default_currency
    amount_with_tax.to_d / exchange_rate.to_d
  end

  def amount_default_currency
    amount.to_d / exchange_rate.to_d
  end

  def self.find_personal_payments(options, user)
    user_id = user.id

    show_only_latest = self.where(user_id: user_id).
        where("date BETWEEN '#{options[:from]}' AND '#{options[:till]}'").count.zero?

    payments = self.select('m2_payments.*, currencies.name AS currency_name').
      where(user_id: user_id).
      joins('JOIN currencies ON currencies.id = m2_payments.currency_id')

    payments = payments.where("date BETWEEN '#{options[:from]}' AND '#{options[:till]}'") unless show_only_latest

    currency_id = User.current.active_currency.id
    current_exchange_rate = User.current.active_currency.exchange_rate

    totals = payments.where(user_id: user_id).select("
      SUM(amount) * IF(currency_id = #{currency_id}, m2_payments.exchange_rate, #{current_exchange_rate}) AS amount,
      SUM(amount_with_tax) * IF(currency_id = #{currency_id}, m2_payments.exchange_rate, #{current_exchange_rate}) AS amount_with_tax
    ").first

    order_by, order_type = options[:order_by], options[:order_type]
    if (payments.column_names << 'currency_name').include?(order_by) && %w[asc desc].include?(order_type.downcase)
      payments = payments.order("#{order_by} #{order_type}")
    end

    return payments, totals, show_only_latest
  end

  def self.create_for_user(user, params = {})
    user = User.where(id: user).first if user.class == Fixnum

    return false unless user

    self.new({user_id: user.id, date: Time.now}.merge(params))
  end

  def exchange_currency
    self.amount = amount_default_currency
    self.amount_with_tax = amount_with_tax_default_currency
  end

  def generate_invoice_for_manual_payment
    user = User.where(id: user_id.to_i).first
    inv = nil

    if user.present? && user.generate_prepaid_invoice.to_i == 1
      inv = create_invoice_for_manual_payment(user)
      inv_details = create_invoice_details_for_manual_payment(inv)
    end
    return inv
  end

  def self.approval_period
    sql = "SELECT MIN(date), MAX(date) FROM m2_payments where approved = 1"
    ActiveRecord::Base.connection.execute(sql).to_a[0]
  end

  def send_confirmnation_email_to_user(confirmation = 'accepted')
    return if user.paypal_do_not_send_confirmation_email.to_i == 1
    MorLog.my_debug("Sending payment #{confirmation} email for user - id: #{user.id}", true)
    email_template = Email.where(name: "payment_#{confirmation}", owner_id: 0).first
    email_sender = EmailSender.new
    email_sent = email_sender.send_notification(email_template, user.main_email, user.id)
  end

  def send_confirmation_email_to_admin
    MorLog.my_debug("Sending payment confirmatrion email for admin", true)
    admin = User.select(:id, :main_email).where(id: 0).first
    email_template = Email.where(name: 'payment_confirmation_necessary', owner_id: 0).first
    email_sender = EmailSender.new
    user_full_name = user.nice_user
    payment_amount = Email.nice_number(amount.to_f * exchange_rate.to_f).to_s
    payment_currency = Currency.where(id: currency_id.to_i).first.try(:name).to_s
    email_sent = email_sender.send_notification(
      email_template, admin.main_email, admin.id,
      payments_user_full_name: user_full_name, payment_amount: payment_amount,
      payment_currency: payment_currency
    )
  end

  private

  def add_action(action)
    Action.add_action_hash(
        User.current,
        {
            action: action,
            data: self.user_id, data2: self.amount, data3: M2Payment.currency_by_id(self.currency_id.to_i),
            target_id: self.id, target_type: 'Payment'
        }
    )
  end

  def self.amounts_are_numeric(amount_min, amount_max)
    is_numeric = /^-?[\d]+(\.[\d]+){0,1}$/
    return (
      (is_numeric.match(amount_min) || amount_min.blank?) && (is_numeric.match(amount_max) || amount_max.blank?)
      )
  end

  def amounts_equal_to_zero?
    if errors.blank?
      if amount.present? && amount == 0
        errors.add(:amount, _('amount_cannot_be_zero'))
      elsif amount_with_tax.present? && amount_with_tax == 0
        errors.add(:amount_with_tax, _('amount_with_tax_cannot_be_zero'))
      end
    end
  end

  def create_invoice_for_manual_payment(user)
    number_type = Confline.get_value('Prepaid_Invoice_Number_Type').to_i
    invoice = M2Invoice.new
    time_now = Time.now
    invoice.user_id = user.id
    invoice.period_start = time_now
    invoice.period_end = time_now
    invoice.issue_date = time_now
    invoice.status_changed = time_now
    invoice.total_amount = amount.to_d
    invoice.total_amount_with_taxes = amount_with_tax.to_d
    time_zone = Timezone.where(zone: user.time_zone.to_s).try(:first)
    if time_zone.present?
      time_zone_offset = time_zone.offset / 60 / 60
      invoice.timezone = "#{time_zone.zone} (GMT #{time_zone_offset >= 0 ? '+': ''}#{time_zone_offset.to_s})"
    end
    invoice.set_client_details(user)

    invoice.mailed_to_user = 1
    invoice.confirmed_to_send_to_user = 1
    # To not send this invoice for admin or manager, only for user
    invoice.notified_admin = 1
    invoice.notified_manager = 1

    invoice.status = 'Paid'
    invoice.manual_payment_invoice = 1
    currency = self.currency


    if currency
      invoice.currency_exchange_rate = currency.exchange_rate
      invoice.currency = currency.name
    end

    invoice.number = generate_invoice_number(Confline.get_value('Invoice_Number_Start'),
                                             Confline.get_value('Invoice_Number_Length').to_i,
                                             Confline.get_value('Invoice_Number_Type'),
                                             time_now)
    invoice.manual_payment_id = id
    invoice.save
    invoice
  end

  def create_invoice_details_for_manual_payment(inv)
    inv_line = M2InvoiceLine.new
    inv_line.m2_invoice_id = inv.id
    inv_line.destination = ''
    inv_line.name = Confline.get_value('Manual_Payment_Line').presence || 'Prepaid VoIP Services'
    inv_line.price = inv.total_amount
    inv_line.save
  end

  def generate_invoice_number(start, length, type, time)
    type = 1 if type.to_i == 0

    if type == 1
      last_number = ActiveRecord::Base.connection.select_value("
        SELECT MAX(CAST(SUBSTR(number, #{start.length+1}) AS signed)) FROM m2_invoices WHERE number LIKE '#{start}%'
      ").to_i

      number = last_number + 1

      zl = length - start.length - number.to_s.length
      zeros = ''
      1..zl.times { zeros += '0' }
      invnum = "#{start}#{zeros}#{number}"
    else
      date = time.year.to_s[-2..-1] + good_date(time.month)+good_date(time.day)
      last_id = ActiveRecord::Base.connection.select_value("
        SELECT MAX(id) FROM m2_invoices
      ").to_i

      number = last_id + 1

      invnum = "#{start}#{date}#{number}"
    end

    invnum
  end

  def good_date(dd)
    dd = dd.to_s
    dd = '0' + dd if dd.length < 2
    dd
  end
end
