# -*- encoding : utf-8 -*-
# Number Model for Number Pools
class Number < ActiveRecord::Base
  belongs_to :number_pool
  attr_accessible :number, :number_pool_id

  after_create  :np_data_changed
  after_save    :np_data_changed?
  after_destroy :np_data_changed

  def np_data_changed?
    np_data_changed if self.changed_attributes.present?
  end

  def np_data_changed
    self.number_pool.np_data_changed
  end


  def self.numbers_order_by(options)
    order_by = options[:order_by].to_s.strip
    return 'id' unless %w(id number counter).include?(order_by)
    order_by << (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC')
  end

  def self.retrieve(wcard, order)
    (wcard.present? ? where('number LIKE ?', wcard) : all).order(order)
  end

  def check_pattern
    self.pattern = (number.include?('%') ? 1 : 0)
  end
end
