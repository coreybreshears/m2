# -*- encoding : utf-8 -*-
# Blocked Countries model
class BlockedCountries < ActiveRecord::Base
  attr_accessible :state, :direction_id
  belongs_to :direction

  def self.update(ids)
    return false if ids && ids.size >= valid.size

    ActiveRecord::Base.connection.execute(
      "UPDATE blocked_countries SET state = #{ids ? "IF(id IN(#{ids.map { |key, _| key }.join ','}),1,0)" : '0'}"
    )

    true
  end

  def self.list
    valid.order('directions.name')
  end

  def self.map_data
    valid.pluck(:iso3166code, :state, :name)
  end

  def self.valid
    joins(:direction).select('blocked_countries.id, name, code, iso3166code, state')
                     .where('iso3166code != "00"')
  end

  def self.countries_to_block(ids)
    valid.where("blocked_countries.id IN (#{ids.present? ? ids.join(',') : '-1'}) AND state = 0").all.pluck(:name)
  end

  def self.countries_to_unblock(ids)
    valid.where("blocked_countries.id NOT IN (#{ids.present? ? ids.join(',') : '-1'}) AND state = 1").all.pluck(:name)
  end
end
