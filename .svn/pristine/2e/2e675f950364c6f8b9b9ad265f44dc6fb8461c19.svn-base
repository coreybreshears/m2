# -*- encoding : utf-8 -*-
module EsHgcStats
  extend UniversalHelpers

  def self.get_data(options = {})
    calls, graph =
        {calls: [], total_calls: 0}, {calls: [], hangupcausecode: '['}

    user_id = options[:user_id]
    device_id = options[:device_id]
    dst_group_id = options[:dst_group_id]
    current_user = options[:current_user]
    order_by = options[:order_by].to_s
    order_desc = options[:order_desc].to_i == 1

    es_options = {}
    es_options[:user_id] = user_id unless user_id == -1
    es_options[:device_id] = device_id if device_id.to_i >= 0
    es_options[:dst_group_id] = dst_group_id unless dst_group_id == -1

    if current_user.show_only_assigned_users?
      es_options[:assigned_users] = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
    end

    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)
    es_options[:utc_offset] = utc_offset

    es_hgc = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.es_hangup_cause_codes_stats_query(options[:a1], options[:a2], es_options))
    es_hgc_good_calls = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.es_hangup_cause_codes_stats_calls_query(options[:a1], options[:a2], es_options.merge({good_calls: true})))
    es_hgc_bad_calls = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.es_hangup_cause_codes_stats_calls_query(options[:a1], options[:a2], es_options.merge({bad_calls: true})))
    return [calls, graph] if es_hgc.blank? || es_hgc_bad_calls.blank? || es_hgc_good_calls.blank?

    calls[:total_calls] = es_hgc['hits']['total'].to_i

    es_hgc['aggregations']['grouped_by_hgc']['buckets'].each do |bucket|
      hangup_cause_code = bucket['key'].to_i
      hangup_cause_code_calls = bucket['doc_count'].to_i
      hangup_cause = Hangupcausecode.where(code: hangup_cause_code).first

      # Table Data
      calls[:calls] << {
          hc_code: hangup_cause_code, calls: hangup_cause_code_calls,
          hc_id: hangup_cause.try(:id).to_s, hc_description: hangup_cause.try(:description).to_s
      }

      # Graph Pie
      graph[:calls] << ["#{_('HGC')}: #{hangup_cause_code}", hangup_cause_code_calls]
    end
    graph[:calls].sort! { |a, b| b[1] <=> a[1] }
    case order_by
      when 'cause_code'
        calls[:calls].sort! { |a, b| order_desc ? b[:hc_code] <=> a[:hc_code] : a[:hc_code] <=> b[:hc_code] }
      else
        calls[:calls].sort! { |a, b| order_desc ? b[:calls] <=> a[:calls] : a[:calls] <=> b[:calls] }
    end
    # Graph Bar
    hgc_good_bad_calls = []
    es_hgc_good_calls['aggregations']['dates']['buckets'].each do |bucket|
      date = bucket['key_as_string'].to_s
      good_calls = bucket['doc_count'].to_i

      hgc_good_bad_calls << {date: date, good_calls: good_calls, bad_calls: 0}
    end

    es_hgc_bad_calls['aggregations']['dates']['buckets'].each do |bucket|
      date = bucket['key_as_string'].to_s
      bad_calls = bucket['doc_count'].to_i

      if hgc_good_bad_calls.find { |dates| dates[:date] == date }.try(:[]=, :bad_calls, bad_calls)
      else
        hgc_good_bad_calls << {date: date, good_calls: 0, bad_calls: bad_calls}
      end
    end

    hgc_good_bad_calls.each do |date|
      graph[:hangupcausecode] << "[new Date('#{date[:date]}'), #{date[:good_calls]}, #{date[:bad_calls]}],"
    end
    graph[:hangupcausecode] <<']'


    return calls, graph
  end
end
