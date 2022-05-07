# -*- encoding : utf-8 -*-
# Currencies managing.
class CurrenciesController < ApplicationController
  layout :determine_layout
  before_filter :check_post_method, only: [:destroy, :create, :update]
  before_filter :check_localization, except: [:calculate]
  before_filter :authorize, except: [:calculate]
  before_filter :find_currecy, only: [:currencies_change_update_status, :currencies_change_status,
                                      :currencies_change_default, :edit, :update, :destroy]

  def calculate
    @without_tax = (params[:curr1].to_s == params[:curr2].to_s) ? round_to_cents(params[:amount].to_d) :
        exchange(params[:amount], params[:curr1], params[:curr2]).to_d
    @without_tax = params[:min_amount].to_d if params[:min_amount].present? &&
        @without_tax.to_d < params[:min_amount].to_d
    @without_tax = params[:max_amount].to_d if params[:max_amount].present? && !params[:max_amount].to_d.zero? &&
        @without_tax.to_d > params[:max_amount].to_d
    @tax_in_amount = params[:tax_in_amount].to_s
    if @tax_in_amount == 'excluded'
      @with_tax = ActiveProcessor.configuration.substract_tax.call(params[:user].to_i, @without_tax.to_d)
      @with_tax, @without_tax = @without_tax, @with_tax
    else
      @with_tax = ActiveProcessor.configuration.calculate_tax.call(params[:user].to_i, @without_tax.to_d)
    end

    result =
    {
      without_tax: round_to_cents(@without_tax.to_d),
      with_tax: round_to_cents(@with_tax.to_d)
    }

    respond_to do |format|
      format.json {
        render json: result.to_json
      }
    end
  end

  def currencies
    @page_title = _('Currencies')
    @page_icon = 'money_dollar.png'
    @currs = Currency.order('name ASC')
  end

  def currencies_change_update_status
    @currency.curr_update = (@currency.curr_update == 1) ? 0 : 1
    if @currency.save
      flash[:status] = (@currency.curr_update == 1) ? _('Currency_update_enabled') : _('Currency_update_disabled')
    else
      flash_errors_for(_('Currency_not_updated'), @currency)
    end
    redirect_to action: :currencies
  end

  def currencies_change_status
    @currency.active = (@currency.active == 1) ? 0 : 1

    if @currency.save
      flash[:status] = (@currency.active == 1) ? _('Currency_enabled') : _('Currency_disabled')
    else
      flash_errors_for(_('Currency_not_updated'), @currency)
    end
    redirect_to action: :currencies
  end

  def change_default
    @page_title = _('Default_currency')
    @page_icon = 'money_dollar.png'
    @currs = Currency.all
  end

  def currencies_change_default
    curr = @currency.set_default_currency
    if curr
      session[:default_currency] = curr
      flash[:status] = _('Currencies_rates_updated')
    else
      flash[:notice] = _('Error_Please_Try_Again_Later')
    end
    redirect_to action: :change_default
  end

  def update_currencies_rates
    updated = true
    if params[:all].to_i == 1
      begin
        Currency.transaction do
          updated = Currency.update_currency_rates
        end
      rescue
        updated = false
      end
    else
      currency = Currency.where(id: params[:id]).first
      unless currency
        flash[:notice] = _('Currency_was_not_found')
        redirect_back_or_default('/currencies/currencies')
      end

      updated = currency.update_rate
    end

    if updated
      flash[:status] = (params[:all].to_i == 1) ? _('Currencies_rates_updated') :
          _('Currency_exchange_rate_successfully_updated')
    else
      # In this block 'updated' is either nil or false
      flash[:notice] = (updated == false) ? _('Error_Please_Try_Again_Later') :
          _('Currency_not_updated_not_authenticated_server')
    end
    redirect_to(action: :currencies)
  end

  def edit
    @page_title = _('Currency_edit')
    @page_icon = 'edit.png'
  end

  def update
    @currency.full_name = params[:full_name]
    if params[:exchange_rate].to_d > 0.to_d
      @currency.assign_attributes(
        exchange_rate: (@currency.id == 1) ? 1 : params[:exchange_rate].to_d,
        last_update: Time.now
      )
    else
      @currency.assign_attributes(
        active: 0,
        last_update: Time.now
      )
    end
    if @currency.save
      flash[:status] = _('Currency_details_updated')
    else
      flash_errors_for(_('Currency_details_not_updated'), @currency)
    end
    redirect_to action: :currencies
  end

  def destroy
    total_tariffs = @currency.tariffs.size

    if (@currency.id != 1) && (total_tariffs == 0) && (@currency.curr_edit != 1) # AND check if some tariff etc uses this currency
      session[:show_currency] = session[:default_currency] if session[:show_currency] == @currency.name
      @currency.destroy
      flash[:status] = _('Currency_deleted')
    else
      flash[:notice] = _('Cant_delete_this_currency_some_tariffs_are_using_it') if total_tariffs != 0
    end
    redirect_to action: :currencies

  end

  private

  def exchange(amount, curr_from, curr_to)
    amount = amount.to_d * ActiveProcessor.configuration.currency_exchange.call(curr_from, curr_to) if defined? ActiveProcessor.configuration.currency_exchange
    round_to_cents(amount)
  end

  def round_to_cents(amount)
    sprintf('%.2f', amount)
  end

  def find_currecy
    @currency = Currency.where(['id=?', params[:id]]).first
    unless @currency
      flash[:notice] = _('Currency_was_not_found')
      redirect_back_or_default('/currencies/currencies') && (return false)
    end
  end
end
