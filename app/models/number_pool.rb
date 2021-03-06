# Number Pool model
class NumberPool < ActiveRecord::Base
  include UniversalHelpers

  attr_protected

  has_many :numbers, dependent: :delete_all

  before_destroy :validate_delete

  after_save :np_data_changed?
  after_create :np_data_changed
  after_destroy :np_data_changed

  def np_data_changed?
    np_data_changed if changed_attributes.present?
  end

  def np_data_changed
    changes_present_set_1
  end

  def changes_present_set_1
    update_column(:changes_present, 1) if persisted?
  end

  def validate_delete
    number_pool_sql = "callerid_number_pool_id = #{id}
                       OR (cli_number_pool_allow_id = #{id} AND cli_allow_type = 2)
                       OR (cli_number_pool_deny_id = #{id} AND cli_deny_type = 2)
                       OR (cld_number_pool_allow_id = #{id} AND cld_allow_type = 2)
                       OR (cld_number_pool_deny_id = #{id} AND cld_deny_type = 2)"
    device = Device.where(number_pool_sql).first
    # Static Destination
    user = User.where(static_list_id: id).first
    default_user_static = Confline.get_value('Default_User_enable_static_list', 0).to_s
    default_user_nb_id = Confline.get_value('Default_User_static_list_id', 0).to_i
    # Static Source
    user_source = User.where(static_source_list_id: id).first
    default_user_static_source = Confline.get_value('Default_User_enable_static_source_list', 0).to_s
    default_user_source_nb_id = Confline.get_value('Default_User_static_source_list_id', 0).to_i

    errors.add(:device, _('number_pool_used_in_device')) if device.present?

    if (user.present? && %w[blacklist whitelist].include?(user.enable_static_list.to_s)) ||
       (user_source.present? && %w[blacklist whitelist].include?(user_source.enable_static_source_list.to_s))
      errors.add(:user, _('number_pool_used_in_user'))
    end

    if (default_user_nb_id == id && %w[blacklist whitelist].include?(default_user_static)) ||
       (default_user_source_nb_id == id && %w[blacklist whitelist].include?(default_user_static_source))
      errors.add(:user, _('number_pool_used_in_default_user'))
    end

    errors.blank?
  end

  def bad_numbers
    dup_f = "duplicate_numbers_in_file_#{id}"
    exs_f = "existing_numbers_in_db_#{id}"
    files = if Confline.get_value('Load_CSV_From_Remote_Mysql').to_i == 1
              [
                load_file_through_database(dup_f, 'txt', '/tmp/m2/'),
                load_file_through_database(exs_f, 'txt', '/tmp/m2/')
              ].reject(&:nil?).size
            end

    return [] unless !files || files > 0

    dups = []
    system("cat /tmp/m2/#{dup_f}.txt /tmp/m2/#{exs_f}.txt | sort | uniq > /tmp/m2/dup_in_#{id}.txt")
    File.open("/tmp/m2/dup_in_#{id}.txt", 'r').each_line { |line| dups << line }
    dups
  end

  def self.number_pools_order_by(options)
    case options[:order_by].to_s.strip
      when 'id'
        order_by = 'id'
      when 'name'
        order_by = 'name'
      when 'numbers'
        order_by = 'num'
      else
        order_by = options[:order_by]
    end

    if order_by != ''
      order_by << ((options[:order_desc].to_i == 0) ? ' ASC' : ' DESC')
    end
    order_by
  end
end
