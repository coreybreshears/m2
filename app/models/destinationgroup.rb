# -*- encoding : utf-8 -*-
# Destination Groups Model
class Destinationgroup < ActiveRecord::Base

  attr_protected

  has_many :destinations, -> { order(:prefix) }
  has_many :rates

  validates_presence_of :name

  # Destinations which haven't assigned to destination group by first letter
  def free_destinations_by_st(st)
    adests = Destination.find_by_sql ["SELECT destinations.* FROM destinations, directions WHERE destinations.destinationgroup_id = 0 AND directions.code = destinations.direction_code AND directions.name like ? ORDER BY directions.name ASC, destinations.prefix ASC", st.to_s+'%']
    adests - self.destinations
  end

  def rate(tariff_id)
    Rate.where(tariff_id: tariff_id).first
  end

  def Destinationgroup.destinationgroups_order_by(options)
    order_by = case options[:order_by].to_s.strip
                 when 'country'
                   'directions.name'
                 when 'prefix'
                   'prefix'
                 when 'destination'
                   'name'
                 else
                   'dgn'
               end

    order_by += (options[:order_desc].to_i == 0 ? ' ASC' : ' DESC') if order_by.present?

    order_by
  end

  def self.get_destination_groups
    groups = Destinationgroup.select(:id, :name).order(:name).map { |dg| [dg.id.to_s, dg.name.to_s] }
    return ([['none', _('Not_assigned')]] + groups)
  end

   def self.csv_file_upload(options)
    MorLog.my_debug('Prefix file upload for destination groups - start', true)

    result = {
      table_name: '',
      errors: []
    }
    uploaded_file = options[:file].read.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '?').gsub("\r\n", "\n")

    filepath = '/tmp/m2/destination_groups/'

    `mkdir -p #{filepath}`

    filename = CsvImportDb.save_file('prefix', uploaded_file, filepath)
    begin
      headers = File.open("#{filepath}#{filename}.csv", &:gets).to_s.chomp.split(Confline.get_value('CSV_Separator').to_s)
    rescue => error
      MorLog.my_debug("Error while reading file. Error: #{error.message}", true)
      result[:errors] << _('Invalid_CSV_file')
    end

    if filename && result[:errors].blank?
      MorLog.my_debug("Temp file was created: #{filename}.csv", true)
      MorLog.my_debug("Checking CSV file headers", true)
      result[:table_name] = "#{filename}"
      valid_headers = Destinationgroup.check_prefix_import_headers(headers, filepath, filename)
      if valid_headers
        db_upload = Destinationgroup.load_to_temporary_table(headers, filepath, filename)
        result[:errors] << _('File_upload_failed') unless db_upload
      else
        result[:errors] << _('Invalid_CSV_headers_or_column_separator')
      end
    end

    `rm -rf #{filepath}#{filename}.csv`
    MorLog.my_debug('Prefix file upload for destination groups - end', true)
    result
  end

  def self.load_to_temporary_table(headers, filepath, filename)
    result = true
    MorLog.my_debug('Load file to temporary table - start', true)

    temp_table = {
      name: "#{filename}",
      columns: [{name: 'id', type: 'INT(11)', additional: 'NOT NULL AUTO_INCREMENT'}],
      keys: ['PRIMARY KEY (`id`)'],
      import_columns: []
    }

    headers.each do |header|
      case header
        when 'prefix'
          temp_table[:columns] << {name: 'prefix', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'prefix'
        when 'action'
          temp_table[:columns] << {name: 'action', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'action'
        when 'dst_group_name'
          temp_table[:columns] << {name: 'dst_group_name', type: 'VARCHAR(255)'}
          temp_table[:import_columns] << 'dst_group_name'
      end
    end

    begin
      CsvImportDb.prefix_temp_import(temp_table, "#{filepath}#{filename}.csv")
    rescue => error
      MorLog.my_debug("Error while uploading file to DB. Error: #{error}", true)
      result = false
    end

    MorLog.my_debug('Load file to temporary table - end', true)
    result
  end

  def self.check_prefix_import_headers(headers, filepath, filename)
    result = true
    if headers.blank? || (headers - %w[prefix action dst_group_name]).present?
      MorLog.my_debug('Invalid CSV headers or file format found. Skipping', true)
      result = false
    else
      MorLog.my_debug('CSV file headers are valid', true)
    end
    result
  end

  def self.map_prefix_import(table_name)
    MorLog.my_debug('Prefix map - start', true)
    destinations_to_remove = Destinationgroup.map_remove(table_name)
    destinations_to_add = Destinationgroup.map_add(table_name)
    total_size_sql = "SELECT COUNT(id) FROM #{table_name}"
    total_size = ActiveRecord::Base.connection.exec_query(total_size_sql).rows.flatten[0].to_i
    MorLog.my_debug('Prefix map - end', true)

    return false unless destinations_to_remove[:status] && destinations_to_add[:status]

    assigned_size = destinations_to_add[:assigned].to_a.map{|id| id['id']}.size
    unassigned_size = destinations_to_add[:unassigned].to_a.map{|id| id['id']}.size
    found_size =  assigned_size + unassigned_size + destinations_to_remove[:sql_result].size

    {
      total_size: total_size,
      add_size: assigned_size + unassigned_size,
      remove_size: destinations_to_remove[:sql_result].size,
      invalid: total_size - found_size
    }
  end


  def self.map_remove(table_name)
    status = true
    sql_result = ''
    MorLog.my_debug('Mapping for remove', true)
    begin
      sql = "SELECT destinations.id FROM #{table_name}
             LEFT JOIN destinationgroups ON destinationgroups.name = dst_group_name
             LEFT JOIN destinations ON destinations.destinationgroup_id = destinationgroups.id
             WHERE action = 'remove' AND destinations.prefix = #{table_name}.prefix;"
      sql_result = ActiveRecord::Base.connection.exec_query(sql)
      MorLog.my_debug('Mapping for remove success', true)
    rescue => error
      status = false
      MorLog.my_debug('Mapping for remove failed. Error: #{error.message}', true)
    end

    {
      sql_result: sql_result,
      status: status
    }
  end

  def self.map_add(table_name)
    status = true
    assigned_sql_result = ''
    unassigned_sql_result = ''

    MorLog.my_debug('Mapping for add', true)
    begin
      dst_sql = "SELECT first.name FROM (SELECT name, COUNT(name) FROM destinationgroups GROUP BY name HAVING COUNT(name) = 1) as first
                 LEFT JOIN (SELECT DISTINCT dst_group_name FROM #{table_name}) as second
                 ON second.dst_group_name = first.name WHERE second.dst_group_name = first.name;"

      dst_group_names = ActiveRecord::Base.connection.exec_query(dst_sql).rows.flatten.join('\',\'')

      assigned_sql = "SELECT destinations.id, dst_group_name FROM #{table_name}
                      LEFT JOIN destinations ON destinations.prefix = #{table_name}.prefix
                      LEFT JOIN destinationgroups ON destinations.destinationgroup_id = destinationgroups.id
                      WHERE action = 'add' AND destinationgroups.name != dst_group_name AND dst_group_name IN ('#{dst_group_names}');"

      unassigned_sql = "SELECT destinations.id, dst_group_name FROM #{table_name}
                        LEFT JOIN destinations ON destinations.prefix = #{table_name}.prefix
                        WHERE action = 'add' AND destinations.destinationgroup_id = 0 AND dst_group_name IN ('#{dst_group_names}');"

      assigned_sql_result = ActiveRecord::Base.connection.exec_query(assigned_sql)
      unassigned_sql_result = ActiveRecord::Base.connection.exec_query(unassigned_sql)
      MorLog.my_debug('Mapping for add success', true)
    rescue => error
      MorLog.my_debug('Mapping for add failed. Error: #{error.message}', true)
      status = false
    end

    {
      assigned: assigned_sql_result,
      unassigned: unassigned_sql_result,
      status: status
    }
  end

  def self.analyze_temp_table(table_name, search = {})
    invalid = []
    invalid += Destinationgroup.analyze_temp_multiple_dst_groups(table_name, search).rows if Destinationgroup.temp_analyze?(search, 'multiple')
    invalid += Destinationgroup.analyze_temp_assigned(table_name, search).rows if Destinationgroup.temp_analyze?(search, 'assigned')
    invalid += Destinationgroup.analyze_temp_unassigned(table_name, search).rows if Destinationgroup.temp_analyze?(search, 'unassigned')
    invalid += Destinationgroup.analyze_temp_invalid_data(table_name, search).rows if Destinationgroup.temp_analyze?(search, 'data')
    invalid.reject { |inv| inv.blank? }
  end

  def self.analyze_temp_multiple_dst_groups(table_name, search)
    dst_sql = "SELECT first.name FROM (SELECT name, COUNT(name) FROM destinationgroups GROUP BY name HAVING COUNT(name) > 1) as first
               LEFT JOIN (SELECT DISTINCT dst_group_name FROM #{table_name}) as second
               ON second.dst_group_name = first.name WHERE second.dst_group_name = first.name;"

    dst_group_names = ActiveRecord::Base.connection.exec_query(dst_sql).rows.flatten.join('\',\'')

    assigned_sql = "SELECT #{table_name}.id, #{table_name}.prefix, action, dst_group_name, 'Multiple_Destination_groups_exist' FROM #{table_name}
                    WHERE action = 'add' AND #{table_name}.prefix IN(SELECT destinations.prefix from destinations)
                    AND dst_group_name IN ('#{dst_group_names}')"
    assigned_sql = Destinationgroup.analyze_temp_apply_search(assigned_sql, table_name, search)
    ActiveRecord::Base.connection.exec_query(assigned_sql)
  end

  def self.analyze_temp_assigned(table_name, search)
    dst_sql = "SELECT first.name FROM (SELECT name, COUNT(name) FROM destinationgroups GROUP BY name HAVING COUNT(name) = 1) as first
               LEFT JOIN (SELECT DISTINCT dst_group_name FROM #{table_name}) as second
               ON second.dst_group_name = first.name WHERE second.dst_group_name = first.name;"

    dst_group_names = ActiveRecord::Base.connection.exec_query(dst_sql).rows.flatten.join('\',\'')
    assigned_sql = "SELECT #{table_name}.id, #{table_name}.prefix, action, dst_group_name, 'Already_Assigned' FROM #{table_name}
                    LEFT JOIN destinations ON destinations.prefix = #{table_name}.prefix
                    LEFT JOIN destinationgroups ON destinations.destinationgroup_id = destinationgroups.id
                    WHERE action = 'add' AND destinationgroups.name = dst_group_name AND dst_group_name IN('#{dst_group_names}')"
    assigned_sql = Destinationgroup.analyze_temp_apply_search(assigned_sql, table_name, search)
    ActiveRecord::Base.connection.exec_query(assigned_sql)
  end

  def self.analyze_temp_unassigned(table_name, search)
    unassigned_sql = "SELECT #{table_name}.id, #{table_name}.prefix, action, dst_group_name, 'Already_Unassigned' FROM #{table_name}
                      LEFT JOIN destinations ON destinations.prefix = #{table_name}.prefix
                      WHERE action = 'remove' AND destinations.destinationgroup_id = 0"
    unassigned_sql = Destinationgroup.analyze_temp_apply_search(unassigned_sql, table_name, search)
    ActiveRecord::Base.connection.exec_query(unassigned_sql)
  end

  def self.analyze_temp_invalid_data(table_name, search)
    sql = "SELECT id, prefix, action, dst_group_name, reason FROM
           (SELECT id, prefix, action, dst_group_name, GROUP_CONCAT(reason) as reason FROM
           (SELECT id, prefix, action, dst_group_name, 'Prefix_was_not_found' as reason FROM #{table_name}
           WHERE #{table_name}.prefix NOT IN(SELECT destinations.prefix from destinations)
           UNION ALL
           SELECT id, prefix, action, dst_group_name, 'Destination_group_was_not_found' as reason FROM #{table_name}
           WHERE dst_group_name NOT IN(SELECT destinationgroups.name from destinationgroups)
           UNION ALL
           SELECT id, prefix, action, dst_group_name, 'Action_was_not_found' as reason FROM #{table_name}
           WHERE action NOT IN('add', 'remove')) as t GROUP BY id) as t2
           "
    sql << ((search[:s_reason] == 'all') ? ' WHERE 1' : " WHERE reason LIKE '%#{search[:s_reason]}%'")
    sql = Destinationgroup.analyze_temp_apply_search(sql, table_name, search, false)
    ActiveRecord::Base.connection.exec_query(sql)
  end

  def self.analyze_temp_apply_search(sql, table_name, search, use_table_name = true)
    prefix = use_table_name ? "#{table_name}.prefix" : 'prefix'
    sql << " AND dst_group_name LIKE '#{search[:s_dst_group]}'" if search[:s_dst_group].present?
    sql << " AND #{prefix} LIKE '#{search[:s_prefix]}'" if search[:s_prefix].present?
    sql << " AND action = '#{search[:s_action]}'" if %w[add remove].include?(search[:s_action].to_s) && sql.exclude?('action =')
    sql + ';'
  end

  def self.temp_analyze?(search, function_name)
    case function_name
    when 'multiple'
      return true if %w[all multiple].include?(search[:s_reason]) && %w[all add].include?(search[:s_action])
    when 'assigned'
      return true if %w[all assigned].include?(search[:s_reason]) && %w[all add].include?(search[:s_action])
    when 'unassigned'
      return true if %w[all unassigned].include?(search[:s_reason]) && %w[all remove].include?(search[:s_action])
    when 'data'
      return true if %w[all prefix destination_group action].include?(search[:s_reason]) && %w[all add remove].include?(search[:s_action])
    else
      return false
    end
    false
  end

  def self.prefix_import(table_name)
    MorLog.my_debug('Prefix import - start', true)

    result = {
      status: true,
      error: []
    }

    destinations_to_add = Destinationgroup.map_add(table_name)
    destinations_to_remove = Destinationgroup.map_remove(table_name)

    unless destinations_to_add[:status] && destinations_to_remove[:status]
      result[:status] = false
      result[:error] << _('Map_Failed')
      Destinationgroup.drop_prefix_import_table(table_name)
      MorLog.my_debug('Prefix import - end', true)
      return status
    end

    assigned_destinations = destinations_to_add[:assigned].to_a
    unassigned_destinations = destinations_to_add[:unassigned].to_a
    destinations_to_add = assigned_destinations + unassigned_destinations

    destinations_to_remove = destinations_to_remove[:sql_result].rows.flatten + assigned_destinations.map{|result| result['id']}

    remove_status = Destinationgroup.prefix_import_remove(destinations_to_remove)

    unless remove_status
      result[:status] = false
      result[:error] << _('Remove_Failed')
      Destinationgroup.drop_prefix_import_table(table_name)
      MorLog.my_debug('Prefix import - end', true)
      return status
    end

    add_status = Destinationgroup.prefix_import_add(destinations_to_add)

    unless add_status
      result[:status] = false
      result[:error] << _('Add_Failed')
    end

    Destinationgroup.drop_prefix_import_table(table_name)
    MorLog.my_debug('Prefix import - end', true)
    result
  end

  def self.drop_prefix_import_table(table_name)
    MorLog.my_debug("Dropping temporary table #{table_name}", true)
    ActiveRecord::Base.connection.execute("DROP TABLE #{table_name}")
  end

  def self.prefix_import_remove(destinations_to_remove)
    # remove(unassign) destinations from destination groups
    status = true
    begin
      MorLog.my_debug('Removing destinations', true)
      if destinations_to_remove.size > 0
        destinations_to_remove.in_groups_of(1000, false).each do |dsts_to_remove|
          remove_sql = "UPDATE destinations SET destinationgroup_id = 0 WHERE id IN (#{(dsts_to_remove).join(',')})"
          ActiveRecord::Base.connection.execute(remove_sql)
        end
        MorLog.my_debug('Destinations removed', true)
      else
        MorLog.my_debug('Nothin to remove', true)
      end
    rescue => error
      MorLog.my_debug("Error: #{error.message}", true)
      status = false
    end
    status
  end

  def self.prefix_import_add(destinations_to_add)
    status = true
    begin
      # add(assign) destinations to destination groups
      MorLog.my_debug('Adding destinations', true)
      if destinations_to_add.size > 0
        dst_groups = destinations_to_add.map{|result| result['dst_group_name']}.uniq
        dst_groups.each do |dst_group_name|
          dst_group_id = Destinationgroup.select(:id).where(name: dst_group_name).first.id
          destination_ids = destinations_to_add.map{|result| result['id'] if result['dst_group_name'] == dst_group_name }
          destination_ids = destination_ids.reject{|ids| ids.blank?}
          destination_ids.in_groups_of(1000, false).each do |dsts_to_add|
            ActiveRecord::Base.connection.execute("UPDATE destinations SET destinationgroup_id = #{dst_group_id} WHERE id IN (#{dsts_to_add.join(',')});")
          end
        end
        MorLog.my_debug('Destinations added', true)
      else
        MorLog.my_debug('Nothin to add', true)
      end
    rescue => error
      MorLog.my_debug("Error: #{error.message}", true)
      status = false
    end
    status
  end

  def merge_from(from_dg_id)
    from_dg = Destinationgroup.where(id: from_dg_id).first
    return false unless from_dg
    return false if id == from_dg.id

    ActiveRecord::Base.connection.execute("UPDATE destinations SET destinationgroup_id = #{id} WHERE destinationgroup_id = #{from_dg_id};")
    from_dg.delete
  end

  def self.reasons_dropdown
    [
     [_('All'), 'all'], [_('Multiple_Destination_groups_exist'), 'multiple'],
     [_('Already_Assigned'), 'assigned'], [_('Already_Unassigned'), 'unassigned'],
     [_('Prefix_was_not_found'), 'prefix'], [_('Destination_group_was_not_found'), 'destination_group'],
     [_('Action_was_not_found'), 'action']
    ]
  end
end
