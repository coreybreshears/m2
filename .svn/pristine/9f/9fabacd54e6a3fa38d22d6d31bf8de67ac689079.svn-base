require_relative  '../xlsx_file'

module TemplateXL
  class RateNotification < XlsxFile
    attr_accessor :workbook

    # Parses the XLSX template and assigns it to @workbook
    def initialize(template_path, save_path, rate_notification_template, rate_notification_job)
      super(template_path, save_path)
      @rnt = rate_notification_template
      @rnj = rate_notification_job
    end

    def populate_data
      worksheet = @workbook.first

      # Client
      add_cell(worksheet, "#{@rnt.client_column}#{@rnt.client_row}", @rnj.user.nice_user)

      # Currency
      default_currency = Confline.get_value('tariff_currency_in_csv_export').to_i
      exrate = Currency.count_exchange_rate(@rnj.tariff.currency, @rnj.user.currency.name)
      currency_name = (default_currency == 0) ? @rnj.user.currency.name.to_s : @rnj.tariff.currency.to_s

      add_cell(worksheet, "#{@rnt.currency_column}#{@rnt.currency_row}", currency_name)

      # Timezone
      timezone_name = Time.now.in_time_zone(@rnj.user.time_zone).time_zone.to_s

      add_cell(worksheet, "#{@rnt.timezone_column}#{@rnt.timezone_row}", timezone_name)

      # Footer
      if @rnt.footer_row.to_i > 0
        add_cell(worksheet, "#{@rnt.footer_column}#{@rnt.header_rows.to_i + @rnt.footer_row.to_i + 1}", @rnt.footer_text.to_s)
      end

      # Headers
      # Destination Group
      add_cell(worksheet, "#{@rnt.destination_group_column}#{@rnt.header_rows}", @rnt.destination_group_header_name.to_s)

      # Destination
      add_cell(worksheet, "#{@rnt.destination_column}#{@rnt.header_rows}", @rnt.destination_header_name.to_s)

      # Dial Code/Prefix
      add_cell(worksheet, "#{@rnt.prefix_column}#{@rnt.header_rows}", @rnt.prefix_header_name.to_s)

      # Rate
      add_cell(worksheet, "#{@rnt.rate_column}#{@rnt.header_rows}", @rnt.rate_header_name.to_s)

      # Effective From
      add_cell(worksheet, "#{@rnt.effective_from_column}#{@rnt.header_rows}", @rnt.effective_from_header_name.to_s)

      # Rate Difference
      add_cell(worksheet, "#{@rnt.rate_difference_raw_column}#{@rnt.header_rows}", @rnt.rate_difference_raw_header_name.to_s)

      # Rate Difference %
      add_cell(worksheet, "#{@rnt.rate_difference_percentage_column}#{@rnt.header_rows}", @rnt.rate_difference_percentage_header_name.to_s)

      # Connection Fee
      add_cell(worksheet, "#{@rnt.connection_fee_column}#{@rnt.header_rows}", @rnt.connection_fee_header_name.to_s)

      # Increment
      add_cell(worksheet, "#{@rnt.increment_column}#{@rnt.header_rows}", @rnt.increment_header_name.to_s)

      # Minimal Time
      add_cell(worksheet, "#{@rnt.minimal_time_column}#{@rnt.header_rows}", @rnt.minimal_time_header_name.to_s)

      # Billing Terms
      add_cell(worksheet, "#{@rnt.billing_terms_column}#{@rnt.header_rows}", @rnt.billing_terms_header_name.to_s)

      # Status
      add_cell(worksheet, "#{@rnt.status_column}#{@rnt.header_rows}", @rnt.status_header_name.to_s)

      # Custom Column 1
      add_cell(worksheet, "#{@rnt.custom_column_1_column}#{@rnt.header_rows}", @rnt.custom_column_1_header_name.to_s)

      # Custom Column 2
      add_cell(worksheet, "#{@rnt.custom_column_2_column}#{@rnt.header_rows}", @rnt.custom_column_2_header_name.to_s)

      # Custom Column 3
      add_cell(worksheet, "#{@rnt.custom_column_3_column}#{@rnt.header_rows}", @rnt.custom_column_3_header_name.to_s)

      # Custom Column 4
      add_cell(worksheet, "#{@rnt.custom_column_4_column}#{@rnt.header_rows}", @rnt.custom_column_4_header_name.to_s)

      # Custom Column 5
      add_cell(worksheet, "#{@rnt.custom_column_5_column}#{@rnt.header_rows}", @rnt.custom_column_5_header_name.to_s)

      # Rates Data
      rates_data_row = @rnt.header_rows.to_i + 1

      sql = "SELECT * FROM rate_notification_data_#{@rnj.id}"
      results = Array(ActiveRecord::Base.connection.select_all(sql))

      results.each_with_index do |result, result_index|
        if default_currency == 0
          rate, rate_difference = Currency.count_exchange_prices(exrate: exrate, prices: [result['price'].to_d, result['price_difference_raw'].to_d])
        else
          rate = result['price'].to_d
          rate_difference = result['price_difference_raw'].to_d
        end

        effective_from_value = nice_date_time_for_user(result['effective_from'])
        status_value = []
        status_value << _('new') if result['is_new'].to_i == 1
        status_value << _('Blocked') if result['is_blocked'].to_i == 1
        status_value << _('Deleted') if result['is_deleted'].to_i == 1

        # Destination Group
        add_cell(worksheet, "#{@rnt.destination_group_column}#{rates_data_row + result_index}", result['destinationgroup_name'].to_s)

        # Destination
        add_cell(worksheet, "#{@rnt.destination_column}#{rates_data_row + result_index}", result['destination_name'].to_s)

        # Dial Code/Prefix
        add_cell(worksheet, "#{@rnt.prefix_column}#{rates_data_row + result_index}", result['prefix'].to_s)

        # Rate
        add_cell(worksheet, "#{@rnt.rate_column}#{rates_data_row + result_index}", sprintf("%0.8f", rate.to_d.round(8)))

        # Effective From
        add_cell(worksheet, "#{@rnt.effective_from_column}#{rates_data_row + result_index}", effective_from_value.to_s)

        # Rate Difference
        add_cell(worksheet, "#{@rnt.rate_difference_raw_column}#{rates_data_row + result_index}", rate_difference.to_s)

        # Rate Difference %
        add_cell(worksheet, "#{@rnt.rate_difference_percentage_column}#{rates_data_row + result_index}", result['price_difference_percentage'].to_s)

        # Connection Fee
        add_cell(worksheet, "#{@rnt.connection_fee_column}#{rates_data_row + result_index}", result['connection_fee'].to_s)

        # Increment
        add_cell(worksheet, "#{@rnt.increment_column}#{rates_data_row + result_index}", result['increment'].to_s)

        # Minimal Time
        add_cell(worksheet, "#{@rnt.minimal_time_column}#{rates_data_row + result_index}", result['minimal_time'].to_s)

        # Billing Terms
        add_cell(worksheet, "#{@rnt.billing_terms_column}#{rates_data_row + result_index}", "#{result['minimal_time']}/#{result['increment']}/0")

        # Status
        add_cell(worksheet, "#{@rnt.status_column}#{rates_data_row + result_index}", status_value.join(', ').to_s)

        # Custom Column 1
        add_cell(worksheet, "#{@rnt.custom_column_1_column}#{rates_data_row + result_index}", @rnt.custom_column_1_text.to_s)

        # Custom Column 2
        add_cell(worksheet, "#{@rnt.custom_column_2_column}#{rates_data_row + result_index}", @rnt.custom_column_2_text.to_s)

        # Custom Column 3
        add_cell(worksheet, "#{@rnt.custom_column_3_column}#{rates_data_row + result_index}", @rnt.custom_column_3_text.to_s)

        # Custom Column 4
        add_cell(worksheet, "#{@rnt.custom_column_4_column}#{rates_data_row + result_index}", @rnt.custom_column_4_text.to_s)

        # Custom Column 5
        add_cell(worksheet, "#{@rnt.custom_column_5_column}#{rates_data_row + result_index}", @rnt.custom_column_5_text.to_s)

        worksheet.insert_row(rates_data_row + result_index) if results.size != (result_index + 1)
      end
    end

    private

    def nice_date_time_for_user(time)
      return '' unless time

      format = '%Y-%m-%d %H:%M:%S'
      t = time.respond_to?(:strftime) ? time : time.to_time
      @rnj.user.user_time(t).strftime(format.to_s)
    end
  end
end