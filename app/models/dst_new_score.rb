class Dst_new_score < ActiveRecord::Base

  validates_numericality_of :score, :only_integer => true, :message => 'asd'

  def self.table_name()
    'bl_dst_new_score'
  end

  attr_protected

  def self.default_score
    self.where(value: 'default').first.try(:score)
  end
end
