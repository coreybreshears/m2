#-*- encoding : utf-8 -*-
# ES module for Calls Dashboard statistics
# V1.1
# 2016-08-30
module EsCallsDashboard
  extend UniversalHelpers

  module_function

  # Returns aggragated statistics for Customers and Vendos
  def stats(current_user)
    @current_user = current_user
    # Initial result format
    result = {op:[], tp:[]}
    # Perform ES queries
    response_tp_day = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.dashboard_stats_tp_last_day(default_options))
    response_tp_hour = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.dashboard_stats_tp_last_hour(default_options))
    response_op_day = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.dashboard_stats_op_last_day(default_options))
    response_op_hour = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.dashboard_stats_op_last_hour(default_options))
    # ES issue, check log
    response = response_tp_day && response_tp_hour && response_op_day && response_op_hour
    return result unless response

    # Non-zero-id Customer and Vendor aggregations
    ops_day = response_op_day['aggregations']['grouped_by_op_user']['buckets']
    ops_hour = response_op_hour['aggregations']['grouped_by_op_user']['buckets']
    tps_day = response_tp_day['aggregations']['grouped_by_tp_user']['buckets']
    tps_hour = response_tp_hour['aggregations']['grouped_by_tp_user']['buckets']

    # Cache for nice User names.
    @data_cache = {users: []}

    result[:op] = get_stats(ops_day, ops_hour)
    result[:tp] = get_stats(tps_day, tps_hour)

    result
  end

  def get_stats(day_source, hour_source)
    result_day = calculate_stats(day_source, 'day')
    result_hour = calculate_stats(hour_source, 'hour')

    (result_day + result_hour).group_by{|h| h[:user]}.map{|_, hs| hs.reduce(:merge)}
  end

  private

  module_function

  # Returns options for ES query
  def default_options
    # Current time in a Server time zone
    server_now = Time.now
    # Current time in a User time zone
    user_now = ActiveSupport::TimeZone[@current_user.time_zone].now
    return unless user_now

    # Beginning of day in a User time zone
    user_beginning_of_day = user_now.beginning_of_day
    # Convert User time to Server time
    beginning_of_day = Time.parse(user_beginning_of_day.to_s).strftime('%Y-%m-%dT%H:%M:%S')
    assigned_users =
      if @current_user.show_only_assigned_users?
        User.where("users.responsible_accountant_id = #{@current_user.id}").pluck(:id)
      end

    {
      # All time is converted to Server time
      now: server_now.strftime('%Y-%m-%dT%H:%M:%S'),
      # One hour AGO does not depend on timezones
      last_hour: (server_now - 1.hour).strftime('%Y-%m-%dT%H:%M:%S'),
      # User time zone beginning of day converted to Server time
      last_day: beginning_of_day,
      billsec_field: Confline.get_value('Invoice_user_billsec_show').to_i == 1 ? 'user_billsec' : 'billsec',
      assigned_users: assigned_users
    }
  end

  # Callculates Total Attemps, Total Answered, Total Billsec, ASR, ACD, Margin
  def calculate_stats(source, period_name)
    result = []
    source.each do |res|
      data_row = {}
      user_id = res['key']
      data_row[:user] = @data_cache[:users][user_id] ||= "#{nice_user(User.find_by(id: user_id))}\n#{user_id}"
      stats = res
      data_row["calls_last_#{period_name}".to_sym] = total = stats['doc_count']

      if total > 0
        data_row["answered_last_#{period_name}".to_sym] = answered = stats['answered_calls']['doc_count']
        sell = stats['user_price']['value']
        buy = stats['provider_price']['value']
        billsec = stats['billsec']['value']

        # ASR = TOTAL ANSWERED / TOTAL ATTEMPTS * 100%
        data_row["asr_last_#{period_name}".to_sym] = (answered.to_f / total * 100).round
        # ACD = TOTAL BILLSEC / TOTAL ANSWERED CALLS
        data_row["acd_last_#{period_name}".to_sym] = answered > 0 ? (billsec.to_f / answered).round : 0
        # Margin = PROFIT / SELL * 100%
        data_row["margin_last_#{period_name}".to_sym] = sell > 0 ? ((sell - buy).to_f / sell * 100).round : 0
      end
      result << data_row
    end
    result
  end
end
