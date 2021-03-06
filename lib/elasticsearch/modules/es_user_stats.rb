#-*- encoding : utf-8 -*-
# Class for the detailed user statistics
class EsUserStats
  extend UniversalHelpers

  # Initializes an options hash, can raise an error
  def initialize(options)
    @options = options.slice(
      :user_id, :from, :till, :ufrom, :utill, :page, :size, :current_user
    )

    raise ConfigurationError if @options.count != 8
    @options[:tz] = ActiveSupport::TimeZone.seconds_to_utc_offset(
      Time.zone.now.utc_offset - Time.now.utc_offset
    )
  end

  # Returns the disposition stats
  def disposition_stats
    DispositionStats.new(@options)
  end

  # Returns the daily stats
  def daily_stats
    DailyStats.new(@options)
  end

  # Class for the daily stats querying and formatting
  class DailyStats
    attr_reader :stats, :totals

    # Creates a daily stats hash, runs
    #   an ElasticSearch query, and stores its response
    def initialize(options)
      @options = options
      @stats = new_stats
      @totals = new_totals
      @response = Elasticsearch.safe_search_m2_calls(
        ElasticsearchQueries.user_stats_days(@options)
      )
      @response ? aggregate_response : @stats = []
    end

    # Data for a calls column chart
    def calls_colchart
      # [call date, calls]
      @stats.map { |day, data| [day, data[0]] }
    end

    # Data for a duration column chart
    def duration_colchart
      # [call date, duration]
      @stats.map { |day, data| [day, data[1]] }
    end

    # Data for an average duration column chart
    def acd_colchart
      # [call date, acd]
      @stats.map { |day, data| [day, data[2]] }
    end

    # Data for a days list
    def days_list
      # [call date, calls, duration, acd]
      mapped = @stats.map { |day, data| [day, *data[0..2]] }
      Kaminari.paginate_array(mapped)
        .page(@options[:page].to_i)
        .per(@options[:size].to_i)
    end

    protected

    # Parses the response and merges it to a days hash
    def aggregate_response
      aggs = @response['aggregations']
      # Aggregated totals
      @totals.merge!(
        calls: @response['hits']['total'],
        duration: aggs['duration']['value'],
        acd: aggs['acd']['value'].try(:round)
      )

      (@stats = []) && return if @totals[:calls].zero?

      # Histogram from the ElasticSearch
      histo = Hash[
        aggs['days_histogram']['buckets'].map do |bck|
          # date: [count, duration, acd]
          [
            bck['key_as_string'],
            [bck['doc_count'], bck['duration']['value'], bck['acd']['value'].round]
          ]
        end
      ]

      # Merge the empty stats with the present stats on intersection
      @stats.merge!(histo.slice(* histo.keys & @stats.keys))
    end

    # Initializes an empty disposition stats hash
    def new_stats
      from, till = date_range
      stats = {}
      # call date: [calls, duration, acd]
      till.downto(from) { |day| stats[day.strftime('%Y-%m-%d')] = [0, 0, 0] }
      stats
    end

    def new_totals
      {calls: 0, duration: 0, acd: 0}
    end

    def date_range
      [
        DateTime.parse(@options[:ufrom]),
        DateTime.parse(@options[:utill])
      ]
    end
  end

  # Class for the disposition stats querying and formatting
  class DispositionStats
    attr_reader :stats

    # Creates a disposition stats hash, runs an
    #    ElasticSearch query, and stores its response
    def initialize(options)
      @stats = new_stats
      current_user = options[:current_user]
      if current_user.show_only_assigned_users?
        options[:assigned_users] = User.where(responsible_accountant_id: current_user.id).pluck(:id)
      end
      @response = Elasticsearch.safe_search_m2_calls(
        ElasticsearchQueries.user_stats_disp(options)
      )
      aggregate_response if @response
    end

    def piechart
      # [disposition, count]
      @stats.except('Total').map { |disp, data| [disp, data[0]] }
    end

    protected

    # Parses the response, computes percents, and
    #   merges the result to a stats hash
    def aggregate_response
      total = @response['hits']['total']
      stats['Total'] = [total, 100.0]
      return if total.zero?

      @stats.merge!(
        Hash[
          @response['aggregations']['disp_groups']['buckets'].map do |bck|
            count = bck['doc_count']
            # disposition: [count, percent of total]
            [bck['key'].gsub(' ', '_'), [count, count.to_f / total * 100]]
          end
        ]
      )
    end

    # Initializes an empty disposition stats hash
    def new_stats
      Hash[
        # disposition: [count, percent of total]
        %w(ANSWERED NO_ANSWER BUSY FAILED Total)
          .map { |disp| [disp, [0, 0.0]] }
      ]
    end
  end

  # Exception raised by a class when configuration
  #   is missing or is insufficient
  class ConfigurationError < StandardError
    def initialize(msg = 'Bad configuration')
      super
    end
  end
end
