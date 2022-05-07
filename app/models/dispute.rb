# -*- encoding: utf-8 -*-
# CDR dispute model
class Dispute < ActiveRecord::Base
  attr_accessible :id, :user_id, :direction, :period_start, :period_end,
                  :time_zone, :time_shift, :billsec_tolerance, :cost_tolerance,
                  :cmp_last_src_digits, :cmp_last_dst_digits, :currency_id,
                  :dispute_template_id, :exchange_rate, :status, :check_only_answered_calls

  # Virtual attributes for template creation
  attr_reader :new_template, :template_name

  # Dispute associations
  belongs_to :dispute_template
  belongs_to :currency
  belongs_to :user
  has_many :disputed_cdrs

  # Dispute validations
  validates :user_id, numericality: {
    greater_than: 0,
    message: _('user_must_be_selected')
  }
  validates :direction, inclusion: {
    in: 0..1, message: _('invalid_dispute_direction')
  }
  validates :cmp_last_src_digits, :cmp_last_dst_digits, inclusion: {
    in: 1..16, message: _('invalid_cmp_last')
  }
  validates :exchange_rate, numericality: {
    greater_than: 0,
    message: _('Exchange_rate_must_be_greater_than_zero')
  }
  validates :billsec_tolerance, numericality: {
    only_integer: true, greater_than_or_equal_to: 0,
    message: _('invlid_billsec_tolerance')
  }
  validates :cost_tolerance, numericality: {
    greater_than_or_equal_to: 0,
    message: _('invlid_cost_tolerance')
  }
  validate :validate_associations
  validate :validate_periods

  before_destroy :check_status

  # Class for working with CDR dispute report groups
  #   aggregated by mismatch type
  class ReportGroup
    attr_reader :code, :mismatch_type, :fields, :aggs

    def initialize(code = '', data = {})
      # Group is identified by a code and a mismatch type
      @code = code.to_s
      @type = ReportGroup.types[code] || ''
      # Fields of a report group
      @fields = %i(loc_and_ext loc_and_ext_perc loc ext dt_calls loc_billsec
                   ext_billsec dt_billsec loc_price ext_price dt_price )
      # Aggregated group initialized with 0s
      @aggs = Hash[@fields.map { |field| [field, 0] }].merge(data)
    end

    # Computes delta values of data
    def compute_deltas
      @aggs[:dt_calls] = @aggs[:loc] - @aggs[:ext]
      @aggs[:dt_billsec] = @aggs[:loc_billsec] - @aggs[:ext_billsec]
      compute_price_deltas
    end

    # Compute price deltas
    def compute_price_deltas
      dt_price = @aggs[:loc_price] - @aggs[:ext_price]
      @aggs[:dt_price] = dt_price.abs > 1E-9 ? dt_price : 0
    end

    # Aggregates a given hash of report groups into itself
    def aggerage_into(groups)
      # Aggregate all groups except the already aggregated ones
      groups.except('TT', 'TC', 'TM', 'NM').each do |_, group|
        @fields.each { |key| @aggs[key] += group.aggs[key] }
      end
      compute_deltas
      self
    end

    # Converts a group into a hash (used by json converter)
    def to_hash
      {code: @code, mismatch_type: @type}.merge @aggs.except(:code)
    end

    # Computes totals
    def self.compute_totals(groups)
      # Aggregates all non-aggregated groups
      groups['TT'] = ReportGroup.new('TT').aggerage_into(groups)

      # Aggregates only specific ranges of groups
      groups['TM'] = ReportGroup.new('TM').aggerage_into groups.slice(* '21'..'23')
      groups['NM'] = ReportGroup.new('NM').aggerage_into groups.slice(* '31'..'99')
    end

    # Packs a all the report groups into an array
    def self.pack(groups)
      ReportGroup.compute_totals(groups)
      # Totals compared CDRs
      total = groups['TT'].aggs[:loc_and_ext]

      types.map do |code, _|
        group = groups[code] || ReportGroup.new(code)
        group.aggs[:loc_and_ext_perc] = total.zero? ? 0 : (100.0 * group.aggs[:loc_and_ext] / total).round
        group.to_hash
      end
    end

    # Forms an array of CDR dispute report groups
    def self.all_for_dispute(dispute, options)
      # Local CDRs cost field depends of dispute direction
      cost = dispute.direction.zero? ? 'user_price' : 'provider_price'
      # Local and external CDRs connected conditions
      loc_con_cond = "calls.disposition = 'ANSWERED'"
      ext_con_cond = "disputed_cdrs.disposition = 'ANSWERED' AND NOT is_placeholder"
      # Exchange rate for local and external CDRs
      loc_ex, ext_ex = dispute.count_exrates(options.slice(:s_curr, :d_curr))

      dispute_id = dispute.id

      # Aggregates data: connects two queries:
      #   The first one aggregates connected CDRs and groups under TC code;
      #   The second one aggregates all the other mismatch groups
      data = ActiveRecord::Base.connection.select(
        "SELECT
          aggs.*, loc + ext AS loc_and_ext, loc - ext AS dt_calls,
          loc_billsec - ext_billsec AS dt_billsec,
          loc_price - ext_price AS dt_price
        FROM (
          SELECT
            'TC' AS code,
            COALESCE(SUM(IF(#{loc_con_cond},1,0)),0) AS loc, COALESCE(SUM(IF(#{ext_con_cond},1,0)),0) AS ext,
            COALESCE(SUM(IF(#{loc_con_cond} AND calls.billsec IS NOT NULL, calls.billsec,0)),0) AS loc_billsec,
            COALESCE(SUM(IF(#{ext_con_cond} AND disputed_cdrs.billsec IS NOT NULL, disputed_cdrs.billsec,0)),0)
              AS ext_billsec,
            COALESCE(SUM(IF(#{loc_con_cond} AND calls.#{cost} IS NOT NULL, calls.#{cost}*#{loc_ex},0)),0) AS loc_price,
            COALESCE(SUM(IF(#{ext_con_cond} AND disputed_cdrs.cost IS NOT NULL, disputed_cdrs.cost*#{ext_ex},0)),0)
              AS ext_price
          FROM disputed_cdrs LEFT JOIN calls ON disputed_cdrs.call_id = calls.id
          WHERE dispute_id = #{dispute_id}

          UNION

          SELECT
            mismatch_type AS code,
            SUM(IF(disputed_cdrs.call_id IS NOT NULL, 1, 0)) AS loc,
            SUM(NOT is_placeholder) AS ext,
            SUM(IF(calls.billsec IS NOT NULL, calls.billsec, 0)) AS loc_billsec,
            SUM(IF(disputed_cdrs.billsec IS NOT NULL, disputed_cdrs.billsec, 0)) AS ext_billsec,
            SUM(IF(calls.#{cost} IS NOT NULL, calls.#{cost} * #{loc_ex}, 0)) AS loc_price,
            SUM(IF(disputed_cdrs.cost IS NOT NULL, disputed_cdrs.cost * #{ext_ex}, 0)) AS ext_price
          FROM disputed_cdrs LEFT JOIN calls ON disputed_cdrs.call_id = calls.id
          WHERE dispute_id = #{dispute_id}
          GROUP BY mismatch_type
        ) AS aggs"
      )
      # Converts keys to symbols, initializes objects and indexes by the mismatch codes
      data.map(&:symbolize_keys)
        .map { |row| ReportGroup.new(row[:code], row) }
        .index_by(&:code)
    end

    # Possible mismatch types of a dispute
    def self.types
      {
        'TT' => _('Total_Calls'),
        'TC' => _('Total_Connected'),
        '00' => _('Not_Compared'),
        '10' => _('Exact_Match'),
        'TM' => _('Tolerated_Mismatch'),
        '21' => _('Tolerated_mismatch_by_Price'),
        '22' => _('Tolerated_mismatch_by_Billsec'),
        '23' => _('Tolerated_mismatch_by_Price_and_Billsec'),
        'NM' => _('Mismatch'),
        '31' => _('Mismatch_by_Price'),
        '32' => _('Mismatch_by_Billsec'),
        '33' => _('Mismatch_by_Price_and_Billsec'),
        '40' => _('Connected_only_locally'),
        '42' => _('Connected_only_externally'),
        '70' => _('Local_duplicate'),
        '72' => _('External_duplicate'),
        '90' => _('Not_matched_by_any_field'),
        '99' => _('Errors')
      }
    end
  end

  # Initializer with virtual attributes
  def initialize(attributes = nil)
    check_if_new_template(attributes)
    super(attributes.try(:except, %w(new_template template_name')))
    time_now = Time.zone.now
    self.period_start ||= time_now
    self.period_end ||= time_now
  end

  # Updater with virtual attributes
  def update_attributes(attributes = nil)
    check_if_new_template(attributes)
    super(attributes.try(:except, %w(new_template template_name')))
  end

  # Forms a CDR dispute report
  def report(options)
    ReportGroup.pack(ReportGroup.all_for_dispute(self, options))
  end

  # Forms a detailed report for a given code
  def detailed_report(options)
    # Local CDRs price depends on the Dispute direction
    price = direction.zero? ? 'user_price' : 'provider_price'

    # Parameters for filtering
    src, dst, code, sort = Dispute.parse_options(options)

    # Exchange rate for local and external CDRs
    loc_ex, ext_ex = count_exrates(options.slice(:s_curr, :d_curr))

    # Appends additional where conditions for filtering
    conds = Dispute.filter_cond(code, src, dst)
    cond = " AND #{conds.join(' AND ')}" unless conds.empty?

    DisputedCdr
      .select(
        "disputed_cdrs.id, mismatch_type AS code,
        calls.src AS l_src, disputed_cdrs.src AS e_src,
        calls.dst AS l_dst, disputed_cdrs.dst AS e_dst,
        calls.calldate AS l_start_time,
        disputed_cdrs.start_time AS e_start_time,
        calls.answer_time AS l_answer_time,
        disputed_cdrs.answer_time AS e_answer_time,
        calls.billsec AS l_billsec, disputed_cdrs.billsec AS e_billsec,
        calls.billsec - disputed_cdrs.billsec AS dt_billsec,
        calls.#{price} * #{loc_ex} AS l_price, disputed_cdrs.cost * #{ext_ex} AS e_price,
        calls.#{price} * #{loc_ex} - disputed_cdrs.cost * #{ext_ex} AS dt_price"
      )
      .joins('LEFT JOIN calls ON disputed_cdrs.call_id = calls.id')
      .where("dispute_id = #{id} #{cond}")
      .order("#{sort[:by]} #{sort[:dir]}")
      .page(options[:page].to_i)
      .per(options[:page_size])
  end

  # Counts exchange rates for local and external CDRs
  def count_exrates(curr)
    s_curr = curr[:s_curr]
    [
      Currency.count_exchange_rate(s_curr, curr[:d_curr]).round(6),
      Currency.count_exchange_rate(s_curr, currency.name).round(6)
    ]
  end

  # Methods to get a status of a dispute
  def completed?
    %w(DONE FAILED).include? status
  end

  def done?
    status == 'DONE'
  end

  def failed?
    status == 'FAILED'
  end

  def in_progress?
    !completed?
  end

  def waiting?
    status == 'WAITING'
  end

  def total_local
    disputed_cdrs.where('call_id IS NOT NULL').size
  end

  def total_external
    disputed_cdrs.where('NOT is_placeholder').size
  end

  def info
    str = ''
    {
      "#{_('Status')}" => status,
      "#{_('Direction')}" => direction.zero? ? _('Origination') : _('Termination'),
      "#{_('Compare_last_SRC_digits')}" => cmp_last_src_digits,
      "#{_('Compare_last_DST_digits')}" => cmp_last_dst_digits,
      "#{_('External_Currency')}" => currency.try(:name),
      "#{_('Exchange_rate')}" => exchange_rate.round(6),
      "#{_('Billsec')} #{_('Tolerance')}" => billsec_tolerance,
      "#{_('Price')} #{_('Tolerance')}" => cost_tolerance.round(6),
      _('Check_only_ANSWERED_Calls') => check_only_answered_calls == 1 ? _('_Yes') : _('_No')
    }.each { |key, val| str << "#{key}: #{val}<br/>" }
    str
  end

  # Period setters
  def period_start=(date)
    self[:period_start] = date.to_datetime
  rescue ArgumentError
    self[:period_start] = Time.zone.now
  end

  def period_end=(date)
    self[:period_end] = date.to_datetime
  rescue ArgumentError
    self[:period_end] = Time.zone.now
  end

  # Creates a child relation: Dispute Template
  def create_template
    return unless @new_template
    tpl = DisputeTemplate.new(
      attributes.slice(
        'billsec_tolerance', 'cost_tolerance', 'cmp_last_src_digits',
        'cmp_last_dst_digits', 'currency_id', 'check_only_answered_calls'
      ).merge(name: @template_name)
    )
    return self.dispute_template = tpl if tpl.save
    # Only name errors are interesting because others are handled in a dispute
    tpl.errors[:name].try(:each) { |err| errors.add(:base, err) }
  end

  # Parses and validates options for a detailed report
  def self.parse_options(options)
    [
      validate_number(options[:src]),
      validate_number(options[:dst]),
      validate_code(options[:code]),
      validate_sort(options.slice(:order_by, :order_desc))
    ]
  end

  # Validates a number format and sanitizes it
  def self.validate_number(number)
    # Number is valid if it has at least some other symbol
    #   than a wild card and is not empty
    ActiveRecord::Base.sanitize(number) if number && number !~ /^[%_]*$/
  end

  # Validates a mismatch code and converts partial codes
  #   to numeric codes
  def self.validate_code(code)
    # Specific cases for TT (total CDRs) and
    #   TC (total connected) partial codes
    return nil if code.blank? || code == 'TT'
    return 'TC' if code == 'TC'

    # Converts other partial codes to numeric ones
    case code
      when 'TM'
        '21, 22, 23'
      when 'NM'
        '31, 32, 33, 40, 42, 70, 72, 90, 99'
      else
        ReportGroup.types[code] ? code : '00'
    end
  end

  # Sets sorting options
  def self.validate_sort(sort)
    order_by = sort[:order_by]
    order_options = %w(l_src e_src l_dst e_dst l_start_time e_start_time
      l_answer_time e_answer_time l_billsec e_billsec dt_billsec
      l_price e_price dt_price mismatch_type)
    {
      by:  order_options.include?(order_by) ? order_by : :mismatch_type,
      dir: sort[:order_desc].to_i.zero? ? 'ASC' : 'DESC'
    }
  end

  # Collects conditions for filtering the detailed report
  def self.filter_cond(code, src, dst)
    cond = []
    cond << "mismatch_type IN (#{code})" if code && code != 'TC'
    cond << "(calls.disposition = 'ANSWERED' OR disputed_cdrs.disposition = 'ANSWERED')" if code == 'TC'
    cond << "(calls.src LIKE #{src} OR disputed_cdrs.src LIKE #{src})" if src
    cond << "(calls.dst LIKE #{dst} OR disputed_cdrs.dst LIKE #{dst})" if dst
    cond
  end

  protected

  # Checks if a new template should be created
  def check_if_new_template(attributes)
    return if attributes[:new_template].to_i.zero?
    @new_template = attributes[:dispute_template_id].blank?
    @template_name = attributes[:template_name]
  end

  # Checks if a user is valid and appropriate for the direction
  def valid_user?
    user = User.find_by(id: user_id)
    return false unless user.present?
    devices = user.devices
    if direction.to_i.zero?
      # If direction is origination, a user must have origination points
      return false if devices.where(op: 1).size.zero?
    else
      # If direction is termination, a user must have termination points
      return false if devices.where(tp: 1).size.zero?
    end
    true
  end

  # Checks if associations exist and are valid
  def validate_associations
    return if errors.present?
    create_template
    errors.add(:base, _('Invalid_Currency')) if Currency.where(id: currency_id).blank?
    if dispute_template_id.present? && DisputeTemplate.where(id: dispute_template_id).blank?
      errors.add(:base, _('Invalid_Template'))
    end
    errors.add(:base, _('Invalid_User')) unless valid_user?
  end

  # Validates period range
  def validate_periods
    return if period_start < period_end
    errors.add(:base, _('invalid_periods'))
  end

  def check_status
    return false unless completed? || waiting?
    DisputedCdr.where(dispute_id: id).delete_all
  end
end