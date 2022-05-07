# Callc Helper
module CallcHelper
  def find_user(value)
    user = User.find(value)
  end

  def request_maches
    request.env['HTTP_USER_AGENT'] && (request.env['HTTP_USER_AGENT'].match('iPhone') || request.env['HTTP_USER_AGENT'].match('iPod'))
  end

  def date_for_last_calls(mode)
    time = Time.now
    time = Time.now - 24.hours if mode == 'from_24hours'
    time = Time.now - 14.days if mode == 'from_14days'
    time = Time.now - 6.months if mode == 'from_6months'

    time_h = {
      year: time.year,
      month: time.month,
      day: time.day,
      hour: time.hour,
      min: time.min
    }

    case mode
    when 'month_from'
      {year: time_h[:year], month: time_h[:month], day: '1', hour: '00', minute: '00'}
    when 'month_till'
      {year: time_h[:year], month: time_h[:month], day: time.end_of_month.day, hour: '23', minute: '59'}
    when 'day_from'
      {year: time_h[:year], month: time_h[:month], day: time_h[:day], hour: '00', minute: '00'}
    when 'day_till'
      {year: time_h[:year], month: time_h[:month], day: time_h[:day], hour: '23', minute: '59'}
    when 'from_24hours'
      time_h
    when 'till_24hours'
      time_h
    when 'from_14days'
      time_h
    when 'till_14days'
      time_h
    when 'from_6months'
      time_h
    when 'till_6months'
      time_h
    end
  end

  def hide_active_calls_longer_than
    hide_active_calls_longer_than = Confline.get_value('Hide_active_calls_longer_than', 0).to_i
    hide_active_calls_longer_than = 24 if hide_active_calls_longer_than.zero?
    hide_active_calls_longer_than
  end

  def payments_to_confirm
    M2Payment.where(approved: 1).all.size.to_i
  end
end
