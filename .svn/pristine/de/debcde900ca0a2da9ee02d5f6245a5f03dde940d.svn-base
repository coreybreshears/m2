# Templates for Tariff Rate Notification
class TariffRateNotificationTemplatesController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || manager?) }
  before_filter :authorize
  before_filter :check_post_method, only: [:create, :update, :destroy]
  before_filter :find_rate_notification_template, only: [:edit, :update, :destroy, :download_current_xlsx_template]
  before_filter :save_xlsx_template_file, only: [:update]

  def list
    @rate_notification_templates = RateNotificationTemplate.list_all
  end

  def new
    @rate_notification_template = RateNotificationTemplate.new(
        header_rows: 6,
        client_row: '2', client_column: 'C',
        currency_row: '3', currency_column: 'C',
        timezone_row: '4', timezone_column: 'C',
        destination_group_column: 'B',
        destination_column: 'C',
        prefix_column: 'D',
        rate_column: 'E',
        effective_from_column: 'F',
        rate_difference_raw_column: 'G',
        rate_difference_percentage_column: 'H',
        increment_column: 'I',
        minimal_time_column: 'J'
    )
  end

  def create
    @rate_notification_template = RateNotificationTemplate.new(params[:rate_notification_template])

    if @rate_notification_template.save
      save_xlsx_template_file
      flash[:status] = _('Rate_Notification_Template_successfully_created')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Rate_Notification_Template_was_not_created'), @rate_notification_template)
      render :new
    end
  end

  def edit
  end

  def update
    if @rate_notification_template.update_attributes(params[:rate_notification_template])
      flash[:status] = _('Rate_Notification_Template_successfully_updated')
      redirect_to(action: :list)
    else
      flash_errors_for(_('Rate_Notification_Template_was_not_updated'), @rate_notification_template)
      render :edit
    end
  end

  def destroy
    if @rate_notification_template.destroy
      flash[:status] = _('Rate_Notification_Template_successfully_deleted')
    else
      flash_errors_for(_('Rate_Notification_Template_was_not_deleted'), @rate_notification_template)
    end
    redirect_to(action: :list)
  end

  def download_current_xlsx_template
    file_path = @rate_notification_template.xlsx_file_path

    if file_path
      file_xlsx = File.open(file_path).read
      send_data(file_xlsx, filename: 'rate_notification_template.xlsx', type: 'application/octet-stream')
      cookies['fileDownload'] = 'true'
    else
      flash[:notice] = _('File_was_not_found')
      redirect_to(action: :list) && (return false)
    end
  end

  private

  def find_rate_notification_template
    @rate_notification_template = RateNotificationTemplate.where(id: params[:id]).first
    return if @rate_notification_template
    flash[:notice] = _('Rate_Notification_Template_was_not_found')
    redirect_to(action: :list) && (return false)
  end

  def save_xlsx_template_file
    file = params[:xlsx_template_file]

    (return false) if @rate_notification_template.is_default? || file.blank? || !file.is_a?(ActionDispatch::Http::UploadedFile)

    if file.size <= 0
      flash[:warning] = "#{_('XLSX_Template_File_was_not_uploaded')}<br/> * #{_('Zero_file_size')}"
      return false
    end

    if file.size > 104857600 # 100 MegaBytes
      flash[:warning] = "#{_('XLSX_Template_File_was_not_uploaded')}<br/> * #{_('File_size_is_too_big')}"
      return false
    end

    unless %w[xlsx].include?(sanitize_filename(file.original_filename).split('.').last.downcase)
      flash[:warning] = "#{_('XLSX_Template_File_was_not_uploaded')}<br/> * #{_('Invalid_File_Type')}"
      return false
    end

    @rate_notification_template.delete_xlsx_template_file
    file_full_path = @rate_notification_template.xlsx_template_file_path
    begin
      File.open(file_full_path, 'wb') { |xlsx_file| xlsx_file.write(file.read) }
    rescue => error
      MorLog.my_debug("TariffRateNotificationTemplatesController::save_xlsx_template_file error => #{error}", true)
    end

    if File.exist?(file_full_path)
      flash[:warning] = _('XLSX_Template_File_successfully_uploaded')
    else
      flash[:warning] = "#{_('XLSX_Template_File_was_not_uploaded')}<br/> * #{_('File_received_but_could_not_be_saved_to_File_System')}"
    end
  end
end
