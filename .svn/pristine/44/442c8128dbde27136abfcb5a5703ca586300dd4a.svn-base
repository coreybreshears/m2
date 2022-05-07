class DatePicker

  def self.default_values
    {
        today: [Time.now.beginning_of_day, Time.now],
        yesterday: last_days(1),
        this_week: this_week,
        last_week: last_weeks(1),
        this_month: this_month,
        last_month: last_months(1),
        last_year: last_years(1),
        year_to_date: year_to_date
    }
  end

  def self.last_days(day_number)
    [day_number.to_i.days.ago.beginning_of_day, 1.days.ago.end_of_day]
  end

  def self.last_weeks(week_number)
    [week_number.to_i.weeks.ago.beginning_of_week, 1.weeks.ago.end_of_week]
  end

  def self.last_months(month_number)
    [month_number.to_i.months.ago.beginning_of_month, 1.month.ago.end_of_month]
  end

  def self.last_years(year_number)
    [year_number.to_i.years.ago.beginning_of_year, 1.years.ago.end_of_year]
  end

  def self.this_week
    time_now = Time.now
    [time_now.beginning_of_week, time_now.end_of_week]
  end

  def self.next_week
    time_now = Time.now
    [time_now.next_week.beginning_of_week, time_now.next_week.end_of_week]
  end

  def self.next_bi_week
    time_now = Time.now
    return [time_now + (16 - time_now.day.to_i).days, time_now.end_of_month] if time_now.day < 15
    [time_now.next_month.beginning_of_month, time_now.next_month.change(day: 16)]
  end

  def self.this_month
    time_now = Time.now
    [time_now.beginning_of_month, time_now.end_of_month]
  end

  def self.next_month
    time_now = Time.now
    [time_now.next_month.beginning_of_month, time_now.next_month.end_of_month]
  end

  def self.next_bi_month
    time_now = Time.now
    add_start_month = (time_now.month % 2 == 0) ? 1 : 2
    add_end_month = (time_now.month % 2 == 0) ? 2 : 3
    [(time_now + add_start_month.month).beginning_of_month, (time_now + add_end_month.month).end_of_month]
  end

  def self.next_quarter
    time_now = Time.now
    [time_now.next_quarter.beginning_of_quarter, time_now.next_quarter.end_of_quarter]
  end

  def self.next_half_year
    time_now = Time.now
    return [time_now.change(month: 6).beginning_of_month, time_now.end_of_year] if time_now.month <= 5
    [time_now.next_year.beginning_of_year, time_now.next_year.change(month: 5).end_of_month]
  end

  def self.year_to_date
    time_now = Time.now
    [time_now.beginning_of_year, time_now]
  end
end
