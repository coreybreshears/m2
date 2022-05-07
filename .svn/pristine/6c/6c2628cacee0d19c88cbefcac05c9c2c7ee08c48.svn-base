#-*- encoding : utf-8 -*-
module EsBalanceReports
  extend UniversalHelpers

  def self.get_data_traffic_to_us(options = {})
    data = []

    es_options = {from: options[:from], till: options[:till]}
    es_options[:users] = User.where("id > 0 AND usertype != 'manager' #{options[:user_id]}").where(options[:assigned_users]).where(options[:show_hidden_users]).pluck(:id)

    es_traffic_to_us = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.balance_reports_traffic_to_us(es_options))

    if es_traffic_to_us && es_traffic_to_us['aggregations'].present?
      es_traffic_to_us['aggregations']['group_by_originator_id']['buckets'].each do |bucket|
        user_id = bucket['key'].to_i
        originator_price = bucket['answered_calls']['total_originator_price']['value'].to_d

        user = User.where(id: user_id).first
        originator_price_with_tax = user.get_tax.apply_tax(originator_price)# * data[:options][:exchange_rate]

        data << {user_id: user_id, traffic_to_us: originator_price_with_tax}
      end
    end

    data
  end

  def self.get_data_traffic_from_us(options = {})
    data = []

    es_options = {from: options[:from], till: options[:till]}
    es_options[:users] = User.where("id > 0 AND usertype != 'manager' #{options[:user_id]}").where(options[:assigned_users]).where(options[:show_hidden_users]).pluck(:id)

    es_traffic_from_us = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.balance_reports_traffic_from_us(es_options))

    if es_traffic_from_us && es_traffic_from_us['aggregations'].present?
      es_traffic_from_us['aggregations']['group_by_terminator_id']['buckets'].each do |bucket|
        data << {user_id: bucket['key'].to_i, traffic_from_us: bucket['answered_calls']['total_terminator_price']['value'].to_d}
      end
    end

    data
  end
end
