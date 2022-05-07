#-*- encoding : utf-8 -*-
module EsQuickStatsTechnicalInfo

  def self.get_data
    cache_time = (Confline.get('Cache_ES_Sync_Status_for_last').try(:value) || 10).to_i
    cached_data = Confline.where(name: 'ES_Sync_Status_cache').first

    if cached_data.present? && (DateTime.strptime(cached_data.value2.to_s, '%s') > (Time.now - cache_time.minutes))
      data = JSON.parse(cached_data.value).symbolize_keys
    else
      data = {mysql: Call.count.to_i, es: '-', status: '-'}
      calls_count = Elasticsearch.safe_search_m2_calls({size: 0})

      if calls_count.present? && calls_count['hits']['total'].present?
        data[:es] = calls_count['hits']['total'].to_i
      else
        return data
      end

      data[:status] = (data[:es] >= data[:mysql]) ? 100 : (data[:es].to_f / data[:mysql].to_f * 100).floor

      Confline.set_value('ES_Sync_Status_cache', data.to_json, 0, false)
      Confline.set_value2('ES_Sync_Status_cache', Time.now.to_i, 0, false)
    end

    data
  end

  def self.get_data_for_invoice(options)
    time_from = parse_time(options[:from] - 2.day)
    options_till = options[:till] + 2.day
    time_now = Time.now - 2.hour
    options_till = time_now if time_now < options_till
    time_till = parse_time(options_till)
    data = {mysql: Call.where("calls.calldate BETWEEN '#{time_from[:mysql]}' AND '#{time_till[:mysql]}'").count.to_i, es: ''}
    es_options = {
      from: time_from[:es],
      till: time_till[:es]
    }
    calls_count = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.quick_stats_call(es_options))
    if calls_count.present? && calls_count['hits']['total'].present?
      data[:es] = calls_count['hits']['total'].to_i
    else
      MorLog.my_debug("***Data checking for invoice: elastic problems. 1# #{calls_count.present?} 2# #{calls_count['hits']['total'].present?}")
      return false
    end
    MorLog.my_debug("***Data checking for invoice:  #{data}")
    data[:status] = data[:es] == data[:mysql]
  end

  private

  def self.parse_time(time)
    es_time_format = '%Y-%m-%dT%H:%M:%S'
    mysql_time_format = '%Y-%m-%d %H:%M:%S'
    {
      es: time.strftime(es_time_format),
      mysql: time.strftime(mysql_time_format)
    }
  end

end
