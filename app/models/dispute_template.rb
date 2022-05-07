# -*- encoding : utf-8 -*-
# CDR Dispute Template model
class DisputeTemplate < ActiveRecord::Base
  attr_accessible :name, :billsec_tolerance, :cost_tolerance, :currency_id,
                  :cmp_last_src_digits, :cmp_last_dst_digits, :check_only_answered_calls

  has_one :dispute

  validates :cmp_last_src_digits, :cmp_last_dst_digits, inclusion: {
    in: 1..16, message: _('invalid_cmp_last')
  }
  validates :billsec_tolerance, numericality: {
    only_integer: true, greater_than_or_equal_to: 0,
    message: _('invlid_billsec_tolerance')
  }
  validates :cost_tolerance, numericality: {
    greater_than_or_equal_to: 0,
    message: _('invlid_cost_tolerance')
  }
  validates :name,
    uniqueness: {message: _('Dispute_Template_name_must_be_unique')},
    length: {minimum: 1, message: _('Dispute_Template_name_is_too_short')}
end
