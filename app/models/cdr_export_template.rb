# -*- encoding : utf-8 -*-
# CDR Export Templates allow to create templates with specific columns for CSV files.
# These templates can be used to export CDRs from Last Calls.
class CdrExportTemplate < ActiveRecord::Base
  attr_protected
  has_many :automatic_cdr_exports, foreign_key: :template_id, primary_key: :id

  validates :name,
            uniqueness: {message: _('Name_must_be_unique')},
            presence: {message: _('Name_cannot_be_blank')}

  before_save :set_nice_columns
  before_destroy :has_automatic_cdr_exports?

  def columns_array
    columns.to_s.split(';')
  end

  def set_nice_columns
    headers = CdrExportTemplate.column_headers
    self.nice_columns = columns_array.map { |name| headers[name] }.join(';')
  end

  def self.column_headers
    headers = {
        'calldate2' => _('Date'),
        'clid' => _('Called_from'),
        'dst' => _('Called_to'),
        'prefix' => _('Prefix'),
        'destination' => _('Destination'),
        'nice_billsec' => _('Originator_Billsec'),
        'dispod' => _('hangup_cause'),
        'provider' => _('Terminator'),
        'provider_rate' => _('Terminator_Rate'),
        'provider_price' => _('Terminator_Price'),
        'user' => _('Originator'),
        'user_rate' => _('Originator_Rate'),
        'user_price' => _('Originator_Price'),
        'id' => _('Call_ID'),
        'uniqueid' => _('UniqueID'),
        'src' => _('Source_Number'),
        'dst_original' => _('Destination_Number'),
        'duration' => _('Duration'),
        'billsec' => _('Billsec'),
        'src_device_id' => _('Originator_ID'),
        'dst_device_id' => _('Terminator_ID'),
        'server_id' => _('Server_ID'),
        'hangupcause' => _('Hangup_Cause_Code'),
        'disposition' => _('Disposition'),
        'originator_ip' => _('Originator_IP'),
        'terminator_ip' => _('Terminator_IP'),
        'real_duration' => _('Real_Duration'),
        'real_billsec' => _('Real_Billsec'),
        'provider_billsec' => _('Terminator_Billsec'),
        'dst_user_id' => _('Terminator_User_ID'),
        'destination_name' => _('Destination_Name'),
        'direction_name' => _('Direction_Name')
    }
    headers['answer_time'] = _('Answer_time') if
      Call.column_exists?(:answer_time)
    headers['end_time'] = _('End_Time') if
      ActiveRecord::Base.connection.column_exists?(:calls, :end_time)
    headers['terminated_by'] = _('Terminated_by') if
      ActiveRecord::Base.connection.column_exists?(:calls, :terminated_by)
    headers['pdd'] = _('PDD') if
      ActiveRecord::Base.connection.column_exists?(:calls, :pdd)
    headers['src_user_id'] = _('Originator_User_ID') if
      ActiveRecord::Base.connection.column_exists?(:calls, :src_user_id)
    headers['nice_src_device'] = _('Device') if
      Confline.get_value('Show_device_and_cid_in_last_calls').to_i == 1
    headers['originator_codec'] = _('Originator_Codec') if Call.column_exists?(:originator_codec)
    headers['terminator_codec'] = _('Terminator_Codec') if Call.column_exists?(:terminator_codec)
    headers['pai_number'] = _('PAI_Number') if Call.column_exists?(:pai)

    if Confline.get_value('M4_Functionality').to_i == 1
      Call.get_v3_columns.each do |col|
        if col == 'op_codec'
          headers['originator_codec'] = _('Originator_Codec')
        elsif col == 'tp_codec'
          headers['terminator_codec'] = _('Terminator_Codec')
        else
          headers[col] = nice_column_name[col]
        end
      end
    end

    headers
  end

  def self.update_setting_changes
    if Confline.get_value('Show_device_and_cid_in_last_calls').to_i == 0
      CdrExportTemplate.where("columns LIKE '%nice_src_device%'").all.each do |template|
        template.columns = template.columns.sub('nice_src_device', '')
        template.set_nice_columns
        template.save
      end
    end
  end

  private

  def has_automatic_cdr_exports?
    errors.add(:has_automatic_cdr_exports, _('One_or_more_Automatic_CDR_Exports_are_using_this_Template')) if automatic_cdr_exports.present?
    errors.blank?
  end

  def self.nice_column_name
    {
      'rpid' => _('RP_ID'),
      'tp_src'=> _('Terminator_Source'),
      'tp_dst' => _('Terminator_Destination'),
      'dc' => _('Disconnect_Code'),
      'op_dc' => _('Originator_Disconnect_Code'),
      'tp_dc' => _('Terminator_Disconnect_Code'),
      'routing_attempt' => _('Routing_Attempt'),
      'op_signaling_ip' => _('Originator_Signaling_IP'),
      'tp_signaling_ip' => _('Terminator_Signaling_IP'),
      'op_media_ip' => _('Originator_Media_IP'),
      'tp_media_ip' => _('Terminator_Media_IP'),
      'op_codec' => _('Originator_Codec'),
      'tp_codec' => _('Terminator_Codec'),
      'op_user_agent_id' => _('Originator_Agent_ID'),
      'tp_user_agent_id' => _('Terminator_Agent_ID'),
      'mos' => _('MOS'),
      'mos_packetloss' => _('MOS_Packet_Loss'),
      'mos_jitter' => _('MOS_Jitter'),
      'mos_roundtrip' => _('MOS_Roundtrip')
    }
  end
end
