#-*- encoding : utf-8 -*-
module EsAggregates
  extend UniversalHelpers

  def self.get_data(options = {})
    current_user = options[:current_user]
    data, es_options = variables(options)
    if current_user.show_only_assigned_users?
      es_options[:assigned_users] = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
    end
    es_aggregates = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.aggregates(es_options))

    aggregates_data_prepare(data, es_aggregates)
  end

  def self.format_options(params, from_t, till_t, c_user)

    params_originator, params_originator_id = [params[:s_originator], params[:s_originator_id]]
    params_terminator, params_terminator_id = [params[:s_terminator], params[:s_terminator_id]]

    allowed_params = %w(dst destination_group use_real_billsec
        from_user_perspective tp s_op_device s_tp_device src dst dst_group
        group_by_originator group_by_op group_by_terminator group_by_tp
        group_by_dst_group group_by_dst group_by_manager answered_calls s_duration s_manager
      )

    params_answered = params[:answered_calls]
    # search_values = params.slice(allowed_params).symbolize_keys
    search_values = params.select { |key, _| allowed_params.member?(key) }.symbolize_keys
    search_values.merge!(
        answered_calls: params_answered.blank? ? '1' : params_answered,
        op_devices: params_originator_id.to_i > 0 ? Device.where(user_id: params_originator_id, op: 1, op_active: 1) : [],
        tp_devices: params_terminator_id.to_i > 0 ? Device.where(user_id: params_terminator_id, tp: 1, tp_active: 1) : [],
        originator: User.find_by(id: params_originator_id) || params_originator.blank? ? params_originator : '',
        originator_id: params_originator.blank? ? nil : params_originator_id,
        terminator: User.find_by(id: params_terminator_id) || params_terminator.blank? ? params_terminator : '',
        filter_by_originator: !params_originator.blank?,
        filter_by_terminator: !params_terminator.blank?,
        terminator_id: params_terminator.blank? ? nil : params_terminator_id,
        from: from_t,
        till: till_t,
        current_user: c_user,
        set_time_of_day: params[:set_time_of_day],
        from_time_of_day: params[:from_time_of_day],
        till_time_of_day: params[:till_time_of_day],
        s_manager: params[:s_manager]
    )
    search_values
  end

  def self.variables(options = {})
    data = {
        table_rows: [],
        table_totals: {
            billed_originator: 0, billed_originator_with_tax: 0, billed_terminator: 0,
            billed_duration_originator: 0, billed_duration_terminator: 0, duration: 0,
            answered_calls: 0, total_calls: 0, asr: 0, acd: 0, pdd: 0, pdd_counter: 0
        },
        options: {
            answered_calls: options[:answered_calls].to_i,
            group_by: []
        }
    }

    @current_user = options[:current_user]

    seconds_offset = (Time.zone.now.utc_offset().second - Time.now.utc_offset().second).to_i
    utc_offset = ActiveSupport::TimeZone.seconds_to_utc_offset(seconds_offset)

    # Filters
    es_options = {
        from: options[:from], till: options[:till],
        utc_offset: utc_offset,
        hour_offset: seconds_offset / 3600,
        group_by: [],
        originator: options[:originator_id],
        terminator: options[:terminator_id],
        originator_present: options[:filter_by_originator],
        terminator_present: options[:filter_by_terminator],
        op: options[:s_op_device].to_i > 0 ? options[:s_op_device] : nil,
        tp: options[:s_tp_device].to_i > 0 ? options[:s_tp_device] : nil,
        dst: options[:dst].present? && !(options[:dst].strip =~ /^%*$/) ? options[:dst] : nil,
        src: options[:src].present? && !(options[:src].strip =~ /^%*$/) ? options[:src] : nil,
        pdd: options[:pdd_show].to_i,
        s_duration: options[:s_duration],
        set_time_of_day: options[:set_time_of_day],
        from_time_of_day: options[:from_time_of_day],
        till_time_of_day: options[:till_time_of_day],
        s_manager: options[:s_manager]
    }

    es_options[:use_real_billsec] = true if options[:use_real_billsec].to_i > 0
    data[:options][:user_perspective] = es_options[:user_perspective] = true if options[:from_user_perspective].to_i > 0

    if options[:dst_group].to_s.strip.present? && !(options[:dst_group].strip =~ /^%*$/)
      es_options[:destinationgroups] = Destinationgroup.where('name LIKE ?', options[:dst_group].strip).pluck(:id)
      es_options[:destinationgroups_present] = true
    end
    # End of Filters

    # Grouping options
    if options[:group_by_originator].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_originator', group_field: es_options[:user_perspective].present? ? 'user_id' : 'src_user_id'}
      data[:options][:group_by] << :originator
    elsif options[:group_by_op].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_op', group_field: 'src_device_id'}
      data[:options][:group_by] << :op
    end

    if options[:group_by_terminator].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_terminator', group_field: 'provider_id'}
      data[:options][:group_by] << :terminator
    elsif options[:group_by_tp].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_tp', group_field: 'dst_device_id'}
      data[:options][:group_by] << :tp
    end

    if options[:group_by_dst].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_dst', group_field: 'prefix'}
      data[:options][:group_by] << :dst
    end

    if options[:group_by_dst_group].to_i > 0 || options[:group_by_dst].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_dst_group', group_field: 'destinationgroup_id'}
      data[:options][:group_by] << :dst_group
    end

    if options[:group_by_manager].to_i > 0
      es_options[:group_by] << {group_name: 'agg_by_manager', group_field: 'manager_id'}
      data[:options][:group_by] << :manager
    end
    # End of Grouping options

    data[:options][:es_group_by] = es_options[:group_by]
    data[:options].merge!(default_formatting_options(@current_user))
    data[:options][:exchange_rate] = Currency.find_by(name: options[:currency]).try(:exchange_rate).to_d

    return data, es_options
  end

  def self.aggregates_data_prepare(data, es_aggregates)
    if es_aggregates.present? && es_aggregates['aggregations'].present?
      groups = data[:options][:es_group_by]
      group_levels = groups.size

      data_out = []
      es_aggregates['aggregations'][groups[0][:group_name]]['buckets'].each do |level_one_data|
        input = {}
        input[groups[0][:group_field]] = level_one_data['key']

        if group_levels > 1
          level_one_data[groups[1][:group_name]]['buckets'].each do |level_two_data|
            input[groups[1][:group_field]] = level_two_data['key']
            add_input_values(data_out, input, level_two_data) if group_levels == 2

            if group_levels > 2
              level_two_data[groups[2][:group_name]]['buckets'].each do |level_three_data|
                input[groups[2][:group_field]] = level_three_data['key']
                add_input_values(data_out, input, level_three_data) if group_levels == 3

                if group_levels > 3
                  level_three_data[groups[3][:group_name]]['buckets'].each do |level_four_data|
                    input[groups[3][:group_field]] = level_four_data['key']
                    add_input_values(data_out, input, level_four_data) if group_levels == 4

                    if group_levels > 4
                      level_four_data[groups[4][:group_name]]['buckets'].each do |level_five_data|
                        input[groups[4][:group_field]] = level_five_data['key']
                        add_input_values(data_out, input, level_five_data) if group_levels == 5
                      end
                    end
                  end
                end
              end
            end
          end
        end

        add_input_values(data_out, input, level_one_data) if group_levels == 1
      end

      if data_out.present?
        data_cache = {dg_name: {}, user: {}, device: {}}

        data_out.each do |data_row|
          answered_calls = data_row['answered_calls']
          next if answered_calls < data[:options][:answered_calls]
          total_calls = data_row['total_calls']
          billed_originator = data_row['billed_originator'] * data[:options][:exchange_rate]
          billed_terminator = data_row['billed_terminator'] * data[:options][:exchange_rate]
          billed_duration_originator = data_row['billed_duration_originator']
          billed_duration_terminator = data_row['billed_duration_terminator']
          duration = data_row['duration']
          pdd_avg = data_row['pdd_avg']
          pdd_total = data_row['pdd_total']
          pdd_not_zero = data_row['pdd_not_zero']
          profit = billed_originator - billed_terminator

          to_row = {
              billed_originator: billed_originator,
              billed_originator_with_tax: 0.to_d,
              billed_terminator: billed_terminator,
              profit: profit,
              billed_duration_originator: billed_duration_originator,
              billed_duration_terminator: billed_duration_terminator,
              duration: duration,
              answered_calls: answered_calls,
              total_calls: total_calls,
              asr: ((answered_calls.to_d / total_calls.to_d) * 100),
              acd: (duration / answered_calls.to_d),
              pdd: pdd_avg.to_d,
              profit_percent: ((profit.to_d / billed_originator.to_d) * 100)
          }
          [:asr, :acd].each { |key| to_row[key] = 0.to_d if to_row[key].nan? || to_row[key].infinite? }

          dg_id = data_row['destinationgroup_id']
          if dg_id.present?
            destination_group_name = data_cache[:dg_name][dg_id] ||= Destinationgroup.find_by(id: dg_id).try(:name)
            if dg_id.to_i == 0
              to_row[:dst_group] = 'Unassigned Destination'
            elsif dg_id.to_i > 0 && destination_group_name.blank?
              to_row[:dst_group] = 'Destination Group missing'
            else
              to_row[:dst_group] = destination_group_name
            end
          end

          prefix = data_row['prefix']
          to_row[:dst] = prefix if prefix.present?

          manager_id = data_row['manager_id']
          if manager_id.present?
            if manager_id == 0
              to_row[:manager] =  'No Manager Assigned'
              to_row[:manager_id] = 0
            else
              manager = data_cache[:user][manager_id] ||= User.select("#{SqlExport.nice_user_name_sql}, users.*").where(id: manager_id).first
              to_row[:manager] = manager.try(:nicename)
              to_row[:manager_id] = manager_id
            end
          end

          user_id = data[:options][:user_perspective].present? ? data_row['user_id'] : data_row['src_user_id']
          if user_id.present?
            user = data_cache[:user][user_id] ||= User.select("#{SqlExport.nice_user_name_sql}, users.*").where(id: user_id).first
            to_row[:originator] = user.try(:nicename)
            to_row[:originator_id] = user_id
            to_row[:billed_originator_with_tax] = user.get_tax.apply_tax(data_row['billed_originator']) * data[:options][:exchange_rate] if user.present?
          end

          op_id = data_row['src_device_id']
          if op_id.present?
            device = data_cache[:device][op_id] ||= Device.find_by(id: op_id)
            to_row[:op_id] = op_id
            to_row[:op] = device ? (device.description || device.ipaddr) : 'Origination Point missing'
          end

          terminator_id = data_row['provider_id']
          if terminator_id.present?
            terminator = data_cache[:user][terminator_id] ||= User.select("#{SqlExport.nice_user_name_sql}, users.*").where(id: terminator_id).first
            to_row[:terminator] = terminator.try(:nicename)
            to_row[:terminator_id] = terminator_id
          end

          tp_id = data_row['dst_device_id']
          if tp_id.present?
            device = data_cache[:device][tp_id] ||= Device.find_by(id: tp_id)
            to_row[:tp_id] = tp_id
            to_row[:tp] = device ? (device.description || device.ipaddr) : 'Termination Point missing'
          end

          [
              :billed_originator, :billed_originator_with_tax, :billed_terminator, :billed_duration_originator,
              :billed_duration_terminator, :duration, :answered_calls, :total_calls
          ].each { |key| data[:table_totals][key] += to_row[key] }
          data[:table_rows] << to_row

          data[:table_totals][:pdd] += pdd_total
          data[:table_totals][:pdd_counter] += pdd_not_zero if pdd_not_zero > 0
        end

        data[:table_totals][:asr] = ((data[:table_totals][:answered_calls].to_d / data[:table_totals][:total_calls].to_d) * 100)
        data[:table_totals][:acd] = (data[:table_totals][:duration] / data[:table_totals][:answered_calls].to_d)
        data[:table_totals][:profit] = data[:table_totals][:billed_originator] - data[:table_totals][:billed_terminator]
        data[:table_totals][:profit_percent] = ((data[:table_totals][:profit].to_d / data[:table_totals][:billed_originator].to_d) * 100)
        [:asr, :acd].each do |key|
          data[:table_totals][key] = 0.to_d if data[:table_totals][key].nan? || data[:table_totals][key].infinite?
        end

        totals_format(data)
      end
    end

    data
  end

  def self.add_input_values(data_out, input, level_data)
    input['billed_originator'] = level_data['agg_by_answered']['total_originator_price']['value'].to_d
    input['billed_terminator'] = level_data['agg_by_answered']['total_terminator_price']['value'].to_d
    input['billed_duration_originator'] = level_data['agg_by_answered']['total_originator_billsec']['value'].to_d
    input['billed_duration_terminator'] = level_data['agg_by_answered']['total_terminator_billsec']['value'].to_d
    input['duration'] = level_data['agg_by_answered']['total_billsec']['value'].to_d
    input['answered_calls'] = level_data['agg_by_answered']['doc_count'].to_i
    input['total_calls'] = level_data['doc_count'].to_i
    input['pdd_avg'] = level_data['pdd']['avg_pdd']['value'].to_d
    input['pdd_total'] = level_data['pdd']['total_pdd']['value'].to_d
    input['pdd_not_zero'] = level_data['pdd']['doc_count'].to_i

    data_out.push(input.clone)
  end

  def self.totals_format(data)
    data[:table_totals][:pdd] = data[:table_totals][:pdd] / data[:table_totals][:pdd_counter].to_d
    data[:table_totals][:pdd] = 0.to_d if data[:table_totals][:pdd].nan? || data[:table_totals][:pdd].infinite?

    [:billed_originator, :billed_originator_with_tax, :billed_terminator, :pdd, :profit, :profit_percent].each do |key|
      data[:table_totals][key] = nice_number_with_separator(
          data[:table_totals][key], data[:options][:number_digits], data[:options][:number_decimal]
      )
    end

    [:billed_duration_originator, :billed_duration_terminator, :duration, :acd].each do |key|
      data[:table_totals][key] = nice_time(data[:table_totals][key], {show_zero: true})
    end

    [:answered_calls, :total_calls].each do |key|
      data[:table_totals][key] = data[:table_totals][key].to_i
    end

    data[:table_totals][:asr] = nice_number_with_separator(data[:table_totals][:asr], 2, data[:options][:number_decimal])
    data[:table_totals][:profit_percent] = nice_number_with_separator(data[:table_totals][:profit_percent], 2, data[:options][:number_decimal])
  end
end
