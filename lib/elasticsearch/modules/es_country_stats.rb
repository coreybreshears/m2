# -*- encoding : utf-8 -*-
module EsCountryStats
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = country_stats_variables(options)

    es_country_stats = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.country_stats_query(es_options))

    country_stats_data_prepare(data, es_country_stats)
  end

  def self.country_stats_variables(options = {})
    data = {
        table_rows: [],
        table_totals: { calls: 0, time: 0, acd: 0, price: 0, user_price: 0, profit: 0 },
        options: {}
    }

    s_user_id = options[:s_user_id]
    current_user = options[:current_user]

    es_options = {from: options[:from], till: options[:till], user_perspective: current_user.usertype.to_s == 'user'}

    if es_options[:user_perspective]
      es_options[:user_id] = current_user.id
    else
      es_options[:user_id] = s_user_id unless s_user_id == -1
    end
    if current_user.show_only_assigned_users?
      es_options[:assigned_users] = User.where("users.responsible_accountant_id = #{current_user.id}").map {|user|  user.id}
    end
    data[:options][:user_perspective] = es_options[:user_perspective]
    data[:options].merge!(default_formatting_options(current_user))
    data[:options][:exrate] = options[:exrate]

    return data, es_options
  end

  def self.country_stats_data_prepare(data, es_country_stats)
    # If query to ES failed or no data found, return no data
    if es_country_stats.present? && es_country_stats['aggregations']['grouped_by_dg_id']['buckets'].present?
      data = country_stats_data_count(
          data,
          es_country_stats['aggregations']['grouped_by_dg_id']['buckets']
      )
    end

    country_stats_totals_format(data)
  end

  def self.country_stats_data_count(data, es_result)
    table_total_calls = table_total_time = 0
    exchange_rate = data[:options][:exrate].to_d
    es_result.each do |bucket|
      calls = bucket['doc_count'].to_i
      total_billsec = bucket['total_billsec']['value'].to_d
      total_provider_price = bucket['total_provider_price']['value'].to_d * exchange_rate
      total_user_price = bucket['total_user_price']['value'].to_d * exchange_rate

      destination_group = Destinationgroup.where(id: bucket['key'].to_i).first
      destination_group_name = destination_group.try(:name)

      if destination_group_name.blank?
        bucket['key'].to_i > 0 ? destination_group_name = 'Destination Group missing' : destination_group_name = 'Unassigned Destination'
      end

      acd = (total_billsec / calls).to_d
      acd = acd.nan? || acd.infinite? ? 0.to_d : acd

      to_row = {
          destination_group_id: destination_group.try(:id),
          flag: destination_group.try(:flag).try(:downcase),
          destination_group_name: destination_group_name,
          calls: calls,
          time: total_billsec,
          acd: acd
      }

      if data[:options][:user_perspective]
        to_row[:price] = total_user_price
        to_row[:user_price] = 0.to_d
        to_row[:profit] = 0.to_d
      else
        to_row[:price] = total_provider_price
        to_row[:user_price] = total_user_price
        to_row[:profit] = total_user_price - total_provider_price
      end

      data[:table_rows] << to_row

      table_total_calls += calls
      table_total_time += total_billsec
      data[:table_totals][:price] += to_row[:price]
      data[:table_totals][:user_price] += to_row[:user_price]
      data[:table_totals][:profit] += to_row[:profit]
    end
    data[:table_totals][:acd] += (table_total_time / table_total_calls).to_d
    data[:table_totals][:time] = table_total_time
    data[:table_totals][:calls] = table_total_calls
    data
  end

  def self.country_stats_totals_format(data)
    [:time, :acd].each do |key|
      data[:table_totals][key] = nice_time data[:table_totals][key]
    end

    [:price, :user_price, :profit].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    return data
  end
end
