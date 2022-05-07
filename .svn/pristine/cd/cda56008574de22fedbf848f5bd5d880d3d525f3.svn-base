# -*- encoding : utf-8 -*-
# Disputed CDR model
class DisputedCdr < ActiveRecord::Base
  attr_accessible :start_time, :answer_time, :end_time, :src, :dst, :billsec,
                  :cost, :disposition, :call_id, :dispute_id, :mismatch_type

  belongs_to :dispute

  def self.import_from_temp_csv_cdr_table(dispute_id, table_name, columns)
    mysql_date_format = columns[:date_format].gsub('%M', '%i')

    [
        :imp_answer_time, :imp_end_time, :imp_src_number, :imp_cost, :imp_disposition, :imp_answer_time,
        :imp_end_time, :imp_cost, :imp_disposition
    ].each { |column| columns[column] = -1 if columns[column].to_s != '0' && columns[column].to_i == 0 }

    ActiveRecord::Base.connection.execute("
      INSERT INTO disputed_cdrs (
        start_time, billsec, dst, dispute_id
        #{', answer_time' if columns[:imp_answer_time].to_i > -1}
        #{', end_time' if columns[:imp_end_time].to_i > -1}
        #{', src' if columns[:imp_src_number].to_i > -1}
        #{', cost' if columns[:imp_cost].to_i > -1}
        , disposition
      )
      SELECT
        STR_TO_DATE(col_#{columns[:imp_calldate]}, '#{mysql_date_format}') AS start_time,
        col_#{columns[:imp_billsec]}, col_#{columns[:imp_dst]}, #{dispute_id}
         #{",STR_TO_DATE(col_#{columns[:imp_answer_time]}, '#{mysql_date_format}')" if columns[:imp_answer_time].to_i > -1}
         #{",STR_TO_DATE(col_#{columns[:imp_end_time]}, '#{mysql_date_format}')" if columns[:imp_end_time].to_i > -1}
         #{",col_#{columns[:imp_src_number]}" if columns[:imp_src_number].to_i > -1}
         #{",REPLACE(col_#{columns[:imp_cost]}, '#{columns[:dec]}', '.')" if columns[:imp_cost].to_i > -1}
         #{self.disposition_select_from(columns)}
      FROM
        #{table_name}
      WHERE nice_error != 11 AND nice_error != 12 AND nice_error != 13
      ORDER BY start_time DESC
      LIMIT 100000")

    BackgroundTask.create(
        task_id: 8,
        owner_id: 0,
        created_at: Time.zone.now,
        status: 'WAITING',
        user_id: 0,
        data1: dispute_id
    )

    dispute = Dispute.where(id: dispute_id).first
    dispute.update_attribute(:status, 'IN PROGRESS') if dispute.present?
  end

  private

  def self.disposition_select_from(columns)
    if columns[:imp_disposition].to_i > -1
      ",TRIM(SUBSTRING_INDEX(col_#{columns[:imp_disposition]}, '(', 1))"
    else
      ",IF(CAST(col_#{columns[:imp_billsec]} AS SIGNED) > 0, 'ANSWERED', 'FAILED')"
    end
  end
end
