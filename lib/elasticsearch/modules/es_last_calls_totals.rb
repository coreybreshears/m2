#-*- encoding : utf-8 -*-
module EsLastCallsTotals

  def self.last_calls_totals(options)
    options[:device_ids] = options[:s_user_id].blank? ? [] : Device.where(user_id: options[:s_user_id]).pluck(:id)
    options[:tp_device_ids] = options[:s_user_terminator_id].blank? ? [] : Device.where(user_id: options[:s_user_terminator_id]).pluck(:id)


    options[:hangup] = options[:s_hgc].blank? ? [] : Hangupcausecode.where(id: options[:s_hgc]).first.try(:code)
    current_user = options[:current_user]
    if current_user.show_only_assigned_users?
      options[:assigned_users] = User.where("users.responsible_accountant_id = #{current_user.id}").pluck(:id)
      options[:assigned_users_device_ids] = if options[:assigned_users].blank?
                                              []
                                            else
                                              Device.where(user_id: options[:assigned_users]).pluck(:id)
                                            end
    end
    if options[:usertype] == 'user' && Confline.get_value('Invoice_user_billsec_show', current_user[:owner_id]).to_i == 1
      options[:billsec_field] = 'user_billsec'
    else
      options[:billsec_field] = 'billsec'
    end

    # When simple user is checking calls list page, displayed price should depend on who made a call
    # If user made a call show user_price
    # If someone else made a call trough user's terminator, show provider_price
    if options[:usertype] == 'user'
      options[:user_price_script] = "doc.provider_id.value == #{current_user[:id]} ? doc.provider_price.value : doc.user_price.value"
    else
      options[:user_price_script] = 'doc.user_price.value'
    end

    options[:calls_ids_by_unique_id] = options[:uniqueid].blank? ? [] : Call.where("uniqueid LIKE #{ActiveRecord::Base::sanitize((options[:uniqueid].size < 32 ? (options[:uniqueid].gsub('%', '') + '%') : options[:uniqueid][0...32]))}").pluck(:id)

    response = Elasticsearch.safe_search_m2_calls(ElasticsearchQueries.last_calls_totals(options))
    data = data_init
    aggs = response.present? ? response['aggregations'] : nil
    data[:total_calls] = response['hits']['total'] if response.present?

    if aggs.present?
      exrate = options[:exchange_rate]
      # Total duration
      data[:total_duration] = aggs['total_duration']['value']

      # Total billsec
      data[:total_billsec] = aggs['total_billsec']['value']

      # Total Provider price
      data[:total_provider_price] = aggs['total_provider_price']['value'] * exrate

      # Total User price
      data[:total_user_price] = aggs['total_user_price']['value'] * exrate
    end
    data
  end

  private

  def self.data_init
    {
        total_duration: 0, total_billsec: 0, total_provider_price: 0,
        total_user_price: 0, total_calls: 0
    }
  end
end
