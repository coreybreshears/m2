# -*- encoding : utf-8 -*-
require 'net/ftp'
class Backup < ActiveRecord::Base
  extend UniversalHelpers

  attr_protected


  def send_to_ftp
    ftp_call(:ftp_send)
  end

  def download_from_ftp
    ftp_call(:ftp_download)
  end

  def delete_from_ftp
    ftp_call(:ftp_delete)
  end

  def ftp_call(ftp_method)
    cached_ftp_mode = get_cache_ftp_mode
    if cached_ftp_mode == 'active'
      unless send(ftp_method, get_active_ftp)
        return false unless send(ftp_method, get_passive_ftp)
        set_cache_ftp_mode('passive')
      end
      return true
    else
      unless send(ftp_method, get_passive_ftp)
        return false unless send(ftp_method, get_active_ftp)
        set_cache_ftp_mode('active')
      end
      return true
    end
  end

  def ftp_send(ftp)
    cfg = Backup.current_conf
    begin
      current_dir = ftp.getdir.to_s
      ftp.chdir(current_dir + cfg[:path])
      ftp.putbinaryfile(get_file_name)
      ftp.close
      return true
    rescue => err
      MorLog.my_debug(err.message)
      return false
    end
  end

  def ftp_download(ftp)
    cfg = Backup.current_conf
    begin
      current_dir = ftp.getdir.to_s
      ftp.chdir(current_dir + cfg[:path])
      ftp.getbinaryfile('db_dump_' + self.backuptime.to_s + '.sql.bz2', get_file_name)
      ftp.close
      return true
    rescue => err
      MorLog.my_debug(err.message)
      return false
    end
  end

  def ftp_delete(ftp)
    cfg = Backup.current_conf
    begin
      current_dir = ftp.getdir.to_s
      ftp.chdir(current_dir + cfg[:path])
      ftp.delete('db_dump_' + self.backuptime.to_s + '.sql.bz2')
      ftp.close
      return true
    rescue => err
      MorLog.my_debug(err.message)
      return false
    end
  end

  def self.ftp_test_connection(path)
    cfg = Backup.current_conf
    begin
      ftp = Net::FTP.new
      ftp.connect(cfg[:host], cfg[:port])
      ftp.passive = true
      ftp.debug_mode = true
      ftp.login(cfg[:username], cfg[:password])
      current_dir = ftp.getdir.to_s
      ftp.chdir(current_dir + path)
      ftp.close
      return true
    rescue => err
      MorLog.my_debug(err.message)
      return false
    end
  end

  def save_file_to_ftp
    if send_to_ftp
      MorLog.my_debug('Backup File will be stored on FTP server')
      self.update_attribute(:file_on_ftp, 1)
      remove_file
    else
      MorLog.my_debug('Backup File will be stored on Local server')
    end
  end

  def destroy_all(cfg = nil)
    if file_on_ftp.to_i == 1
      delete_from_ftp
    end
    remove_file
    self.destroy
  end

  def remove_file
    `rm -rf #{get_file_name}`
  end

  def get_file_name
    backup_folder = Confline.get_value('Backup_Folder')
    backup_folder.to_s + '/db_dump_' + self.backuptime.to_s + '.sql.bz2'
  end

  def self.backups_hourly_cronjob(user_id)
    MorLog.my_debug 'Checking hourly backups'
    backup_shedule = Confline.get_value('Backup_shedule')
    backup_month = Confline.get_value('Backup_month')
    backup_month_day = Confline.get_value('Backup_month_day')
    backup_week_day = Confline.get_value('Backup_week_day')
    backup_hour = Confline.get_value('Backup_hour')
    backup_number = Confline.get_value('Backup_number')

    MorLog.my_debug("Make backups at: #{backup_hour} h", true, '%Y-%m-%d %H:%M:%S')
    backup_hour = backup_hour.to_i == 24 ? 0 : backup_hour.to_i

    @time = Time.now()
    if backup_shedule.to_i == 1
      if (backup_month.to_i == @time.month.to_i) or (backup_month.to_s == 'Every_month')
        if (backup_month_day.to_i == @time.day.to_i) or (backup_month_day.to_s == 'Every_day')
          if (backup_week_day.to_i == @time.wday.to_i) or (backup_week_day.to_s == 'Every_day')
            if (backup_hour.to_i == @time.hour.to_i) or (backup_hour.to_s == 'Every_hour')
              res = 0
              MorLog.my_debug 'Making auto backup'

              if space_available?
                # check if we have correct number of auto backups
                ftp_cfg = Backup.current_conf
                MorLog.my_debug 'Checking for old backups'
                Backup.where(backuptype: 'auto').order('backuptime ASC').each do |backup|
                  if Backup.where(backuptype: 'auto').size.to_i >= backup_number.to_i
                    if backup.destroy_all(ftp_cfg)
                      MorLog.my_debug 'Old auto backup deleted'
                    else
                      MorLog.my_debug "Old auto backup(id: #{backup.id}) was not deleted"
                    end
                  end
                  MorLog.my_debug 'Old auto backup deleted'
                end
                #make backup
                res = Backup.private_backup_create(user_id, 'auto', '')
              else
                res = 2
              end

              if res > 0
                MorLog.my_debug('Auto backup failed')
                Action.add_error(user_id, 'Auto Backup', {data2: 'There is not enough space on HDD'})
              else
                MorLog.my_debug('Auto backup created')
              end
            end
          end
        end
      end
    end
  end

  def self.private_backup_create(user_id, backuptype = 'manual', comment = '')
    time = Time.now().to_s(:db)
    backuptime = time.gsub(/[- :]/, '').to_s
    backup_folder = Confline.get_value('Backup_Folder')
    exclude_calls_old = Confline.get_value('Backup_Exclude_Calls_Old').to_i

    backup_folder = '/usr/local/m2/backups' if backup_folder.to_s == ''
    space_available = backuptype == 'auto' ? true : space_available?

    if space_available
      MorLog.my_debug("/usr/local/m2/backups/backup_create.sh #{backuptime} #{backup_folder} #{exclude_calls_old}")

      begin
        script = `/usr/local/m2/backups/backup_create.sh #{backuptime} #{backup_folder} #{exclude_calls_old}`
      rescue Errno::EPIPE
        MorLog.my_debug('Errno::EPIPE - Connection broke!')
      end



      return_code = script.to_s.scan(/\d+/).first.to_i
      MorLog.my_debug(return_code)

      if return_code.zero?
        backup = Backup.new
        backup.comment = comment
        backup.backuptype = backuptype
      	backup.backuptime = backuptime
       	backup.save
        if Confline.get_value('store_backups_on_ftp').to_i == 1
          backup.save_file_to_ftp
        end
       	MorLog.my_debug('Auto backup made', true, '%Y-%m-%d %H:%M:%S')
        Action.add_action_second(user_id.to_i, 'backup_created', backup.id, return_code)
      else
        return_code = 1  # backup script error
      end
  	else
      return_code = 2  # not enought space
    end

    return_code
  end

  private

  def set_cache_ftp_mode(mode = 'passive')
    Confline.set_value('ftp_mode', mode)
  end

  def get_cache_ftp_mode
    Confline.get_value('ftp_mode').to_s
  end

  def get_passive_ftp(cfg = Backup.current_conf)
    MorLog.my_debug('Trying connect to ftp in passive mode')
    ftp = Net::FTP.new
    ftp.connect(cfg[:host], cfg[:port])
    ftp.passive = true
    ftp.debug_mode = true
    ftp.login(cfg[:username], cfg[:password])
    return ftp
    rescue => err
      MorLog.my_debug(err.message)
      return nil
  end

  def get_active_ftp(cfg = Backup.current_conf)
    MorLog.my_debug('Trying connect to ftp in active mode')
    ftp = Net::FTP.new
    ftp.connect(cfg[:host], cfg[:port])
    ftp.debug_mode = true
    ftp.login(cfg[:username], cfg[:password])
    return ftp
    rescue => err
      MorLog.my_debug(err.message)
      return nil
  end

  def self.current_conf
    {
      host: Confline.get_value('ftp_host').to_s,
      username: Confline.get_value('ftp_user').to_s,
      password: Confline.get_value('ftp_pass').to_s,
      path: Confline.get_value('ftp_backups_path').to_s,
      port: Confline.get_value('ftp_port').to_i
    }
  end

  def self.space_available?
    available = true

    MorLog.my_debug('Checking free HDD space')

    backup_folder = Confline.get_value('Backup_Folder').to_s
    backup_disk_space_percent = Confline.get_value('Backup_disk_space')

    db_config = Rails.configuration.database_configuration[Rails.env]
    #Retrieves the space required to make a backup for the Database, in KB
    required_disk_space_from_script = `/usr/bin/mysql -h "#{db_config['host']}" -u #{db_config['username']} --password=#{db_config['password']} "#{db_config['database']}" -e "SELECT ROUND(SUM(Data_length)/1024) AS SIZE FROM  INFORMATION_SCHEMA.PARTITIONS WHERE TABLE_SCHEMA = '#{db_config['database']}' AND   TABLE_NAME  != 'call_logs' AND   TABLE_NAME  != 'sessions'" | tail -n 1`
    required_disk_space = required_disk_space_from_script.to_i * 0.2

    space = disk_space_usage(backup_folder).to_i
    space_percent = (100 - disk_space_usage_percent(backup_folder).to_i)

    MorLog.my_debug "Don't start backup if HDD free space less than: #{100 - backup_disk_space_percent.to_i}%"
    MorLog.my_debug "Free space on HDD for backups: #{space}KB #{space_percent}%"
    MorLog.my_debug "Required space on HDD for backups: #{required_disk_space.to_i}KB"

    if (space < required_disk_space) or (space_percent < backup_disk_space_percent.to_i)
      MorLog.my_debug 'Not enough space on HDD to make new backup'
      available = false
    end

    available
  end

  def self.delete_local_files
    Backup.where(file_on_ftp: 1).each do |backup|
      backup.remove_file
    end
  end
end
