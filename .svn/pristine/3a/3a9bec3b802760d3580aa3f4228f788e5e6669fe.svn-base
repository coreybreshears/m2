# Hardcoded for Invoices, avoid using for anything else

require 'rubyXL'
require_relative 'monkey_patches/xlsx_parser_patch'
require_relative 'monkey_patches/legacy_worksheet_patch'
require_relative 'monkey_patches/reference_patch'

module TemplateXL
  class Template
    def initialize(template_path, save_path, invoice_cells_confline_owner_id = 0)
      parent_template_path = template_path.split('/')[0..-2].join('/')
      parent_save_path = save_path.split('/')[0..-2].join('/')
      if File.exist?(template_path)
        begin
          system("chmod 777 -R #{parent_save_path}")
          system("chmod 777 -R #{parent_template_path}")
          system("chmod +t #{parent_template_path}")
          @workbook = RubyXL::Parser.parse(template_path)
        rescue => err
          MorLog.my_debug(
            "XLSX Debug (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}) -> "\
            "Failed to apply template. Error: #{err.message}"
          )
          @workbook = RubyXL::Workbook.new
        end
      else
        @workbook = RubyXL::Workbook.new
      end
      @save_path = save_path

      @details = {}
      @lines_details = {}
      @confline_owner_id = invoice_cells_confline_owner_id

      initialize_coordinates
    end

    # This method uses assign_cell_coordinates to collect
    # The method - coordinate pairs that will be added to the template
    # Then it makes the final iteration to modify the key values so they could be evaluated through eval.
    # Finally, the values that come from evaluated hash keys are added to the correspoding cells in the XLSX file.
    def generate
      debug_id = "XLSX Debug - Invoice: #{@save_path} (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}) ->"
      begin
        x2 = @details['m2_invoice.client_details1'].first
        if !@details.blank? or !@lines_details.blank?
          worksheet = @workbook.first
          @details.each do |key, value|
            next if value == [-1, -1]
            x, y = value
            # client_details5 should show destination group name, not id
            if key == 'm2_invoice.client_details5'
              direction_id = eval("@#{key}")
              value = Direction.where(id: direction_id).first.try(:name).to_s
            else
              if key == 'm2_invoice.exchange_rate'
                value = nice_value(eval("@#{key}"), 2).to_d
                # client name depends on setting and can be changed to username or remain as client full name
              elsif key == 'm2_invoice.client_name' && Confline.get_value('invoices_show_username', 0, 0).to_i == 1
                user_id = eval("@m2_invoice.user_id")
                value = User.where(id: user_id).first.try(:username).to_s
              else
                value = nice_value(eval("@#{key}"))
              end
            end
            if key.match(/m2_invoice.client_details[1-6]/)
              x = x2
              x2 += 1 if value.present?
            end
            add_cell(x, y, value, worksheet)
          end
        end
      rescue NoMethodError => err
        #Somebody messed with Cell_m2_invoice_ conflines
        MorLog.my_debug("#{debug_id} Crash in details: #{err.message}")
      end
      invoicedetails_lines = eval(@lines)
      invoicedetails_lines_size = invoicedetails_lines.size
      invoicedetails_lines.each_with_index do |line, line_index|
        ongoing_row = -1

        @lines_details['line.rate'] = [-1, -1] if Confline.get_value('Show_Rates').to_i == 0
        @lines_details['line.destination'] = [-1, -1] if Confline.get_value('Invoice_Group_By').to_i == 1
        @lines_details.each do |key, value|
          next if value == [-1, -1]
          x, y = value
          begin
            if key == 'm2_invoice.exchange_rate'
              value = nice_value(eval(key), 2).to_d
            elsif key == 'line.rate'
              value = nice_value(eval(key), Confline.get_value('nice_number_digits')).to_d
            elsif key == 'line.nice_total_time' && Confline.get_value('Duration_Format').to_s == 'M'
              global_separator = Confline.get_value('Global_Number_Decimal', 0).to_s
              value = nice_value(eval(key).gsub(global_separator, '.'), Confline.get_value('Duration_Format_Minute_Precision')).to_d
            else
              value = nice_value(eval(key))
            end
            add_cell(x, y, (value.nil? ? '' : value), worksheet)
            x = x.next
            ongoing_row = x if x > ongoing_row
            @lines_details[key] = [x, y]
          rescue NoMethodError => err
            # Somebody messed with Cell_m2_invoice_line conflines
            MorLog.my_debug("#{debug_id} Crash in line details: #{err.message}, key: #{key}")
          end
        end
        worksheet.insert_row(ongoing_row) if ongoing_row > 0 && invoicedetails_lines_size != (line_index + 1)
      end
    end

    def add_cell(x, y, value, worksheet)
      cell = worksheet.try(:[], x).try(:[], y)
      if cell
        cell.change_contents(value)
      else
        worksheet.add_cell(x, y, value)
      end
    end

    def content
      data = File.open(@save_path).try(:read)
      data
    end

    def save
      @workbook.write(@save_path)
    end

    def test
      worksheet_hash = {}

      worksheet = @workbook.worksheets.first

      worksheet.each do |row|
        row && row.cells.each do |cell|
          if cell.is_a?(RubyXL::Cell)
            coord = RubyXL::Reference.ind2ref(cell.row, cell.column)
            value = cell.value.to_s
            worksheet_hash[coord] = value
          end
        end
      end
      return worksheet_hash
    end

    private

    def nice_value(value,digits = 0)
        if value.is_a?(Time)
          value = value.strftime('%Y-%m-%d')
        end
      if digits == 0
        return value
      else
        n = ''
        n = sprintf("%0.#{digits}f", value) if value && value.present?
        return n
      end
    end
  end
end