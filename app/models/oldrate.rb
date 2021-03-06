# Rate model
class Rate < ActiveRecord::Base
  attr_accessor :rate
  attr_protected

  belongs_to :destination
  belongs_to :destinationgroup
  belongs_to :tariff
  has_many :ratedetails, -> { order('daytype DESC, start_time ASC') }

  validates_presence_of :tariff_id
  validates_presence_of :destination_id

  scope :prefix_group, ->(is_user) {group('rates.prefix') if is_user}

  def ratedetails_by_daytype(daytype)
    Ratedetail.where("rate_id = #{self.id} AND daytype = '#{daytype}'").order('daytype DESC, start_time ASC').all
  end

  def destroy_everything

    # rate details
    self.ratedetails.each { |ratedetail| ratedetail.destroy }
    self.destroy
  end

  def Rate.get_provider_rate(call, direction, exrate)
    prov_price = call.provider_price
    rate_cur, rate_cpr = Currency.count_exchange_prices({exrate: exrate, prices: [call.user_price.to_d, prov_price.to_d]})
    return rate_cur, rate_cpr
  end

  def Rate.get_provider_rate_details(rate, exrate)
    @rate_details = Ratedetail.where("rate_id = #{rate.id.to_s}").order('rate DESC').all
    if @rate_details.size > 0
      @rate_increment_s = @rate_details[0]['increment_s']
      @rate_cur, @rate_free = Currency.count_exchange_prices({exrate: exrate, prices: [@rate_details[0]['rate'].to_d, @rate_details[0]['connection_fee'].to_d]})
    end
    return @rate_details, @rate_cur
  end

  def self.selection(select, join, condition, params, items_per_page, group_by, custom_tariff_id = 0)
    if params[:action] == 'rates_list'
      allowed_order_by = %w[prefix destinations.name rate connection_fee ratedetails.increment_s ratedetails.min_time ratedetails.blocked ratedetails.start_time ratedetails.end_time ratedetails.daytype effective_from]
      params[:order_by] = 'destinations.name' unless allowed_order_by.include?(params[:order_by].to_s)

      order_desc = params[:order_desc].to_i == 1 ? 'DESC' : 'ASC'

      order_by = if custom_tariff_id == 0
                   params[:order_by] + ' ' + order_desc + ', rates.prefix ASC, rates.effective_from DESC'
                 else
                   params[:order_by].gsub('ratedetails.', '').gsub('destinations.name', 'destinations_name').gsub('destinations.', '') + ' ' + order_desc + ', prefix ASC, effective_from DESC'
                 end
    else
      order_by = ''
    end

    params[:page] = 1 unless params[:page]

    if custom_tariff_id != 0 && params[:action] == 'rates_list' && User.current.is_user?

      sql = "SELECT * FROM
              (
                SELECT * FROM
                (
                  SELECT #{select}, IF(tariffs.purpose = 'user_custom',0,1) AS order_priority, rate, connection_fee, ratedetails.increment_s, ratedetails.min_time, ratedetails.blocked, destinations.name AS name, start_time, end_time, daytype
                  FROM rates
                  JOIN tariffs ON tariffs.id = rates.tariff_id
                  #{join}
                  WHERE #{condition}
                  GROUP BY #{group_by}
                ) AS custom_tariff_rates
                ORDER BY custom_tariff_rates.order_priority
              ) AS prioritized_rates
              GROUP BY prioritized_rates.id
              ORDER BY #{order_by}
              "
      rates = Rate.find_by_sql(sql)
    else
      rates = Rate.select(select)
                  .joins('JOIN tariffs ON tariffs.id = rates.tariff_id')
                  .joins(join)
                  .where(condition)
                  .group(group_by)
                  .order(order_by)

      rates = Rate.select('*').from(rates) if params[:action] == 'rates_list' && User.current.is_user?
    end

    return rates if "#{params[:controller]}/#{params[:action]}" == 'tariffs/list'
    return Kaminari.paginate_array(rates).page(params[:page]).per(items_per_page) if rates.kind_of?(Array)
    rates.page(params[:page]).per(items_per_page)
  end

  def quick_create(attributes = {})
    attributes ||= {}
    attributes.each do |name, value|
      self.send("#{name}=", value) if name != 'rate'
    end
    @rate = attributes[:rate]
    @changed = true if !attributes.blank?

    @model_cache = {}
  end

  def quick_save
    already_set?
    tariff_present?
    prefix_present?
    valid_rate?

    if errors.size == 0
      tmp_destination = @model_cache[:destination]
      self.destination_id = tmp_destination.id
      rate_detail = Ratedetail.new(rate: @rate)
      self.ratedetails << rate_detail

      self.save
    else
      false
    end
  end

  def changed?
    !!@changed
  end

  def self.separated_rates(destination_id)
    rate = Rate.where(destination_id: destination_id)

    rate_details = []
    rate1 = []
    rate2 = []
    rate.each do |rat|
      if rat.tariff.purpose == 'provider'
        rate1[rat.id] = rat.tariff.name
        rate_details[rat.id] = Ratedetail.where(rate_id: rat.id).first
      elsif rat.tariff.purpose == 'user_wholesale'
        rate2[rat.id] = rat.tariff.name
        rate_details[rat.id] = Ratedetail.where(rate_id: rat.id).first
      end
    end
    [rate, rate1, rate2, rate_details]
  end

  def self.delete_effective_date(rates)
    rates.each do |rate|
      rate.effective_from = nil
    end
  end

  # Sets a high rate value if valid
  def self.save_high_rate(value)
    value = value.sub(/[,;]/, '.').to_f
    value = 0.0 if value <= 0
    Confline.set_value('High_Rate', value)
    value
  end

  # Returns a high rate value or 1.0 when not present
  def self.high_rate
    (Confline.get('High_Rate').try(:value) || 1.0).to_f
  end

  def tariff_changes_present_set_1
    try(:tariff).try(:changes_present_set_1)
  end

  private

  def valid_rate?
    rate.gsub!(/[\,\.\;]/, '.')
    unless rate.to_s =~ /^-?[\d]+([\,\.\;][\d]+){0,1}$/
      errors.add(:base, _('new_rate_must_be_numeric'))
      false
    end
  end

  def already_set?
    if Rate.where(tariff_id: tariff_id, prefix: prefix, effective_from: effective_from).present?
      errors.add(:base, _('Rate_already_set'))
      false
    end
  end

  def tariff_present?
    unless @model_cache[:tariff] = Tariff.where(id: tariff_id).first
      errors.add(:tariff_id, _('tariff_was_not_found'))
      false
    end
  end

  def prefix_present?
    @model_cache[:destination] = Destination.where(prefix: self.prefix).first
    if @model_cache[:destination].blank?
      errors.add(:prefix, _('Destination_not_found'))
      false
    elsif self.prefix.to_i.to_s != self.prefix.to_s
      errors.add(:prefix, _('Destination_Prefix_is_not_numeric'))
      false
    end
  end
end
