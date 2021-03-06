# -*- encoding : utf-8 -*-
# M2 Background tasks for C
class BackgroundTask < ActiveRecord::Base

  attr_protected

  belongs_to :user
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'

  def tariff_generation_validate_params(params)
    # Validation
    if params[:tariff].blank?
      self.errors.add(:something_went_wrong_try_again, _('something_went_wrong_try_again'))
    else
      # Collect data from params
      tariff = {
          name: params[:tariff][:name].to_s.strip,
          currency_id: params[:tariff][:currency_id].to_s,
          profit_margin_at_least: params[:tariff][:profit_margin_at_least].to_s.strip,
          profit_margin: params[:tariff][:profit_margin].to_s.strip,
          do_not_add_a_profit_margin_if_rate_more_than: params[:tariff][:do_not_add_a_profit_margin_if_rate_more_than].to_s.strip,
          tariff_generation_for: params[:tariff][:tariff_generation_for],
          tariffs_from: params[:tariff][:tariffs_from],
          cheapest_rate: params[:tariff][:cheapest_rate],
          date_time: "#{params[:date].to_date.to_s(:db)} #{params[:time]}:00",
          prefixes_for_generated_tariff: params[:tariff][:prefixes_for_generated_tariff].to_s,
          prefixes_for_generated_tariff_selected_tariff_id: params[:tariff][:prefixes_for_generated_tariff_selected_tariff_id].to_i,
          prefixes_for_generated_tariff_for_db: params[:tariff][:prefixes_for_generated_tariff].to_s.dup,
          tariff_generation_for_existing_tariff_id: params[:tariff][:tariff_generation_for_existing_tariff_id].to_i
      }

      if tariff[:prefixes_for_generated_tariff_for_db].to_s == 'use_prefix_from_tariff'
        tariff[:prefixes_for_generated_tariff_for_db] << ",#{tariff[:prefixes_for_generated_tariff_selected_tariff_id]}"
      end

      Tariff.tariff_name_validation(tariff[:name], self) if tariff[:tariff_generation_for].to_s == 'new_tariff'
      Tariff.tariff_profit_margin_validation(tariff[:profit_margin_at_least], self)
      Tariff.tariff_profit_margin_validation(tariff[:profit_margin], self)
      Tariff.tariff_do_not_add_profit_margin_validation(tariff[:do_not_add_a_profit_margin_if_rate_more_than], self)

      # Selected dial peers/tariffs validation
      case tariff[:tariffs_from]
        when 'dial_peer'
          if params[:dial_peer_id].blank?
            self.errors.add(:dial_peer_must_be_selected, _('dial_peer_must_be_selected')) if tariff[:selected].blank?
          else
            tariff_ids = Tariff.select('DISTINCT(tariffs.id) AS id').
                joins('JOIN devices ON devices.tp_tariff_id = tariffs.id ').
                joins("JOIN dpeer_tpoints ON (dpeer_tpoints.dial_peer_id IN (#{params[:dial_peer_id].join(', ')}) AND dpeer_tpoints.device_id = devices.id)").
                order(:id).to_a.map(&:id)
          end
          tariff[:selected] = tariff_ids || ''
        when 'tariff'
          tariff[:selected] = params[:tariff_id]
          self.errors.add(:tariff_must_be_selected, _('tariff_must_be_selected')) if tariff[:selected].blank?
        else
          self.errors.add(:dial_peer_or_tariff_must_be_selected, _('dial_peer_or_tariff_must_be_selected')) if tariff[:selected].blank?
      end
    end

    tariff
  end

  def self.generate_invoice_background(time, s_user_id, owner_id)
     BackgroundTask.create(
      task_id: 4,
      created_at: Time.now,
      owner_id: owner_id,
      status: 'WAITING',
      user_id: s_user_id.to_i,
      data1: time[:from].to_s + ' 00:00:00',
      data2: time[:till].to_s + ' 23:59:59',
      data3: Time.parse(time[:issue]).to_s
    )
  end

  def self.cdr_export_template(options = {})
    BackgroundTask.create(
        task_id: 7,
        owner_id: options[:user_id],
        user_id: options[:user_id],
        created_at: Time.zone.now,
        status: 'WAITING',
        data1: options[:template_id],
        data4: options[:from],
        data5: options[:till],
        data6: options[:sql]
    )
  end

  def self.delete_all_done
    imported_jobs = self.where(status: 'DONE').all
    imported_jobs.each { |job| job.destroy }
    imported_jobs.size
  end
end
