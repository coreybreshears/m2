# -*- encoding : utf-8 -*-
module DevicesHelper

  def cp_list_json(cp_in_page, visible_columns)
    # Default Data assignation
    result = {columns: [], rows: [], datafields: []}

    # For metadata manipulation which is not required to be shown in Table
    always_hidden_columns = ['user_id', '_id']

    # Table header manipulation

    visible_columns.each do |column_name|
      column = {}

      case column_name
        when 'id'
          column.merge!(text: 'ID', align: 'center', cellsalign: 'center')
        when 'nice_user'
          column.merge!(text: _('User'), datafield: 'nice_user', cellsrenderer: 'linkrenderer_user')
        when 'hide'
          column.merge!(text: 'Hide', datafield: 'hide', align: 'center', cellsrenderer: 'linkrenderer_hide')
        when 'edit'
          column.merge!(text: 'Edit', datafield: 'edit', align: 'center', cellsrenderer: 'linkrenderer_edit')
        when 'delete'
          column.merge!(text: 'Delete', datafield: 'delete', align: 'center', cellsrenderer: 'linkrenderer_delete')
        else
          column[:text] = column_name.capitalize
      end

      column[:datafield] ||= column_name

      result[:columns] << column
      result[:datafields] << {name: column[:datafield]}
    end

    # Table Data (Rows) manipulation
    # result[:rows] = cp_in_page.as_json # This is slower and no additional manipulation
    cp_in_page.try(:each) do |cp|
      row = {}

      result[:columns].map { |column_info| column_info[:datafield] }.each do |column|
        # row[column] = case column
        #                 when 'something'
        #                   'SOMETHING'
        #                 else
        #                   cp[column]
        #               end
        row[column] = cp[column]
      end

      result[:rows] << row
    end

    # Table header manipulation for metadata columns
    always_hidden_columns.each do |column_name|
      result[:columns].delete_if { |column_data| column_data[:datafield] == column_name }
    end

    raw result.to_json
  end

  def can_view_registration_info?(device)
    device.auth_dynamic? && device.ipaddr.to_s.present? && device.port.to_s.present?
  end
end
