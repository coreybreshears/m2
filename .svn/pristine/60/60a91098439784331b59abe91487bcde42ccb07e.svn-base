# -*- encoding : utf-8 -*-
# M2 Quality Routing
class QualityRoutingsController < ApplicationController
  include UniversalHelpers

  layout :determine_layout

  before_action :check_post_method, only: [:destroy, :update, :create]
  before_action :authorize, :check_localization
  before_action :access_denied, unless: -> { admin? }
  before_action :find_quality_routing, only: [:edit, :update, :destroy]
  before_action :stats_remember, only: [:stats]
  before_action :find_stats_data, only: [:stats]
  before_action :formatting_options, only: [:stats]
  before_action :check_xhr, only: [:valid_formula, :has_price]

  def list
    @qrs = QualityRouting.list
  end

  def new
    @qr = QualityRouting.new
  end

  def create
    @qr = QualityRouting.new(permitted_params)
    if @qr.save
      flash[:status] = _('Quality_Routing_created')
      redirect_to action: :list
    else
      flash_errors_for(_('Quality_Routing_not_created'), @qr)
      render layout: 'm2_admin_layout', action: :new
    end
  end

  def edit
  end

  def update
    if @qr.update_attributes(permitted_params)
      flash[:status] = _('Quality_Routing_updated')
      redirect_to action: :list
    else
      flash_errors_for(_('Quality_Routing_not_updated'), @qr)
      render layout: 'm2_admin_layout', action: :edit
    end
  end

  def destroy
    if @qr.destroy
      flash[:status] = _('Quality_Routing_deleted')
    else
      flash_errors_for(_('Quality_Routing_not_deleted'), @qr)
    end
    redirect_to action: :list
  end

  def stats
    @dp_id = @search[:dp_id]
    @qr_id = @search[:qr_id]
    @qr = QualityRouting.find_by(id: @qr_id)
    @dst = @qr.try(:formula_has_price?) ? @search[:dst].to_s.strip : ''
    render json: @dp_id && @qr_id ? make_json(QualityRouting.stats(@dp_id, @qr_id, @dst)) : [] if request.xhr?
  end

  def valid_formula
    return render text: QualityRouting.new(formula: params[:formula]).valid_attribute?(:formula)
  end

  def has_price
    qr = QualityRouting.find_by(id: params[:id])
    return render nothing: true, status: 404 unless qr.present?
    render json: {show_dst: qr.formula_has_price?, formula: qr.formula}, status: 200
  end

  private

  def formatting_options
    @fomratting = {
      time_format: Confline.get('time_format').try(:value) || '%M:%S',
      decimal_separator: Confline.get('Global_Number_Decimal').try(:value) || '.',
      decimal_num: Confline.get('Nice_Number_Digits').try(:value) || 2,
    }
  end

  def find_quality_routing
    @qr = QualityRouting.find_by(id: params[:id])
    if @qr.blank?
      flash[:notice] = _('Quality_Routing_was_not_found')
      redirect_to action: :list
    end
  end

  def permitted_params
    params.require(:quality_routing).permit(QualityRouting.writable_attrs)
  end

  def make_json(qr_stats)
    tps = []
    qr_stats.each do |tp|
      tp_obj = Device.find_by(id: tp[0])
      tp_id = tp_obj.id
      dp_tp_obj = DpeerTpoint.find_by(device_id: tp_id, dial_peer_id: @dp_id)
      exrate = Currency.count_exchange_rate(session[:default_currency], session[:show_currency])
      tps << {
        tp_id: tp_id, tp: nice_tp_name(tp_obj), total_calls: tp[1].to_i, answered_calls: tp[2].to_i,
        total_failed: tp[3].to_i, total_billsec: tp[4].to_i, asr: tp[5].to_f.round, acd: tp[6].to_f.round,
        result: tp[7], weight: dp_tp_obj.tp_weight.to_i, percent: dp_tp_obj.tp_percent.to_i,
        price: tp[8].to_d * exrate
      } if tp_obj.present?
    end
    tps.to_json
  end

  def stats_remember
    return @search = session[:qr_stats_options] = {} if params[:clear].present?

    @search = if params[:search_pressed] == 'true'
                {dp_id: params[:dp_id], qr_id: params[:qr_id], dst: params[:dst]}
              else
                session[:qr_stats_options] || {}
              end

    session[:qr_stats_options] = @search
  end

  def find_stats_data
    @dps = DialPeer.order('name ASC')
    @qrs = QualityRouting.order('name ASC')
    if @dps.blank? || @qrs.blank?
      flash[:notice] = _('Make_sure_you_have_DP_and_QR')
      redirect_to action: :list
    end
  end
end
