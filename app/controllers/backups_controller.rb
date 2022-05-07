# -*- encoding : utf-8 -*-
# Backup managing controller.
class BackupsController < ApplicationController
  layout :determine_layout
  before_filter :check_localization
  before_filter :authorize

  def index
    redirect_to action: 'backup_manager'
  end

  def list
    redirect_to action: 'backup_manager'
  end

  def backup_manager
    @page_title = _('Backup_manager')
    @page_icon = 'database_save.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Backup_system'
    @backups = Backup.order('backuptime ASC').all
  end

  def backup_new
    @page_title = _('Backup_new')
    @page_icon = 'add.png'
    @help_link = 'http://wiki.ocean-tel.uk/index.php/Backup_system'
    @back = Backup.new
  end

  def backup_destroy
    backup = Backup.where(id: params[:id]).first

    unless backup
      flash[:notice] = _('Backup_was_not_found')
      redirect_to(action: :backup_manager) && (return false)
    end

    if backup.destroy_all
      flash[:status] = _('Backup_deleted')
    else
      flash[:notice] = _('Backup_was_not_deleted')
    end
    flash[:status] = _('Backup_deleted')
    redirect_to action: 'backup_manager'
  end

  def backup_download
    path = Confline.get_value('Backup_Folder')
    backup = Backup.where(id: params[:id]).first

    unless backup
      flash[:notice] = _('Backup_was_not_found')
      redirect_to(action: :backup_manager) && (return false)
    end

    unless prepare_file(backup)
      flash[:notice] = _('Backup_file_is_missing')
      redirect_to(action: :backup_manager) && (return false)
    end

    fname = ''
    fpath = ''
    # Legacy download requires tar.gz format
    %w[tar.gz bz2].each do |ext|
      fname = "db_dump_#{backup.backuptime}.sql.#{ext}"
      fpath = "#{path}/#{fname}"
      break if File.exist?(fpath)
    end

    begin
      send_file fpath, filename: fname, x_sendfile: true, stream: true
    rescue
      flash[:notice] = _('Backup_file_is_missing')
      redirect_to(action: :backup_manager) && (return false)
    end
  end

  def backup_create
    res = Backup.private_backup_create(session[:user_id], 'manual', params[:comment])
    if res > 0
      my_debug('Manual backup failed')

      backup = Backup.new

      errors = [
        [:other, backup_error],
        [:space, _('not_enough_disk_space')]
      ]

      backup.errors.add(*errors[res.pred])

      flash_errors_for(_('Backup_not_created'), backup)
    else
      my_debug('Manual backup created')
      flash[:status] = _('Backup_created')
    end

    redirect_to action: 'backup_manager'
  end

  def backup_restore
    backup = Backup.where(id: params[:id]).first

    unless backup
      flash[:notice] = _('Backup_was_not_found')
      redirect_to(action: :backup_manager) && (return false)
    end

    unless prepare_file(backup)
      flash[:notice] = _('Backup_file_is_missing')
      redirect_to(action: :backup_manager) && (return false)
    end

    res = private_backup_restore(backup)
    MorLog.my_debug(res)

    if res.to_i == 1
      my_debug('Backup restore failed')
      flash[:notice] = _('Backup_was_not_found')
    else
      my_debug('Backup restored')
      flash[:status] = _('Backup_restored')
    end
    Backup.delete_local_files

    redirect_to action: 'backup_manager'
  end

  def backups_hourly_cronjob
    Backup.backups_hourly_cronjob(session[:user_id])
    Backup.delete_local_files
    render nothing: true
  end

  private

  def private_backup_restore(backup)
    backup = Backup.find(backup) unless backup.class == Backup
    backup_folder = Confline.get_value('Backup_Folder')

    # script=[]
    command = "/usr/local/m2/backups/backup_restore.sh #{backup.backuptime} #{backup_folder} -c"
    script = %x(#{command})
    # my_debug("response : " + script[0].split(" ").last.last.to_s )

    return_code = script.to_s.scan(/\d+/).last.to_i # script.to_s.scan(/\d+/).to_s.to_i

    Action.add_action_second(session[:user_id].to_i, 'backup_restored', backup.id, return_code)
    return_code
  end

  def backup_error
    if File.exists?('/var/log/m2/db_backup.log')
      file = File.open('/var/log/m2/db_backup.log', 'rb')
      error = file.read.split("\n")
      total_numbers = error.size
      error[(total_numbers - 1).to_i].to_s
    else
      ''
    end
  end

  def prepare_file(backup)
    return true if backup.file_on_ftp == 0 || File.exist?(backup.get_file_name)
    Backup.delete_local_files
    return backup.download_from_ftp
  end
end
