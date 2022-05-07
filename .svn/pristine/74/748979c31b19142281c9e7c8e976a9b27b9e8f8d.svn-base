# -*- encoding : utf-8 -*-
# Quality Routing model
class QualityRouting < ActiveRecord::Base
  validates         :formula, presence: {message: _('Quality_Index_Formula_must_be_provided')}
  validates         :name, presence: {message: _('Quality_Routing_name_must_be_provided')},
                           uniqueness: {message: _('Quality_Routing_name_must_be_unique')}
  validate          :validate_index_params
  validate          :validate_eval

  before_validation :format_params

  before_destroy    :check_usage

  # Checks if a single attribute is valid
  def valid_attribute?(attribute_name)
    valid?
    errors[attribute_name].blank?
  end

  # Returns a list of Quality Routings
  def self.list
    find_by_sql("SELECT quality_routings.*,
      ( SELECT COUNT(*) FROM devices
        WHERE devices.quality_routing_id = quality_routings.id
      ) AS used
      FROM quality_routings
      ORDER BY name ASC")
  end

  # Returns permitted attributes for a model.
  #   Required for higher Rails versions
  def self.writable_attrs
    [
      :name, :formula, :asr_calls, :asr_period, :acd_period, :total_calls, :total_calls_period,
      :total_answered_calls, :total_answered_period, :total_failed_calls, :total_failed_period,
      :total_billsec_calls, :total_billsec_period, :acd_calls
    ]
  end

  # Retrieves Quality Routing Stats
  def self.stats(dp_id, qr_id, dst)
    # File where we put a Radius request
    path_to_file = "/tmp/m2/m2_quality_routing_stats/stats_#{dp_id}.m2_quality_routing"
    # Write the request pn file
    prepare_stats_file(path_to_file, dp_id, qr_id, dst)

    # Send the request
    port = Confline.get_value('RADIUS_PORT')
    radius_port = port.present? ? port : 1812
    host = Confline.get_value('RADIUS_HOST')
    radius_host = host.present? ? host : 'localhost'

    system "/usr/local/bin/radclient -r 1 -t 3 #{radius_host}:#{radius_port} auth m2 -f #{path_to_file}"
    system "rm -rf #{path_to_file}"
    wait_for_stats(dp_id, qr_id) || []
  end

  # Private Singleton Calss methods
  class << self
    private

    # Writes a Radius request on file
    def prepare_stats_file(path_to_file, dp_id, qr_id, dst)
      system "rm -rf #{path_to_file} && touch #{path_to_file} && chmod 777 #{path_to_file}"
      unique_id = `uuid`.to_s.strip
      File.open(path_to_file, 'w') do |file|
        file.write('h323-remote-address = "127.0.0.1"'\
          "\nUser-Name = \"#{dst}\""\
          "\nCalling-Station-Id = \"#{dp_id}\""\
          "\nCalled-Station-Id = \"#{qr_id}\""\
          "\nCisco-AVPair = \"freeswitch-src-channel=m2_quality_routing_data\""\
          "\ncall-id = \"#{unique_id}\""\
          "\nAcct-Session-Id = \"#{unique_id}auth\""\
          "\nService-Type = Authenticate-Only"\
          "\nNAS-Port = 0"\
          "\nNAS-IP-Address = 127.0.0.1")
      end
    end

    # Waits till Radius responds and formats data as json
    def wait_for_stats(dp_id, qr_id)
      counter = 1

      loop do
        qr_stats = ActiveRecord::Base.connection.select("SELECT * FROM quality_routing_stats
          WHERE dp_id = #{dp_id} AND quality_routing_id = #{qr_id}").first['csv']
        return (qr_stats.try(:split, "\n").try(:map) { |csv| csv.split(',') } || []) if qr_stats.present? || counter > 3
        sleep(1)
        counter += 1
      end
    end
  end

  def formula_has_price?
    formula.include?('PRICE')
  end

  private

  # Checks if any OP's use the QR
  def check_usage
    if Device.where(quality_routing_id: id).present?
      errors.add(:used_by_device, _('Quality_Routing_is_used'))
      return false
    end
    ActiveRecord::Base.connection.execute("DELETE FROM quality_routing_stats
      WHERE quality_routing_id = #{id}")
  end

  # Formats the params before save
  def format_params
    self.formula = formula.strip.upcase
    name.strip! if name.present?
  end

  # Validates Quality Index params
  def validate_index_params
    params = [
      asr_calls, acd_calls, total_calls, total_answered_calls,
      total_failed_calls, total_billsec_calls
    ]
    # If you change a range, do not forget to change an error message
    params.reject! { |param| (1..200).cover? param }
    errors.add(:params, _('Quality_Index_Parameters_range')) && (return false) unless params.empty?
  end

  # Encapsulates the formula evaluation scope to only allowed variables.
  #   Creates a binding instance for eval
  class EvalScope
    def params
      asr = acd = total_calls = total_answered = total_failed = total_billsec = price = weight = percent = 1
      binding
    end
  end

  # Check if a formula is valid
  def validate_eval
    # Checks if there were no unallowed variables
    return false unless valid_params?
    # Finally evaluate for sytax errors
    eval(formula.downcase, EvalScope.new.params)
  rescue ZeroDivisionError
    return true
  rescue SyntaxError, NameError
    errors.add(:formula, _('Quality_Index_Formula_is_not_correct')) && (return false)
  end

  def valid_params?
    # List of allowed variables
    # DO NOT REFACTOR! Word array will not work in this case
    allowed_params = ['ASR', 'ACD', 'TOTAL_CALLS', 'TOTAL_ANSWERED', 'TOTAL_FAILED',
      'TOTAL_BILLSEC', 'PRICE', 'WEIGHT', 'PERCENT']
    # List of given variables
    given_params = formula.upcase.split(%r{[\.\*\-\+\/\(\)0-9+]}).reject(&:blank?).map(&:strip)
    unless (given_params - allowed_params).empty?
      errors.add(:formula, _('Quality_Index_Formula_is_not_correct'))
      return false
    end
    true
  end
end
