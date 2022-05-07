# -*- encoding: utf-8 -*-

# TP deviation model
class TpDeviation < ActiveRecord::Base
  attr_accessible :id, :device_id, :check_period, :check_since,
                  :asr_deviation, :acd_deviation, :user_id,
                  :email_id, :dial_peer_id

  belongs_to :dial_peer, -> { where(active: 1) }
  belongs_to :user
  belongs_to :device, -> { where(tp: 1, tp_active: 1) }
  belongs_to :email

  # Periods for deviation check must be positive integers
  validates :check_period, numericality: {
    only_integer: true,
    greater_than: 0,
    message: _('invalid_deviation_check_period')
  }
  validates :check_since, numericality: {
    only_integer: true,
    greater_than: 0,
    message: _('invalid_deviation_check_interval')
  }

  # Deviations for deviation check must be non-negative integers
  validates :asr_deviation, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    message: _('invalid_asr_deviation')
  }
  validates :acd_deviation, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    message: _('invalid_acd_deviation')
  }

  # Email template must be selected for reporting
  validates :email_id, numericality: {
    only_integer: true,
    greater_than: 0,
    message: _('email_must_be_selected')
  }

  # Should not be possible to create multiple observers for the same lcr
  validates :dial_peer_id, uniqueness: {
    message: _('dp_used_in_deviation')
  }

  # Relationship validations
  validate :validate_dp
  validate :validate_tp, if: -> { dial_peer.present? }
  validate :validate_report_receiver

  after_initialize :set_defaults, unless: :persisted?

  # Sets default values for an initial deviation observer
  def set_defaults
    # Default dp is the first suitable dp in a row
    self.dial_peer_id ||= DialPeer.where(active: 1).order(:name).first.try(:id)
    # Default main tp is the first active tp in the default dp
    self.device_id ||= dial_peer.active_tps.sort_by(&:nice_name).first.try(:id) if dial_peer
  end

  # Returns a report of monitored tps in relation to the main tp
  def deviation_report
    # Retrieves a period statistics from elasticsearch
    @tps = tps
    @stats = EsTpDeviations.tp_quality(@tps.map(&:id), check_since)
    return [] if @stats.empty?
    # Computes deviations and prepares a report
    @tps.map do |tp|
      tp_id = tp.id
      curr = @stats[tp_id]
      {
        id: tp_id,
        name: tp.nice_name,
        dp_id: dial_peer_id,
        deviation: compare_with(curr, main_stats)
      }.merge(curr)
    end
  end

  # Returns a hash indexed by deviation id containing reports
  #   of changed tp deviations
  def self.deviations_change_report
    to_check = all.select { |dev| (Time.zone.now.to_i / 60 % dev.check_period.to_i).zero? }
    Hash[to_check.select(&:deviation_valid?).map { |dev| [dev.id, dev.check_changes] }]
  end

  # Returns a deviation report for tps that have changed
  #   The essence of the method is to prevent multiple warnings
  #   and notify only when the state of tp deviation changes
  def check_changes
    tp_index = dpeer_tps.index_by(&:device_id)
    deviation_report.select do |row|
      tp = tp_index[row[:id]]
      dev = row[:deviation]
      warn = tp.warn_about_quality
      if dev[:warn_asr] || dev[:warn_acd]
        tp.update_attributes(warn_about_quality: 1) if warn.zero?
      elsif warn == 1
        tp.update_attributes(warn_about_quality: 0)
      end
    end
  end

  # Returns an ASR/ACD deviation data
  # +tp_qual+:: tp data which is compared to the main tp
  # +main_qual+:: main tp
  def compare_with(tp_qual, main_qual)
    main_asr = main_qual[:asr]
    main_acd = main_qual[:acd]
    asr_dev = (main_asr > 0 ? 100.0 * tp_qual[:asr] / main_asr - 100 : 0).round
    acd_dev = (main_asr > 0 ? 100.0 * tp_qual[:acd] / main_acd - 100 : 0).round
    {
      asr: asr_dev, warn_asr: asr_dev < -asr_deviation,
      acd: acd_dev, warn_acd: acd_dev < -acd_deviation
    }
  end

  # Returns a list of monitored tps
  def tps
    dial_peer.try(:active_tps) || []
  end

  # Dial peer termination points
  def dpeer_tps
    dial_peer.try(:active_dpeer_tpoints) || []
  end

  # Main tp statistics
  def main_stats
    @stats[device.try(:id)]
  end

  # Checks if main tp is active and present
  def main_active?
    dial_peer.try(:dpeer_tp_active?, device_id)
  end

  # Checks if deviation has valid associations
  def deviation_valid?
    device && user && !user.blocked? && email
  end

  def self.generate_emails
    changes = deviations_change_report.reject { |_, tps| tps.empty? }
    changes.map do |dev_id, change|
      dev = find_by(id: dev_id)
      # Names of changed tps
      tp_names = change.map { |tp| tp[:name] }.join(', ')
      {
        to: dev.user.try(:email).to_s.split(';'),
        email: dev.email,
        variables: {
          dp_id: dev.dial_peer_id,
          login_url: "#{Web_URL}#{Web_Dir}",
          dp_name: dev.dial_peer.name,
          asr_deviation: dev.asr_deviation,
          acd_deviation: dev.acd_deviation,
          tp_name: dev.device.nice_name,
          changed_tps: tp_names
        }
      }
    end
  end

  def warn?
    self.main_stats && (self.main_stats[:acd].zero? || self.main_stats[:asr].round.zero?)
  end

  private

  # Checks if a dial peer is active
  def validate_dp
    # Allows only non-blank and active dial peers
    errors.add(:base, _('dp_must_be_selected')) && return if dial_peer.blank?
    errors.add(:base, _('dp_must_be_active')) if dial_peer.active != 1
  end

  # Checks if tp is present and in a dial peer
  def validate_tp
    # Allows only non-blank tps from a selected dial peer
    errors.add(:base, _('tp_must_be_selected')) && return if device.blank? || device.tp_active.to_i != 1
    errors.add(:base, _('tp_not_in_dp')) unless dial_peer.devices.map(&:id).include?(device.id)
  end

  # Checks if a user and an email setup are valid
  def validate_report_receiver
    # Allows only non-blank users with email addresses
    errors.add(:base, _('user_must_be_selected')) && return if user.blank?
    errors.add(:base, _('user_must_have_email')) if user.try(:email).blank?
  end
end
