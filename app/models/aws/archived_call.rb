# -*- encoding : utf-8 -*-

# Module encapsulates Amazon Web Services management functionality
module AWS
  # Base class prevents multiple connections for each model
  class ArchivedCallBase < ActiveRecord::Base
    self.abstract_class = true
    # Establishes connection to AWS Aurora DB
    establish_connection(Aurora.config)

    # Model's table name on Aurora DB
    def self.table_name
      'calls_old'
    end
  end

  # Implementation of Archived Calls model.
  #   The model works as an alternative for older OldCall model.
  #   The main difference between the two is that ArchivedCall is
  #   intended to work with Aurora DB and to reduce redundant legacy
  #   code found in OldCall
  class ArchivedCall < ArchivedCallBase
    belongs_to :user

    class << self
      # Checks if Aurora is reachable and working
      def active?
        Aurora.active?(Aurora.config) && connection ? 1 : 0
      rescue StandardError => err
        MorLog.my_debug("AWS Aurora connection error: #{err.message}")
        0
      end

      # Selects archived calls list
      def calls(options)
        Aurora.sync

        # Termination Points
        cnd, var, jns = OldCall.last_calls_parse_params(options)
        jns << 'LEFT JOIN devices ON devices.id = calls_old.dst_device_id'

        fiels = SqlExport.old_calls_fields((options[:exchange_rate] || 1).to_d)

        select(fiels.join(','))
          .where(cnd.join(' AND '), *var)
          .joins(jns.join(' '))
          .order(options[:order])
          .limit(paginate(*options.slice(:page, :items_per_page).values.map(&:to_i)))
      end

      # Selects archived calls totals
      def totals(options)
        cnd, var, jns = OldCall.last_calls_parse_params(options)
        fiels = SqlExport.old_calls_total_fields((options[:exchange_rate] || 1).to_d)
        select(fiels.join(',')).where(cnd.join(' AND '), *var).joins(jns.join(' ')).first
      end

      # Generates archived calls csv file
      def as_csv(options)
        Aurora.sync

        cnd, var, jns = OldCall.last_calls_parse_params(options)
        if options[:s_country].blank?
          jns << "LEFT JOIN destinations ON destinations.prefix = IFNULL(calls_old.prefix, '')"
        end
        jns << 'LEFT JOIN directions ON directions.code = (destinations.direction_code)'

        fields  = SqlExport.old_calls_csv_fields(options)
        columns = fields.keys
        col_sep = options[:collumn_separator]
        csv_row = columns.map(&:to_s).join(",'#{col_sep}',")
        query   = "
          SELECT CONCAT_WS('', #{csv_row}) AS row
          FROM (
            SELECT #{fields.values.join(',')}
            FROM calls_old FORCE INDEX (calldate) #{jns.join(' ')}
            WHERE #{ActiveRecord::Base.sanitize_sql_array([cnd.join(' AND '), *var])}
            ORDER BY #{options[:order]}) AS A
          "

        filename = csv_filename(options)
        File.open("/tmp/#{filename}.csv", 'w') do |file|
          file.write("#{csv_headers.slice(*columns).values.join(col_sep)}\n")
          file.write(connection.select_all(query).rows.join("\n"))
        end

        # For testing purposes
        test_content = ''
        if options[:test].to_i == 1
          resp = ActiveRecord::Base.connection.select_all(query)
          test_content = resp.map { |row| row['row'] }
        end

        [filename, test_content]
      end

      # Creates a limit/offset query for pagination
      def paginate(page, per_page)
        "#{(page - 1) * per_page}, #{per_page}"
      end

      # Generates a name for csv file
      def csv_filename(options)
        "Last_calls_old-#{options[:current_user].id.to_s.gsub(' ', '_')}-" \
          "#{options[:from].gsub(' ', '_').gsub(':', '_')}-" \
          "#{options[:till].gsub(' ', '_').gsub(':', '_')}-#{Time.now.to_i}"
      end

      # Column map to csv header names
      def csv_headers
        {
          calldate2: _('Date'),
          src: _('Called_from'), dst: _('Called_to'),
          prefix: _('Prefix'), destination: _('Destination'),
          nice_billsec: _('Billsec'), dispod: _('Hangup_cause'),
          provider_rate: _('Provider_rate'), provider_price: _('Provider_price'),
          user_rate: _('User_rate'), user_price: _('User_price')
        }
      end
    end
  end
end
