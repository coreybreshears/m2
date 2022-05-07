class InvoiceJob < JobInterface
  ATTRIBUTES = %i[run_at dynamic_days user period user_id dynamic_hours]
  attr_accessor *ATTRIBUTES

  def initialize(options = {})
    @run_at = options[:run_at]
    @dynamic_days = options[:days].to_i
    @dynamic_hours = options[:dynamic_hours].to_i
    # for billing periods, from user settings
    @user = options[:user]
    @user_id = user.id
    # ----
    @period = set_period
  end

  def do_job
    MorLog.my_debug("---- Generate Invoice for User: #{user_id}")
    MorLog.my_debug("Invoice Time: ")
    MorLog.my_debug(inv_options)
    if EsQuickStatsTechnicalInfo.get_data_for_invoice(inv_options)
      BackgroundTask.generate_invoice_background(format_date_for_invoice(inv_options), user_id, 0)
      system('/usr/local/m2/m2_invoices generate &')
      Action.add_action_hash(0, action: 'InvoiceJob_run_successful', data: 'InvoiceJob successful generate Invoice', target_id: user_id, target_type: 'User')
    else
      Action.add_error(user_id, 'Invoice was not generated', {data2: 'Inconsistent data between ES and MySQL', data3: 'Please contact support'})
    end
    MorLog.my_debug('Invoice Job completed', 1)
  rescue => err
    Action.add_action_hash(0, action: 'error', data: 'InvoiceJob dont run', data4: err.message.to_s + ' ' + err.class.to_s, target_id: user_id, target_type: 'User')
  end

  def next_run_at
    case period.to_s
      when 'dynamic'
        tmp_run_at = Date.today.to_time + dynamic_days.days
        tmp_run_at = tmp_run_at.change(hour: @dynamic_hours)
        user.billing_run_at = tmp_run_at
      when 'bimonthly'
        user.billing_run_at = run_at.to_s.to_time + 2.months
      when 'quarterly'
        user.billing_run_at = run_at.to_s.to_time + 3.months
      when 'halfyearly'
        user.billing_run_at = run_at.to_s.to_time + 6.months
    end
    user.save
  end

  def self.set_run_at(options = {})
    case options[:billing_period]
      when 'dynamic'
        dynamic_days = options[:billing_dynamic_days].to_i
        billing_dynamic_from = options[:billing_dynamic_from].to_s.to_time
        dynamic_hour = options[:dynamic_hour]
        run_at = billing_dynamic_from + 1.day + dynamic_days.days
        run_at = Date.today.to_time + 1.day if run_at < Date.today
        run_at = run_at.change(hour: dynamic_hour)
        run_at
      when 'bimonthly', 'quarterly', 'halfyearly'
        DateTime.now.beginning_of_month + 1.month + 1.day
    end
  end

  private

  def inv_options
    method("date_by_#{period}_period").call
  end

  def date_by_dynamic_period
    datetime_now = DateTime.now.at_beginning_of_day + (@dynamic_hours == 24 ? -1.day : 0.day)
    {
        from: datetime_now - dynamic_days.days,
        till: datetime_now - 1.second
    }
  end

  def date_by_bimonthly_period
    datetime_now = DateTime.now
    {
        from: (datetime_now - 2.month).beginning_of_month,
        till: (datetime_now - 1.month).end_of_month
    }
  end

  def date_by_quarterly_period
    datetime_now = DateTime.now
    {
        from: (datetime_now - 3.month).beginning_of_month,
        till: (datetime_now - 1.month).end_of_month
    }
  end

  def date_by_halfyearly_period
    datetime_now = DateTime.now
    {
        from: (datetime_now - 6.month).beginning_of_month,
        till: (datetime_now - 1.month).end_of_month
    }
  end

  def format_date_for_invoice(options = {})
    options.each do |name, time|
      options[name] = time.strftime('%Y-%m-%d')
    end
    options[:issue] = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    options
  end

  def set_period
    user.billing_period
  end
end