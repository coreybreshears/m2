# -*- encoding : utf-8 -*-
class Blank < ActiveRecord::Base

  attr_accessible :id, :name, :date, :description, :value1, :value2, :value3, :value4, :value5, :value6, :balance

  validates_presence_of :name, message: _('Blank_must_have_name')
  validates_numericality_of :value1, only_integer: true, allow_nil: true, greater_than_or_equal_to: 0, message: _('value1_must_be_integer')
  validates_numericality_of :value2, allow_nil: true, message: _('value2_must_be_number')
  validates_numericality_of :balance, allow_nil: true, message: _('balance_must_be_number')

  def self.order_by(options, items_per_page)
    order_by, order_desc = [options[:order_by], options[:order_desc]]
    order_string = ''
    unless order_by.blank? || order_desc.blank?
      order_string << "#{order_by} #{order_desc.to_i.zero? ? 'ASC' : 'DESC'}" if Blank.accessible_attributes.member?(order_by)
    end
    selection = Blank.order(order_string)
    selection = options[:csv].to_i.zero? ? selection.page(options[:page]).per(items_per_page) : selection
  end

  def self.filter(options, session_from, session_till)
    max_value = options[:s_max_value2]
    min_value = options[:s_min_value2]
    name = options[:s_name]
    value4 = options[:s_value4]
    value5 = options[:s_value5]
    value6 = options[:s_value6].to_i

    where = []
    where << "name LIKE #{ActiveRecord::Base::sanitize(name)}" if name.present?
    where << "value4 = #{ActiveRecord::Base::sanitize(value4)}" if value4.present? && value4 != 'any'
    where << "value5 = #{ActiveRecord::Base::sanitize(value5)}" if value5.present? && value5 != 'All'
    where << "value6 = #{ActiveRecord::Base::sanitize(value6)}" if value6.present? && value6 != -2
    where << "value2 >= #{min_value}" if min_value.present?
    where << "value2 <= #{max_value}" if max_value.present?
    where << "date >= '#{session_from}'"
    where << "date <= '#{session_till}'"

    if [min_value, max_value].any? { |var| (/^(?!0\d)\d*(\.\d+)?$/ !~ var && var.present?) }
      return Blank.none
    end

    Blank.where(where.join(' AND '))
  end

  def providers_for_select
    Device.where(tp: 1, tp_active: 1)
  end

  def provider_by_id(id)
    return unless id
    if id >= 0
      Device.where(tp_active: 1, id: id).first
    else
      _('None')
    end
  end

  def self.params_date
    {
        year: Time.now.year,
        month: Time.now.month,
        day: Time.now.day,
        hour: Time.now.hour,
        minute: Time.now.min
      }
  end
end
