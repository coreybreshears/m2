#-*- encoding : utf-8 -*-

# Module for elasticsearch TP deviation stats
module EsTpDeviations
  class << self
    # Runs an elasticsearch query and aggregates stats about termination points
    # Params:
    # +tp_ids+:: an array of tps' ids to gather stats for
    # +minutes_back+:: a number of minutes back from now to gather stats for
    # Returns a hash with tps' stats: {id: {asr:, acd:},...}
    def tp_quality(tp_ids, minutes_back)
      response = do_query(tp_ids, minutes_back)
      response ? fill_in_gaps(format_response(response), tp_ids) : []
    end

    # Performs an elasticsearch query
    # Params:
    # +tp_ids+:: an array of tps' ids to gather stats for
    # +minutes_back+:: a number of minutes back from now to gather stats for
    # Returns a raw response as a hash
    def do_query(tp_ids, minutes_back)
      time_now = Time.now
      time_format = '%Y-%m-%dT%H:%M:%S'
      Elasticsearch.safe_search_m2_calls(
        ElasticsearchQueries.tp_deviations(
          tps: tp_ids,
          from: (time_now - minutes_back.minute).strftime(time_format),
          till: time_now.strftime(time_format)
        )
      )
    end

    private

    # Formats a raw elasticsearch response as an array of hashes
    # +response+:: a raw elasticsearch response as a hash
    # Returns a hash with tps' stats: {id: {asr:, acd:},...}
    def format_response(response)
      Hash[
        response['aggregations']['tps']['buckets'].map do |agg|
          attempts = agg['doc_count'].to_f
          answered = agg['answered']['doc_count'].to_f
          [
            agg['key'],
            {
              # ACD = billsec / number of answered calls
              acd: answered.zero? ? 0 : agg['billsec']['value'].to_f / answered,
              # ASR % = number of answered calls / number of call attempts
              asr: attempts.zero? ? 0 : answered / attempts * 100
            }
          ]
        end
      ]
    end

    def fill_in_gaps(tp_stats, tp_ids)
      Hash[tp_ids.map { |id| [id, {acd: 0, asr: 0}] }].merge(tp_stats)
    end
  end
end
