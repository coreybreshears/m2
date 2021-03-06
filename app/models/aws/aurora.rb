# -*- encoding : utf-8 -*-

# Module encapsulates Amazon Web Services management functionality
module AWS
  require 'net/http'
  require 'json'

  # Module works as an interface between M2 and Aurora DB.
  #   Current functionality implements a bridge that allows one to
  #   synchronize necessary local tables with Aurora DB and
  #   retrieve connection data that might be needed for other modules
  module Aurora
    class << self
      def sync(force: false)
        return unless force || sync?

        cfg = config
        return unless cfg
        return unless active?(cfg)
        sync_relations(cfg)
      rescue SyncError => err
        MorLog.my_debug("AWS Aurora sync error: #{err.message}")
        false
      end

      # Determines whether a sync is needed and returns true in that case
      def sync?
        curr_time = Time.now
        last_sync = Time.parse(Confline.get_value('AWS_DB_last_sync')) rescue 0
        cool_down = 3600
        curr_time.to_i - last_sync.to_i >= cool_down
      end

      # Performs mysqldump of relation tables
      # Raises: AWS::SyncError when fails to create dump
      # Returns: dump file's absolute path
      def dump_relations
        cfg = main_db_conf
        dmp = "/tmp/m2/aws_ac_relations_#{Time.now.to_i}.sql"
        flg = '--skip-triggers'
        system("mysqldump #{cfg[:database]} #{relations} #{flg} " \
               "-h #{cfg[:host]} -P #{cfg[:port]} " \
               "-u #{cfg[:username]} --password='#{cfg[:password]}' " \
               "> #{dmp}") || fail(SyncError, 'Dump failed')
        local_table =  ActiveRecord::Base.connection.execute('SHOW CREATE TABLE calls_old')
        table_structure = local_table.first[1].insert(13, 'IF NOT EXISTS ')
        fail(SyncError, "Dump '#{dmp}' not found") unless File.exist?(dmp)
        File.open(dmp, "a") do |f|
          f.write table_structure
        end
        dmp
      end

      # Uploads local relations (see. self.relations) on Aurora DB
      # Raises: AWS::SyncError when dump is not found or upload fails
      def sync_relations(cfg)
        Confline.set_value('AWS_DB_last_sync', Time.now.strftime('%Y-%m-%d %H:%M:%S'))
        dmp = dump_relations
        fail(SyncError, "Dump '#{dmp}' not found") unless File.exist?(dmp)

        # Upload mysql dump on a remote Aurora DB
        system("mysql #{cfg[:database]} " \
               "-h #{cfg[:write_host]} -P #{cfg[:port]} " \
               "-u #{cfg[:username]} --password='#{cfg[:password]}' " \
               "< #{dmp}") || fail(SyncError, 'Dump upload failed')
      ensure
        system("rm -rf #{dmp}")
      end

      # Returns locally found Aurora DB configuration if present.
      #   Otherwise downloads a new one from CRM and stores locally.
      #   Retruns nil on failure.
      def config
        cfg = current_conf
        return cfg if cfg && active?(cfg)

        return unless query_crm?
        Confline.set_value('AWS_DB_creds_last_check', Time.now.strftime('%Y-%m-%d %H:%M:%S'))

        begin
          rsp = Net::HTTP.get_response(URI('https://support.ocean-tel.uk/api/aws_aurora_credentials'))
        rescue => error
          MorLog.my_debug("AWS Aurora config sync error when requesting data from CRM:\n#{error}")
          return
        end
        return unless Net::HTTPSuccess

        cfg = JSON.parse(rsp.body).symbolize_keys
        # Defensive check against no config
        return if cfg.slice(:host, :write_host, :port, :username, :password, :database).size != 6
        return if cfg.values.any?(&:blank?)

        Confline.set_aurora_confs(cfg.merge(adapter: 'mysql2'))
      rescue JSON::JSONError
        nil
      end

      # Checks if cooldown time between CRM checks has passed. It is 30 min.
      def query_crm?
        curr_time = Time.now
        last_sync = Time.parse(Confline.get_value('AWS_DB_creds_last_check')) rescue 0
        cool_down = (Confline.get('AWS_DB_creds_check_cooldown').try(:value) || 30).to_i * 60
        curr_time.to_i - last_sync.to_i >= cool_down
      end

      # Configuration for a remote Aurora DB found locally
      def current_conf
        port = Confline.get_value('AWS_DB_Port')
        cfg = {
          adapter:    'mysql2',
          host:       Confline.get_value('AWS_DB_Host_read'),
          write_host: Confline.get_value('AWS_DB_Host_write'),
          port:       port.blank? ? 3306 : port,
          username:   Confline.get_value('AWS_DB_Username'),
          password:   Confline.get_value('AWS_DB_Password'),
          database:   Confline.get_value('AWS_DB_Name')
        }
        cfg.values.any?(&:blank?) ? nil : cfg
      end

      # Local DB configuration from database.conf
      def main_db_conf
        ActiveRecord::Base.configurations[Rails.env].symbolize_keys
      end

      # Local relations that are uploaded on Aurora DB
      def relations
        'users devices destinations directions providers'
      end

      # Simply pings Aurora DB
      def active?(cfg)
        return unless cfg
        system("mysql #{cfg[:database]} -h #{cfg[:host]} -P #{cfg[:port]} " \
               "-u #{cfg[:username]} --password='#{cfg[:password]}' " \
               "-e 'USE #{cfg[:database]}' --connect-timeout=10")
      end

      def sync_tables
        cfg = config
        return unless cfg
        return unless active?(cfg)
        return if check_tables(cfg)
        sync_relations(cfg)
      rescue SyncError => err
        MorLog.my_debug("AWS Aurora sync tables error: #{err.message}")
        false
      end

      # checks if tables exists
      def check_tables(cfg)
        return unless cfg

        relation_tables = (relations << ' calls_old')
        count = `mysql #{cfg[:database]} -h #{cfg[:host]} -P #{cfg[:port]} -u #{cfg[:username]} --password='#{cfg[:password]}' --disable-column-names -B -e 'SELECT count(*)  FROM information_schema.tables WHERE table_schema = "#{cfg[:database]}" AND table_name in (#{relation_tables.split.map {|e| "\"#{e}\"" }.join(',')})'  --connect-timeout=10`

        (count.present? && count.to_i == relation_tables.split.count)
      end
    end
  end

  # Synchronization error can be caused by failed mysqldump
  #   or by unsuccessful Aurora DB connection
  class SyncError < StandardError
    def initlialize(msg)
      super(msg)
    end
  end
end
