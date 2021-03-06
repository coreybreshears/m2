# -*- encoding : utf-8 -*-
# Ratedetails model
class Ratedetail < ActiveRecord::Base
  attr_protected

  before_save :validate_blocked

  def Ratedetail.find_all_from_id_with_exrate(options = {})
    if options[:rates] and options[:rates].size.to_i > 0
      sql = "SELECT ratedetails.*, rate * #{options[:exrate].to_d} as erate, connection_fee * #{options[:exrate].to_d} as conee #{', directions.*' if options[:directions]}  #{', directions.name as dname' if options[:directions]} #{', destinations.*' if options[:destinations]} FROM ratedetails join rates on (rates.id = ratedetails.rate_id) join destinations on (rates.destination_id = destinations.id) join directions on (destinations.direction_code = directions.code) where rate_id in (#{(options[:rates].collect { |rate| rate.id }).join(' , ')}) ORDER BY directions.name ASC, destinations.prefix ASC, ratedetails.daytype DESC, ratedetails.start_time ASC, rates.id  ASC"
      ratesd = Ratedetail.find_by_sql(sql)
      ratesd
    end
  end

  def combine_work_days
    combine_day_type('WD')
  end

  def combine_free_days
    combine_day_type('FD')
  end

  def split
  	new_rate_detail = Ratedetail.new(attributes)
    new_rate_detail.daytype = 'FD'
    new_rate_detail.save

    self.daytype = 'WD'
    save
  end

  def combine_day_type(day_type)
  	if daytype == day_type
      self.daytype = ''
      save
    else
      destroy
    end
  end

  def action_on_change(user)
    return if previous_changes.empty?
    Action.ratedetail_change(user, self)
  end

  def tariff_changes_present_set_1
    Rate.where(id: rate_id).first.try(:tariff_changes_present_set_1)
  end

  def validate_increment_and_min_time(params)
    details = params[:ratedetail]
    errors.add(:increment_value_must_be_integer_greater_than_or_equal_to_1, _('Increment_value_must_be_integer_greater_than_or_equal_to_1')) if details[:increment_s].try(:to_i) < 1
    errors.add(:min_time_value_must_be_integer_greater_than_or_equal_to_0, _('Min_Time_value_must_be_integer_greater_than_or_equal_to_0')) if details[:min_time].try(:to_i) < 0
  end

  private

  def validate_blocked
    self.blocked = 1 if rate.to_i == -1
  end
end
