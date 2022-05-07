# More info on rubyXL methods: https://github.com/weshatheleopard/rubyXL/tree/v3.3.8

require 'rubyXL'
require_relative 'monkey_patches/xlsx_parser_patch'
require_relative 'monkey_patches/legacy_worksheet_patch'
require_relative 'monkey_patches/reference_patch'

module TemplateXL
  class XlsxFile
    def initialize(template_path, save_path)
      if template_path && File.exist?(template_path)
        begin
          parent_template_path = template_path.split('/')[0..-2].join('/')
          parent_save_path = save_path.split('/')[0..-2].join('/')

          system("chmod 777 -R #{parent_save_path}")
          system("chmod 777 -R #{parent_template_path}")
          system("chmod +t #{parent_template_path}")

          @workbook = RubyXL::Parser.parse(template_path)
        rescue => err
          this_debug("Failed to apply template. Error: #{err.message}")
          @workbook = RubyXL::Workbook.new
        end
      else
        @workbook = RubyXL::Workbook.new
      end

      @save_path = save_path
    end

    def add_cell(worksheet, coordinates, value)
      case coordinates
      when String
        x, y = RubyXL::Reference.ref2ind(coordinates)
      when Array
        x, y = coordinates[0].to_i, coordinates[1].to_i
      else
        return false
      end

      return false if x == -1 || y == -1

      cell = worksheet.try(:[], x).try(:[], y)
      cell ? cell.change_contents(value.to_s) : worksheet.add_cell(x, y, value.to_s)

      [x, y]
    end

    def content
      File.open(@save_path).try(:read)
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

      worksheet_hash
    end

    def this_debug(text)
      MorLog.my_debug(
          "TemplateXL::XlsxFile Debug (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}) [#{@save_path}] -> #{text}"
      )
    end
  end
end
