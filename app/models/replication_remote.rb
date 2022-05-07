# -*- encoding : utf-8 -*-
# Remote Replication Database
class ReplicationRemote < ActiveRecord::Base
  establish_connection ({
      adapter:  'mysql2',
      host:     "#{ActiveRecord::Base.connection.select_all('SHOW SLAVE STATUS').first.try(:[], 'Master_Host')}",
      port:     "#{ActiveRecord::Base.connection.select_all('SHOW SLAVE STATUS').first.try(:[], 'Master_Port')}",
      username: "#{ActiveRecord::Base.connection.select_all('SHOW SLAVE STATUS').first.try(:[], 'Master_User')}",
      password: "#{ActiveRecord::Base.connection.select_all('SHOW SLAVE STATUS').first.try(:[], 'Master_User')}",
      database: 'm2'
  })

  def self.db_replication_status
    db_replication = self.connection.select_all('SHOW SLAVE STATUS').first
    if db_replication.present?
      (db_replication['Slave_IO_Running'] == 'Yes') && (db_replication['Slave_SQL_Running'] == 'Yes') ? 1 : 2
    else
      0
    end
  end
end