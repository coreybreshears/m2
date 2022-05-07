# -*- encoding : utf-8 -*-
# Model for CDR import template
class CdrImportTemplate < ActiveRecord::Base
  attr_protected

  validates :name,
            uniqueness: { message: _('Name_must_be_unique') },
            presence: { message: _('Name_cannot_be_blank') }
  validates_presence_of :start_time_col, message: _('start_time_column_must_be_presented')
  validates_presence_of :dst_col, message: _('dst_column_must_be_presented')
  validates_presence_of :billsec_col, message: _('billsec_column_must_be_presented')
  validates_numericality_of :skip_n_first_lines, message: _('number_of_lines_must_be_numerical')
  validates_length_of :decimal_seperator, maximum: 1, message: _('Decimal_seperator_cannot_be_longer')
  validates_length_of :column_seperator, maximum: 1, message: _('Column_seperator_cannot_be_longer')

  def import_options(session)
    {
      imp_date: -1,
      imp_time: -1,
      imp_calldate: nice_template_column(start_time_col, session),
      imp_clid: nice_template_column(clid_col, session),
      imp_src_name: nice_template_column(src_name_col, session),
      imp_src_number: nice_template_column(src_number_col, session),
      imp_dst: nice_template_column(dst_col, session),
      imp_duration: nice_template_column(duration_col, session),
      imp_billsec: nice_template_column(billsec_col, session),
      imp_disposition: nice_template_column(disposition_col, session),
      imp_accountcode: nice_template_column(accountcode_col, session),
      imp_provider_id: nice_template_column(provider_id_col, session),
      sep: column_seperator,
      dec: decimal_seperator,
      imp_answer_time: nice_template_column(answer_time_col, session),
      imp_end_time: nice_template_column(end_time_col, session),
      imp_cost: nice_template_column(cost_col, session),
      date_format: date_format,
      template_use: true,
      imp_hangup_cause: nice_template_column(hangupcause_col, session)
    }
  end

  def nice_template_column(column, session)
    # This method is made in case, if template has more columns
    # than actual file. For example Template has column:
    # SRC_number = COL_13
    # BUT file only has 3 columns.
    # So there is a problem in further actions, where analyzing starts.
    # Analysis will try to check whats in TMP table import_csv__crd__.col_13
    # But this column, will not exist in that table.
    # This code will check if this column exist, if not, it will be ignored
    # and wont have any inpact in further actions.
    column && ActiveRecord::Base.connection.column_exists?("#{session}", "col_#{column}") ? column : -1
  end
end
