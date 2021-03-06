require 'json'
# Tariff Import v2 Tariff Inbox
class TariffInboxController < ApplicationController
  layout :determine_layout

  before_filter :access_denied, if: -> { !(admin? || (manager? && tariff_import_active?)) }, except: [:map_attachments, :move_to_completed]
  before_filter :authorize, except: [:map_attachments, :move_to_completed]
  before_filter :check_before_delete, only: [:delete_emails]
  before_filter :set_inbox_options, only: [:inbox]
  before_filter :check_email, only: [:delete_email, :show_source, :retry_rules_mapping]
  before_filter :check_post_method, only: [:retry_rules_mapping, :assign_import_settings]
  before_filter :find_attachment, only: [:assign_import_settings]

  def inbox
    @emails = TariffEmail.data_for_list(@options)
    @options[:inbox_pagintaion] = TariffEmail.pagination(@options[:inbox_page], @emails[:inbox].count, session)
    @options[:completed_pagintaion] = TariffEmail.pagination(@options[:completed_page], @emails[:completed].count, session)
    @options[:junk_pagintaion] = TariffEmail.pagination(@options[:junk_page], @emails[:junk].count, session)
  end

  def delete_email
    message = if @email.folder == 'junk'
                      _('Email_was_successfully_deleted')
                     else
                      _('Email_was_successfully_moved_to_junk')
                     end
    @email.delete_email
    flash[:status] = message
    redirect_to(action: :inbox) && (return false)
  end

  def delete_emails
    email_ids = JSON.parse(params[:selected_emails]).map(&:to_i)
    if params[:delete_type] == 'junk'
      TariffEmail.bulk_move_to_junk(email_ids)
      flash[:status] = _('Emails_were_successfully_moved_to_junk')
    else
      TariffEmail.bulk_delete(email_ids)
      flash[:status] = _('Emails_were_successfully_deleted')
    end
    redirect_to(action: :inbox) && (return false)
  end

  def download_attachment
    attachment = TariffAttachment.where(id: params[:attachment_id]).first
    if attachment.present?
      send_data attachment.data, disposition: 'attachment', type: 'application/zip', filename: "#{attachment.file_full_name}.rar"
    else
      flash[:notice] = _('Attachment_was_not_found')
      redirect_to(action: :inbox) && (return false)
    end
  end

  def show_source
    @email
  end

  def map_attachments
    return render nothing: true, status: 403 unless request.local?
    TariffAttachment.map_attachments
    render nothing: true, status: 200
  end

  def move_to_completed
    return render nothing: true, status: 403 unless request.local?
    TariffEmail.move_to_completed
    render nothing: true, status: 200
  end

  def retry_rules_mapping
    TariffAttachment.remap_attachments(@email.id)
    flash[:status] = _('Import_Rules_for_selected_email_were_successfully_remapped')
    redirect_to(action: :inbox) && (return false)
  end

  def assign_import_settings
    @attachment.assign_import_setting(params["assign_tariff_import_rule_#{@attachment.id}".to_sym])

    if @attachment.tariff_jobs.present?
      flash[:status] = _('Tariff_Job_was_successfully_created')
    else
      flash[:notice] = _('Tariff_Job_was_not_created')
    end
    redirect_to(action: :inbox) && (return false)
  end

  private

  def check_email
    @email = TariffEmail.where(id: params[:email_id]).first
    if @email.blank?
      flash[:notice] = _('Email_was_not_found')
      redirect_to(action: :inbox) && (return false)
    end
  end

  def find_attachment
    @attachment = TariffAttachment.where(id: params[:attachment_id]).first
    if @attachment.blank?
      flash[:notice] = _('Attachment_was_not_found')
      redirect_to(action: :inbox) && (return false)
    end
  end

  def check_before_delete
    if params[:selected_emails].blank? || params[:selected_emails] == '[]'
      flash[:notice] = _('No_Emails_were_selected')
      redirect_to(action: :inbox) && (return false)
    end
  end

  def set_inbox_options
    clear = params[:clear]
    params[:search].each { |key, _| params[:search][key] = '' } if clear.present?
    @options = {}
    @options[:inbox] = params[:search]

    %w[inbox completed junk].each do |type|
      session["#{type}_page".to_sym] = params[:page] if params[:type] == type
      @options["#{type}_page".to_sym] = { page: session["#{type}_page"] || 1 }
    end
  end
end
