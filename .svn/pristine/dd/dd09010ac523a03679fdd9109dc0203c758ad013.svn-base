#-*- encoding : utf-8 -*-
module EsCallsByUser
  extend UniversalHelpers

  def self.get_data(options)
    data, es_options = calls_by_user_variables(options)

    current_user = options[:current_user]
    all_calls = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.calls_by_user(es_options))

    calls_by_user_data_prepare(data, all_calls, es_options)
  end


  def self.calls_by_user_variables(options = {})
    data = {
        table_rows: [],
        table_totals: {
            balance: 0, answered_calls: 0, call_attempts: 0, billsec: 0, acd: 0, asr: 0,
            price: 0, provider_price: 0, profit: 0, margin: 0, markup: 0, pdd: 0,
            pdd_counter: 0
        },
        options: {ex: options[:ex]}
    }

    current_user = options[:current_user]

    data[:options].merge!(default_formatting_options(current_user))

    [data, options]
  end

  def self.calls_by_user_data_prepare(data, all_calls, options)
    current_user = options[:current_user]
    bucket = all_calls['aggregations']['group_by_user_id']['buckets'] if defined?(all_calls) && all_calls.present?

    if bucket.present?
      data = calls_by_user_data_count(data, bucket)
    end

    calls_by_user_totals_format(data)
  end


  def self.calls_by_user_data_count(data, buckets)
    buckets.each do |bucket|
      user_id = bucket['key'].to_i
      call_attempts = bucket['doc_count'].to_d
      answered_calls = bucket['answered_calls']['doc_count'].to_d
      billsec = bucket['answered_calls']['total_billsec']['value'].to_d
      price = bucket['answered_calls']['total_user_price']['value'].to_d * data[:options][:ex]
      provider_price = bucket['answered_calls']['total_provider_price']['value'].to_d * data[:options][:ex]
      pdd_avg = bucket['pdd']['avg_pdd']['value'].to_d
      pdd_total = bucket['pdd']['total_pdd']['value'].to_d
      pdd_not_zero = bucket['pdd']['doc_count'].to_d
      user = User.where(id: user_id).first
      balance = user.raw_balance * data[:options][:ex]
      acd = billsec / answered_calls
      asr = answered_calls / call_attempts * 100
      profit = price - provider_price
      margin = profit / price * 100
      markup = (price / provider_price * 100) - 100

      to_row = {
        user_id: user_id,
        nice_user_and_id: "#{nice_user(user).to_s} #{user_id.to_s}",
        balance: balance,
        answered_calls: answered_calls,
        call_attempts: call_attempts.to_i,
        billsec: billsec,
        acd: acd.to_d,
        asr: asr.to_d,
        price: price.to_d,
        provider_price: provider_price.to_d,
        profit: profit.to_d,
        margin: margin.to_d,
        markup: markup.to_d,
        pdd: pdd_avg.to_d
      }

      %i[acd asr margin markup].each do |key|
        to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
      end

      data[:table_rows] << to_row

      # balance: 0, answered_calls: 0, call_attempts: 0, billsec: 0, adc: 0, asr: 0,
      # price: 0, provider_price: 0, profit: 0, margin: 0, markup: 0
      data[:table_totals][:balance] += balance
      data[:table_totals][:answered_calls] += answered_calls
      data[:table_totals][:call_attempts] += call_attempts
      data[:table_totals][:billsec] += billsec
      data[:table_totals][:price] += price
      data[:table_totals][:provider_price] += provider_price
      data[:table_totals][:pdd] += pdd_total
      data[:table_totals][:pdd_counter] += pdd_not_zero if pdd_not_zero > 0
    end

    data[:table_totals][:pdd] = data[:table_totals][:pdd] / data[:table_totals][:pdd_counter].to_i
    data[:table_totals][:profit] += data[:table_totals][:price] - data[:table_totals][:provider_price]
    data[:table_totals][:acd] += data[:table_totals][:billsec] / data[:table_totals][:answered_calls]
    data[:table_totals][:asr] += data[:table_totals][:answered_calls] / data[:table_totals][:call_attempts] * 100
    data[:table_totals][:margin] += (data[:table_totals][:profit] / data[:table_totals][:price]) * 100
    data[:table_totals][:markup] += (data[:table_totals][:price] / data[:table_totals][:provider_price] * 100) - 100

    %i[acd asr margin markup pdd].each do |key|
      data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
    end
    data
  end

  def self.calls_by_user_totals_format(data)
    data[:table_totals][:answered_calls] = data[:table_totals][:answered_calls].to_i
    data[:table_totals][:call_attempts] = data[:table_totals][:call_attempts].to_i
    data[:table_totals][:billsec] = nice_time(data[:table_totals][:billsec], show_zero: true)
    data[:table_totals][:acd] = nice_time(data[:table_totals][:acd], show_zero: true)


    %i[balance price provider_price profit pdd].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
        data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    %i[asr margin markup].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
        data[:table_totals][key], 2, data[:options][:number_decimal]
      )
    end

    data
  end
end
