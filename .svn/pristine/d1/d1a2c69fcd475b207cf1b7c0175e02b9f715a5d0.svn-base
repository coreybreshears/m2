# Aggregates Templates
class AggregateTemplate < ActiveRecord::Base
  TEXT_INPUTS = %w[s_originator_id s_originator s_op_device s_terminator s_terminator_id src dst
                   s_duration dst_group answered_calls s_tp_device s_manager
                  ].freeze

  CHECKBOXES = %w[price_orig_show price_term_show billed_time_orig_show billed_time_term_show
                  duration_show acd_show calls_answered_show asr_show calls_total_show profit_show
                  group_by_op group_by_originator group_by_terminator group_by_tp group_by_dst_group
                  group_by_dst pdd_show group_by_manager profit_percent_show
                 ].freeze

  RADIO_BUTTONS = %w[use_real_billsec from_user_perspective].freeze

  attr_accessible(*TEXT_INPUTS)
  attr_accessible(*CHECKBOXES)
  attr_accessible(*RADIO_BUTTONS)
  attr_accessible :name, :user_id

  validates :name,
            presence: {message: _('Name_cannot_be_blank')},
            uniqueness: {message: _('Name_must_be_unique'), scope: :user_id}

  before_save :validate_group_by

  def self.text_inputs
    TEXT_INPUTS
  end

  def self.checkboxes
    CHECKBOXES
  end

  def self.radio_buttons
    RADIO_BUTTONS
  end

  def to_hash
    options = {}
    attributes.each { |var| options[var[0].to_sym] = var[1] }
    options
  end

  def to_s
    options = {}
    attributes.each { |var| options[var[0].to_s] = var[1] }
    options
  end

  private

  def validate_group_by
    return true if [group_by_op, group_by_originator, group_by_terminator, group_by_tp, group_by_dst_group, group_by_dst, group_by_manager].map(&:to_i).include?(1)
    errors.add(:group, _('At_least_one_grouping_option_must_be_selected'))
    false
  end
end
