require_relative  '../template'
module TemplateXL
  class M2InvoiceTemplate < Template
    attr_accessor :m2_invoice
    attr_accessor :m2_invoice_lines
    attr_accessor :do_not_include
    attr_accessor :workbook

    # Parses the XLSX template and assigns it to @workbook
    def initialize(template_path, save_path, invoice_cells_confline_owner_id = 0)
      super(template_path, save_path, invoice_cells_confline_owner_id)
      @lines = '@m2_invoice_lines'
      @do_not_include = Confline.get_value('Do_not_include_currencies')
      M2InvoiceLine.reset_destination_number
    end

    private

    # The confline settings are used as user's input for the confline
    # For example, if we have a confline named 'Cell_invoice_exchange_rate'
    # It will assign the value returned by invoice.exchange_rate to Confline's value
    # That could be for example: 'A2'
    # The method below collects Cell_ conflines, and edits them.
    # For example: Cell_invoice_exchange_rate becomes 'invoice.exchange_rate'

    def initialize_coordinates
      invoice_template_coordinates = Confline.where("name LIKE 'Cell_m2_invoice%' AND owner_id = #{@confline_owner_id}").all
      unless invoice_template_coordinates.blank?
        invoice_template_coordinates.each do |confline|
          key = confline.name
          key.sub!('Cell_', '')
          coordinates = RubyXL::Reference.ref2ind(confline.value.to_s)

          if key['m2_invoice_lines']
            @lines_details[key.sub('m2_invoice_lines_', 'line.')] = coordinates
          else
            @details[key.sub('m2_invoice_', 'm2_invoice.')] = coordinates
          end
        end
      end
    end

  end
end