# -*- encoding : utf-8 -*-
# Rate bulk updater
class Tariff::RateUpdater
  include ActiveModel::Validations
  extend ActiveModel::Naming

  attr_accessor :tariff, :destination_group, :dg_name, :rate, :exchange_rate
  validates :rate, numericality: {
    message: _('new_rate_must_be_numeric')
  }

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def update_rates
    if valid?
      current_user = User.current_user
      new_rate = rate.to_d / exchange_rate.to_d
      destinatios_query = "destinations.name LIKE #{ActiveRecord::Base::sanitize(dg_name.to_s)} COLLATE utf8_general_ci"

      found_rates_count = Rate.where("#{destinatios_query} AND rates.tariff_id = #{@tariff.id}").
                              joins('LEFT JOIN destinations on rates.destination_id = destinations.id').count

      if found_rates_count > 1000
        errors.add(:count, _('Number_of_destinations_must_be_reduced'))
        return false
      elsif found_rates_count == 0
        errors.add(:count, _('No_Destinations_found'))
        return false
      else


        rates_to_update = Ratedetail.select('ratedetails.*, rates.id AS rate_id').
                                    joins("LEFT JOIN rates ON rates.id = ratedetails.rate_id AND rates.tariff_id = #{@tariff.id} LEFT JOIN destinations on rates.destination_id = destinations.id").
                                    where(destinatios_query)

        rates_to_update.update_all(rate: new_rate)
        rates_to_update.each do |rate|
          Action.add_action_hash(current_user, target_id: rate.rate_id, target_type: 'rates', action: 'Rate updated',  data: "Updated rate for tariff #{@tariff.name} from #{rate.rate} to #{new_rate}")
        end
      end
    else
      false
    end
  end

  def destination_group=(dg_id)
    @destination_group = Destinationgroup.where(id: dg_id).first
  end
end