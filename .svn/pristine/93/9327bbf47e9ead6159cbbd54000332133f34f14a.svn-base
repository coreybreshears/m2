#-*- encoding : utf-8 -*-
module EsCallsPerHour
  extend UniversalHelpers

  def self.get_data(options = {})
    data, es_options = variables(options)
    case options[:level]
      when 0
        data_by_originator(data, es_options)
      when 1
        data_by_hour(data, es_options)
      when 2
        data_by_destination(data, es_options)
      when 3
        data_by_terminator(data, es_options)
      else
        data_by_date(data, es_options)
    end
  end

  def self.variables(options = {})
    data = {
        table_rows: [],
        table_totals: {
            user_call_attempts: 0, answered_calls: 0, user_acd: 0, user_asr: 0,
            admin_call_attempts: 0, admin_acd: 0, admin_asr: 0, duration: 0
        },
        options: {}
    }

    current_user = options[:current_user]

    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)

    es_options = {
        from: options[:from], till: options[:till],
        utc_offset: utc_offset,
        hour_offset: seconds_offset / 3600
    }

    es_options[:user] = options[:user] if options[:user] > 0
    es_options[:prefix] = options[:prefix].presence

    es_options[:providers] = [options[:terminator]] if options[:terminator].to_i > 0


    es_options[:destination_group_id] = options[:destination_group] if options[:destination_group] > 0
    es_options[:billsec_field] = Confline.get_value('Invoice_user_billsec_show').to_i == 1 ? 'user_billsec' : 'billsec'
    if current_user.show_only_assigned_users?
      es_options[:show_only_assigned_users] = 1
      current_acc_id = current_user.id
      es_options[:user_array] = User.where(responsible_accountant_id: current_acc_id).pluck(:id)
    end
    data[:options].merge!(default_formatting_options(current_user))

    return data, es_options
  end

  def self.data_by_date(data, es_options)
    es_data = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.calls_per_hour_by_date(es_options))

    if es_data.present? && es_data['aggregations']['group_by_date']['buckets'].present?

      es_data['aggregations']['group_by_date']['buckets'].each do |bucket|
        branch = bucket['key_as_string']
        user_call_attempts = bucket['user_perspective']['doc_count'].to_d
        answered_calls = bucket['answered_calls']['doc_count'].to_d
        admin_call_attempts = bucket['doc_count'].to_d
        duration = bucket['total_billsec']['value'].to_d

        to_row = {
            branch: branch,
            user_call_attempts: user_call_attempts.to_i,
            answered_calls: answered_calls.to_i,
            user_acd: (duration / answered_calls),
            user_asr: ((answered_calls / user_call_attempts) * 100),
            admin_call_attempts: admin_call_attempts.to_i,
            admin_acd: (duration / answered_calls),
            admin_asr: ((answered_calls / admin_call_attempts) * 100),
            duration: duration
        }

        [:user_acd, :user_asr, :admin_acd, :admin_asr].each do |key|
          to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
        end

        data[:table_rows] << to_row
        data[:table_totals][:user_call_attempts] += user_call_attempts
        data[:table_totals][:answered_calls] += answered_calls
        data[:table_totals][:admin_call_attempts] += admin_call_attempts
        data[:table_totals][:duration] += duration
      end

      data[:table_totals][:user_acd] = data[:table_totals][:admin_acd] = (data[:table_totals][:duration] / data[:table_totals][:answered_calls])
      data[:table_totals][:user_asr] = ((data[:table_totals][:answered_calls] / data[:table_totals][:user_call_attempts]) * 100)
      data[:table_totals][:admin_asr] = ((data[:table_totals][:answered_calls] / data[:table_totals][:admin_call_attempts]) * 100)

      [:user_acd, :admin_acd, :user_asr, :admin_asr].each do |key|
        data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
      end

      data[:table_rows].reverse!

      data = totals_format(data)
    end

    data
  end

  def self.totals_format(data)
    [:answered_calls, :user_call_attempts, :admin_call_attempts].each do |key|
      data[:table_totals][key] = data[:table_totals][key].to_i
    end

    [:user_acd, :admin_acd, :duration].each do |key|
      data[:table_totals][key] = nice_time(data[:table_totals][key])
    end

    [:user_asr, :admin_asr].each do |key|
      data[:table_totals][key] = nice_number_with_separator(data[:table_totals][key], 2, data[:options][:number_decimal])
    end

    return data
  end

  def self.data_by_originator(data, es_options)
    es_data = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.calls_per_hour_by_originator(es_options))
    if es_data.present? && es_data['aggregations']['group_by_user_id']['buckets'].present?
      es_data['aggregations']['group_by_user_id']['buckets'].each do |bucket|
        branch = bucket['key'].to_i
        user_call_attempts = bucket['user_perspective']['doc_count'].to_d
        answered_calls = bucket['answered_calls']['doc_count'].to_d
        admin_call_attempts = bucket['doc_count'].to_d
        duration = bucket['total_billsec']['value'].to_d
        user_nicename = User.select(SqlExport.nice_user_name_sql).where(id: branch).first.try(:nicename)
        to_row = {
            day: es_options[:from],
            secret_user_id: branch,
            branch: user_nicename.to_s,
            user_call_attempts: user_call_attempts.to_i,
            answered_calls: answered_calls.to_i,
            user_acd: (duration / answered_calls),
            user_asr: ((answered_calls / user_call_attempts) * 100),
            admin_call_attempts: admin_call_attempts.to_i,
            admin_acd: (duration / answered_calls),
            admin_asr: ((answered_calls / admin_call_attempts) * 100),
            duration: duration
        }

        [:user_acd, :user_asr, :admin_acd, :admin_asr].each do |key|
          to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
        end

        data[:table_rows] << to_row
      end

      data[:table_rows].sort! { |a, b| a[:branch].downcase <=> b[:branch].downcase }
    end

    data
  end

  def self.data_by_hour(data, es_options)
    es_data = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.calls_per_hour_by_hour(es_options))

    if es_data.present? && es_data['aggregations']['group_by_hour']['buckets'].present?
      es_data['aggregations']['group_by_hour']['buckets'].each do |bucket|
        branch = bucket['key_as_string'].to_i
        user_call_attempts = bucket['user_perspective']['doc_count'].to_d
        answered_calls = bucket['answered_calls']['doc_count'].to_d
        admin_call_attempts = bucket['doc_count'].to_d
        duration = bucket['total_billsec']['value'].to_d

        user_nicename = User.select(SqlExport.nice_user_name_sql).where(id: es_options[:user]).first.try(:nicename)

        hour = branch + es_options[:hour_offset]
        if hour < 0
          hour += 24
        elsif hour >= 24
          hour -= 24
        end
        to_row = {
            day: es_options[:from],
            hour: hour,
            secret_user_id: es_options[:user],
            nice_username: user_nicename.to_s,
            user_call_attempts: user_call_attempts.to_i,
            answered_calls: answered_calls.to_i,
            user_acd: (duration / answered_calls),
            user_asr: ((answered_calls / user_call_attempts) * 100),
            admin_call_attempts: admin_call_attempts.to_i,
            admin_acd: (duration / answered_calls),
            admin_asr: ((answered_calls / admin_call_attempts) * 100),
            duration: duration
        }

        [:user_acd, :user_asr, :admin_acd, :admin_asr].each do |key|
          to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
        end

        data[:table_rows] << to_row
      end
    end

    data
  end

  def self.data_by_destination(data, es_options)
    es_data = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.calls_per_hour_by_destination(es_options))

    if es_data.present? && es_data['aggregations']['group_by_prefix']['buckets'].present?
      data_cache = {destination_name: {}}
      es_data['aggregations']['group_by_prefix']['buckets'].each do |bucket|
        branch = bucket['key'].to_s
        user_call_attempts = bucket['user_perspective']['doc_count'].to_d
        answered_calls = bucket['answered_calls']['doc_count'].to_d
        admin_call_attempts = bucket['doc_count'].to_d
        duration = bucket['total_billsec']['value'].to_d

        user_nicename = User.select(SqlExport.nice_user_name_sql).where(id: es_options[:user]).first.try(:nicename)

        hour = es_options[:from].split('T')[1][0..1].to_i + es_options[:hour_offset]
        day = es_options[:from].split('T')[0][8..9].to_i
        if hour < 0
          hour += 24
          day -= 1
        elsif hour > 24
          hour -= 24
          day += 1
        end

        dest_prefix = data_cache[:destination_name][branch] ||= "#{Destination.where(prefix: branch).first.try(:name)} (#{branch})"


        to_row = {
            dest_prefix: dest_prefix,
            prefix: branch,
            day: es_options[:from],
            hour: hour,
            secret_user_id: es_options[:user],
            nice_username: user_nicename.to_s,
            user_call_attempts: user_call_attempts.to_i,
            answered_calls: answered_calls.to_i,
            user_acd: (duration / answered_calls),
            user_asr: ((answered_calls / user_call_attempts) * 100),
            admin_call_attempts: admin_call_attempts.to_i,
            admin_acd: (duration / answered_calls),
            admin_asr: ((answered_calls / admin_call_attempts) * 100),
            duration: duration,
            fixed_day: day
        }

        [:user_acd, :user_asr, :admin_acd, :admin_asr].each do |key|
          to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
        end

        data[:table_rows] << to_row
      end

      data[:table_rows].sort! { |a, b| a[:dest_prefix].downcase <=> b[:dest_prefix].downcase }
    end

    data
  end

  def self.data_by_terminator(data, es_options)
    es_data = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.calls_per_hour_by_terminator(es_options))

    if es_data.present? && es_data['aggregations']['group_by_provider_id']['buckets'].present?
      terminators = {}
      es_data['aggregations']['group_by_provider_id']['buckets'].each do |bucket|
        branch = bucket['key'].to_i
        user_call_attempts = bucket['user_perspective']['doc_count'].to_d
        answered_calls = bucket['answered_calls']['doc_count'].to_d
        admin_call_attempts = bucket['doc_count'].to_d
        duration = bucket['total_billsec']['value'].to_d

        to_row = {
            user_call_attempts: user_call_attempts.to_i,
            answered_calls: answered_calls.to_i,
            admin_call_attempts: admin_call_attempts.to_i,
            duration: duration
        }

        terminator_id = User.where(id: branch).first.try(:id).to_i

        if terminators[terminator_id]
          [:user_call_attempts, :answered_calls, :admin_call_attempts, :duration].each do |key|
            terminators[terminator_id][key] += to_row[key]
          end
        else
          terminators[terminator_id] = to_row
        end
      end

      no_terminator_data = {}
      terminators.each do |terminator_id, to_row|
        to_row[:terminator_name] = if terminator_id == 0
                                     "<i>(#{_('Unassigned_Terminator')})</i>".html_safe
                                   else
                                     User.select(SqlExport.nice_user_name_sql).where(id: terminator_id).first.try(:nicename)
                                   end

        to_row[:user_acd] = to_row[:duration].to_d / to_row[:answered_calls].to_d
        to_row[:user_asr] = (to_row[:answered_calls].to_d / to_row[:user_call_attempts].to_d) * 100
        to_row[:admin_acd] = to_row[:duration].to_d / to_row[:answered_calls].to_d
        to_row[:admin_asr] = (to_row[:answered_calls].to_d / to_row[:admin_call_attempts].to_d) * 100

        [:user_acd, :user_asr, :admin_acd, :admin_asr].each do |key|
          to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite?
        end

        if terminator_id == '0'
          no_terminator_data = to_row
        else
          data[:table_rows] << to_row
        end
      end

      data[:table_rows].sort! { |a, b| a[:terminator_name].downcase <=> b[:terminator_name].downcase }
      data[:table_rows] << no_terminator_data if no_terminator_data.present?
    end

    data
  end
end
