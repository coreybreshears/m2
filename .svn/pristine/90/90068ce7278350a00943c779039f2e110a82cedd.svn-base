# Monkey Patched
require 'rubyXL'

module RubyXL::LegacyWorksheet
  # Inserts row at row_index, pushes down, copies style from the row above (that's what Excel 2013 does!)
  # NOTE: use of this method will break formulas which reference cells which are being "pushed down"
  def insert_row(row_index = 0)
    validate_workbook
    ensure_cell_exists(row_index)

    old_row = new_cells = nil

    if row_index > 0 then
      old_row = sheet_data.rows[row_index - 1]
      if old_row then
        new_cells = old_row.cells.collect { |c|
          if c.nil? then nil
          else nc = RubyXL::Cell.new(:style_index => c.style_index)
          nc.worksheet = self
          nc
          end
        }
      end
    end

    row0 = sheet_data.rows[0]
    new_cells ||= Array.new((row0 && row0.cells.size) || 0)

    sheet_data.rows.insert(row_index, nil)
    new_row = add_row(row_index, :cells => new_cells, :style_index => old_row && old_row.style_index)

    # Update row values for all rows below                         #
    row_index.upto(sheet_data.rows.size - 1) { |r|                 # This code block was patched, to
      row = sheet_data.rows[r]                                     #   create valid Cell objects.
      next if row.nil?                                             #
      row.cells.each_with_index { |cell, c|                        #
        next if cell.nil?                                          #
        cell.r = RubyXL::Reference.new(r, c)                       #
      }                                                            #
    }                                                              #

    if merged_cells                                                                                 #
      merged_cells.each { |cell| cell.ref.shift_down(row_index) }                                   #  This code block was patched, to
                                                                                                    #    deal with merged cells
      # Copy merge info from row before (above)                                                     #    not pushing down
      # NOTE: Only merges that have a length of one row are copied                                  #
      merged_cells.each do |cell|                                                                   #
        if cell.ref.row_range.min == (row_index - 1) && cell.ref.row_range.max == (row_index - 1)   #
          merge_cells(row_index, cell.ref.col_range.min, row_index, cell.ref.col_range.max)         #
        end                                                                                         #
      end                                                                                           #
    end                                                                                             #

    return new_row
  end
end
