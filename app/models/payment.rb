# -*- encoding : utf-8 -*-
class Payment < ActiveRecord::Base
  attr_protected

  belongs_to :user, -> { (includes([:tax]) }

  after_create { |record| Action.add_action_hash(User.current, action: 'manual_payment_created', data: record.user_id, data2: record.amount, data3: record.currency, target_id: record.id, target_type: 'Payment') if record.paymenttype.to_s == 'manual' }

  after_destroy { |record| Action.add_action_hash(User.current, action: 'manual_payment_deleted', data: record.user_id, data2: record.amount, data3: record.currency, target_id: record.id, target_type: 'Payment') if record.paymenttype.to_s == 'manual' }

  def count_exchange_rate(curr1, curr2)
    (curr1 != curr2) ? Currency.count_exchange_rate(curr1, curr2) : 1
  end

  def payment_amount
    user = self.user
    pa = self.amount
    if self.paymenttype == 'manual' and user
      pa = self.tax ? self.amount.to_d - self.tax.to_d : user.get_tax.count_amount_without_tax(self.amount.to_d)
    end
    pa
  end

  def payment_amount_with_vat(nice_number_digits)
    self.tax ? (self.amount.to_d + self.tax.to_d) : self.amount
  end

  def amount_to_system_currency
    self.amount * Currency.count_exchange_rate(self.currency, Currency.get_default)
  end

  def Payment.add_global(details = {})
    Payment.create({shipped_at: Time.now, date_added: Time.now, completed: 1, currency: Currency.get_default}.merge(details))
  end

  def Payment.create_for_user(user, params = {})
    user = User.where(id: user.id).first if user.class == Fixnum
    user ? Payment.new({
                           user_id: user.id,
                           first_name: user.first_name,
                           last_name: user.last_name,
                           date_added: Time.now,
                           owner_id: user.owner.id
                       }.merge(params)) : false
  end

=begin
  All payments for financial data.

  *Params*
  +owner_id+ owner of users that the user is interested in, but might be nil if
     current user if ordinary user
  +user_id+ user that has invoices generated for him, might be nil if admin,
     reseller or accountatn is not interested i certain user, but interested in all his users.
     BUT IF we are generating financial statemens for ordinary users, they cannot see other users
     information and must supply theyr own id
  +status+ valid status parameter would be 'paid' 'unpaid' or 'all', might be nil
     in that case all statuses would be selected
  +from_date, till_date+ dates as strings
  +ordinary_user+ if user is of type 'user' there is no need to join users table, but user_id mus
     be specified.
  +currency_name+ since payments may be in any currency, one must specify currency name that he
     wants payment prices to be represented.

  *Returns*
  +array of MockPayment instances+
=end
  def self.financial_statements(owner_id, user_id, status, from_date, till_date, ordinary_user, currency_name)
    condition = ["payments.date_added BETWEEN '#{from_date} 00:00:00' AND '#{till_date} 23:59:59'"]
    condition << "payments.owner_id = #{owner_id}" unless ordinary_user
    condition << "payments.user_id = #{user_id}" if user_id and user_id != 'all'
    if status != 'all' and ['paid', 'unpaid'].include? status
      condition << "payments.completed = #{(status == 'paid') ? 1 : 0}"
    end

    recalculate_payments(Payment.includes(:user).where(condition.join(" AND\n")).references(:user).to_a, currency_name)
  end

=begin
  Since to callculate payment price, price with taxes and to convert it to users currency
  we need every payment and can not group it so that database server would just sum up prices,
  like we have done with credit notes or invoices. this is the method to do everyting:
  1. count price of payment in specified currency
  2. count price with tax in specified currency
  3. group all payments by theyr status
  4. sum it all up
  5. return information about all paid and unpaid payments.

  *Params*
  +payments+ iterable of payment instances

  *Return*
  +array of payment data+ information about paid and unpaid payments
=end
  def self.recalculate_payments(payments, currency_name)
    Struct.new('MockPayment', :count, :price, :price_with_vat, :status)
    paid = Struct::MockPayment.new(0, 0, 0, 'paid')
    unpaid = Struct::MockPayment.new(0, 0, 0, 'unpaid')
    for payment in payments
      exchange_rate = Currency.count_exchange_rate(payment.currency, currency_name)
      price = Currency.count_exchange_prices(exrate: exchange_rate, prices: [payment.payment_amount.to_d])
      price_with_vat = Currency.count_exchange_prices(exrate: exchange_rate, prices: [payment.payment_amount_with_vat(0)])
      if payment.completed != 0
        paid.count += 1
        paid.price += price
        paid.price_with_vat += price_with_vat
      else
        unpaid.count += 1
        unpaid.price += price
        unpaid.price_with_vat += price_with_vat
      end
    end
    return paid, unpaid
  end

  def self.unnotified_payment(payment_type)
    current_user = User.current

    initial_attributes = {
      paymenttype: payment_type,
      date_added: Time.now,
      completed: 0,
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      user: current_user,
      pending_reason: 'Unnotified payment',
      owner_id: current_user.owner_id
    }

    payment = Payment.new(initial_attributes)

    yield(payment) if block_given?

    payment.save and payment
  end
end
