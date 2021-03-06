# -*- encoding : utf-8 -*-
# I'm not sure why it has ActiveRecord relation, we don't have stats table...
class Stat < ActiveRecord::Base
  attr_protected

  def self.find_rates_and_tariffs_by_number(user_id, collided_prefix)
    collided_prefix = "'#{collided_prefix.join("', '")}'"
    sql =
    "
      SELECT /*+ MAX_EXECUTION_TIME(300000) */
        rates.id AS rate_id,
        rates.prefix AS prefix,
        tariffs.purpose AS purpose,
        tariffs.id AS tariffs_id,
        tariffs.name AS tariff_name,
        tariffs.currency AS currency,
        destinations.direction_code AS direction_code,
        destinations.name AS name,
        ratedetails.id AS ratedetails_id,
        ratedetails.rate AS rate,
        ratedetails.start_time AS start_time,
        ratedetails.end_time AS end_time,
        rates.effective_from AS effective_from
        FROM rates
      INNER JOIN tariffs ON (
        rates.tariff_id = tariffs.id
        AND (tariffs.purpose = 'provider' OR tariffs.purpose = 'user_wholesale')
        AND tariffs.owner_id = #{user_id}
      )
      INNER JOIN (
        SELECT DISTINCT
          ALL_MATCHING_RATES.tariff_id,
          ALL_MATCHING_RATES.destination_id
        FROM
          ( SELECT
            tariffs.id AS tariff_id,
            rates.id AS rate_id,
            rates.destination_id,
            rates.effective_from,
            rates.prefix
          FROM tariffs
          INNER JOIN rates ON (
            rates.prefix IN (#{collided_prefix})
            AND rates.tariff_id = tariffs.id
          )
          WHERE tariffs.owner_id = #{user_id}
          ORDER BY
            LENGTH(rates.prefix) DESC, rates.effective_from DESC ) AS ALL_MATCHING_RATES
        GROUP BY tariff_id
        ) AS LONGEST_PREFIX_DSTS ON (
          rates.tariff_id = LONGEST_PREFIX_DSTS.tariff_id
          AND rates.destination_id = LONGEST_PREFIX_DSTS.destination_id
        )
        JOIN ratedetails ON ratedetails.rate_id = rates.id
        LEFT JOIN destinations ON destinations.id = LONGEST_PREFIX_DSTS.destination_id
    "
    return ActiveRecord::Base.connection.select_all(sql)
    rescue ActiveRecord::StatementInvalid => e
    return ['error', _('Query_execution_time_is_too_long_please_select_shorter_period')] if e.to_s.include?('maximum statement execution time exceeded')
    return ['error', 'Mysql Error']
  end

  def self.find_sql_conditions_for_profit(reseller, session_user_id, user_id, responsible_accountant_id, session_from_datetime, session_till_datetime, up, pp)
    conditions, user_sql2 = [[], '']
    user_id_not_equal_minus_one = (user_id.to_i != -1)

    if reseller
      # conditions << "calls.reseller_id = #{session_user_id}"

      # if user_id_not_equal_minus_one
      #   conditions << "calls.user_id = '#{user_id}'"
      # end

    else
      if user_id && user_id_not_equal_minus_one
        conditions << "calls.user_id IN (SELECT id FROM users WHERE id = '#{user_id}' OR owner_id = #{user_id})"
        user_sql2 = ''
      elsif responsible_accountant_id.to_s != "-1"
        conditions << 'calls.user_id IN (SELECT id FROM users WHERE id IN ' +
                      '(SELECT users.id FROM `users` JOIN users tmp ON(tmp.id = users.responsible_accountant_id) ' +
                      "WHERE tmp.id = '#{responsible_accountant_id}') OR owner_id IN (SELECT users.id FROM `users` " +
                      'JOIN users tmp ON(tmp.id = users.responsible_accountant_id) ' +
                      "WHERE tmp.id = '#{responsible_accountant_id}'))"
        user_sql2 = ''
      end
    end

    conditions << "calls.calldate BETWEEN '#{session_from_datetime}' AND '#{session_till_datetime}'"
    select = ["SUM(IF(calls.billsec > 0, calls.billsec, CEIL(calls.real_billsec) )) AS 'billsec'"]
    select += ["SUM(#{SqlExport.user_price_sql}) AS user_price", "SUM(#{SqlExport.admin_provider_price_sql}) AS provider_price"]

    # if reseller
    #   conditions << "calls.reseller_id = #{session_user_id}"
    # end

    return conditions, user_sql2, select
  end

  def self.manager_users(user_id)
    return User.find_by(id: user_id) if User.check_responsability(user_id)
    User.check_responsability(user_id)
  end
end
