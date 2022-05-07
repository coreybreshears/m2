# -*- encoding : utf-8 -*-
class Currency < ActiveRecord::Base

  attr_protected

  has_many :users
  has_many :disputes

  validates_length_of :name, maximum: 5, message: _('Currency_Name_is_to_long_Max_5_Symbols')
  validates_numericality_of :exchange_rate, greater_than: 0.to_d, message: _('Currency_exchange_rate_cannot_be_blank')
  validates_presence_of :name, message: _('Currency_must_have_name')
  validates_uniqueness_of :name, message: _('Currency_Name_Must_Be_Unique')
  validate :is_used_by_users?

  before_save :set_update_date

  scope :first_active, ->(id) { where(id: id, active: 1).first }

  def tariffs
    Tariff.find_by_sql ["SELECT tariffs.id FROM tariffs WHERE currency = ?", self.name, self.name]
  end

  def is_used_by_users?
    if active == 0 and not users.count.zero?
      errors.add(:active, _('currency_is_used_by_users'))
    end
  end

  def Currency::get_active
    Currency.where(active: '1').all
  end

  def Currency.count_exchange_rate(curr1, curr2)
    # curr1 is ko
    # curr2 i ka
    if curr1 == curr2
      return 1.0
    else
      curr1 = Currency.where(name: curr1).first if curr1.class != Currency
      curr2 = Currency.where(name: curr2).first if curr2.class != Currency
      if curr2 and curr1 and curr1.exchange_rate.to_d != 0.0
        # preventing ruby Infinity number
        balance = curr2.exchange_rate.to_d / curr1.exchange_rate.to_d
        balance.to_s == 'Infinity' ? balance = 0.to_d : false
        return balance
      else
        return 0.0
      end
    end
  end

  def Currency.count_exchange_prices(options = {})
    if options[:exrate].to_d > 0.to_d
      new_prices = []
      options[:prices].each { |price| new_prices << price.to_d * options[:exrate].to_d }
      a = new_prices #.to_sentence
    else
      a = options[:prices] #.to_sentence
    end
    if a.size == 1
      return a[0]
    else
      return *a
    end
  end

  # Wrapper method. For future caching.

  def Currency.get_by_name(name)
    Currency.where(name: name).first
  end

  def Currency.get_default
    Currency.where(id: 1).first
  end

  def set_default_currency
    old_curr = Currency.get_default
    begin
      transaction do
        change_default_currency(old_curr, self)
        notice = Currency.update_currency_rates
        if notice
          return old_curr.name
        else
          change_default_currency(old_curr, self)
          return false
        end
      end
    rescue => e
      change_default_currency(old_curr, self)
      return false
    end
  end

  # Action is called from daily_actions and from GUI -> Settings
  # If it is called from daily_actions there will be no session, so user.current is undefined.
  def self.update_currency_rates(update_currency_id = -1)
    notice = true
    default_currency = Currency.get_default.name
    currencies = Currency.where(update_currency_id.to_i > 0 ? {id: update_currency_id} : 'curr_update = 1 AND id != 1').pluck(:name).join(',')

    if currencies.present?
      MorLog.my_debug('API to CRM currency_exchange_rate', true)
      require 'net/http'
      source = "https://support.ocean-tel.uk/api/currency_exchange_rate?base_currency=#{default_currency}&currencies=#{currencies}"

      3.times do
        MorLog.my_debug('API to CRM currency_exchange_rate', true)
        MorLog.my_debug("  Request URL: #{source}")
        begin
          @result = JSON.parse(Net::HTTP.get_response(URI.parse(source)).body)
          MorLog.my_debug("  JSON Response: #{@result}")
          break if @result && (@result['success'].to_i == 1 || (@result['success'].to_i == 0 && @result['error_message'].to_s == 'Server not authenticated'))
        rescue => exception
          MorLog.my_debug("  EXCEPTION: #{exception}")
          sleep 3
          next
        end
      end

      if @result && @result['success'].to_i == 1
        @result['currency_exchange_rate'].each do |currency_name, exchange_rate|
          currency = Currency.where(name: currency_name).first
          next if currency.blank?

          if exchange_rate != 0
            currency.exchange_rate = exchange_rate.to_d
            currency.save
          else
            Action.add_action_hash(User.current ? User.current.id : 0, {target_id: currency.id, target_type: 'currency', action: 'failed_to_update_currency', data: currency.exchange_rate})
          end
        end

        Action.add_action(User.current ? User.current.id : 0, 'Currency updated', update_currency_id)
      elsif @result && @result['success'].to_i == 0 && @result['error_message'].to_s == 'Server not authenticated'
        Action.add_action(User.current ? User.current.id : 0, 'Failed to update currency, because this Server installation was not authenticated in Kolmisoft System', update_currency_id)
        notice = nil
      else
        Action.add_action(User.current ? User.current.id : 0, 'Failed to update currency', update_currency_id)
        notice = false
      end
    end

    notice
  end

  def update_rate
    begin
      transaction do
        Currency.update_currency_rates(self.id)
      end
    rescue => exception
      MorLog.my_debug('Currency.rb update_rate', true)
      MorLog.my_debug("  EXCEPTION: #{exception}")
      return false
    end
  end

  def Currency.check_first_for_active
    currency = Currency.get_default
    if currency.present? && currency.active == 0
      currency.active = 1
      currency.save
    end
  end

  def change_default_currency(old_curr, new_curr)
          temp_curr = old_curr.dup
          old_curr.assign_attributes({
            name: new_curr.name,
            full_name: new_curr.full_name,
            exchange_rate: 1,
            active: 1
          })
          old_curr.save(validate: false)
          new_curr.assign_attributes({
            name: temp_curr.name,
            active: 0,
            full_name: temp_curr.full_name
          })
          new_curr.save(validate: false)
  end

end

  def set_update_date
    self.last_update = Time.now
  end
