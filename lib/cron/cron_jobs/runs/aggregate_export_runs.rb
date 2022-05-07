
  class AggregateExportRuns
    ATTRIBUTES = %i[agg_export next_run_at from till completed montrose_response]
    attr_accessor *ATTRIBUTES
    def initialize(agg_export)
      @agg_export = agg_export
      @from = agg_export.from
      @till = agg_export.till
      @next_run_at = Time.now
      @completed = 1
    end

    def set_run_at
      case @agg_export.recurrence_type.to_i
        when 1
          set_run_at_daily
        when 2
          set_run_at_weekly
        when 3
          set_run_at_monthly
        when 4
          set_run_at_yearly
        when 5
          set_run_at_horly
      end
      save_agg_export
    end

    private

    def save_agg_export
      @agg_export.next_run_at = @next_run_at
      @agg_export.completed = @completed
      @agg_export.save
    end

    def set_run_at_daily
      run_at_by_frequency_type(
        second: (Montrose.daily(on: [:monday, :tuesday, :wednesday, :thursday, :friday], starts: set_starts)),
        first: (Montrose.daily(interval: @agg_export.frequency, starts: set_starts))
      )
    end

    def set_run_at_weekly
      set_next_run_by_montrose_response(Montrose.weekly(interval: @agg_export.frequency, on: [day_of_week_to_sym], starts: set_starts))
    end

    def set_run_at_monthly
      run_at_by_frequency_type(
        first: (Montrose.monthly(interval: @agg_export.month, mday:[@agg_export.day], starts: set_starts)),
        second: (Montrose.every(:month, day: { day_of_week_to_sym => [@agg_export.day] }, interval: @agg_export.month, starts: set_starts))
      )
    end

    def set_run_at_yearly
      case @agg_export.frequency_type
        when 31
          set_next_run_by_montrose_response(Montrose.yearly(month: @agg_export.month, interval: @agg_export.frequency, starts: set_starts)) do |resp|
            get_day_of_month(resp)
            @montrose_response = resp.change(day: @agg_export.day)
          end
        when 32
          planned_time = yearly_second_type_algorithm(set_starts.to_date)
          set_next_run_at(planned_time.to_time) if planned_time < @till
      end
    end

    def set_run_at_horly
      set_next_run_by_montrose_response(Montrose.hourly(interval: @agg_export.frequency,  starts: set_starts))
    end

    def yearly_second_type_algorithm(today)
      month = @agg_export.month - 1
      from = today.beginning_of_year + month.months
      till = today.beginning_of_year + (month + 1).months

      if @agg_export.day_of_week == 7
        week_day = [0]
      else
        week_day = [@agg_export.day_of_week]
      end

      days = (from...till).to_a.select {|k| week_day.include?(k.wday)}

      day_of_week_of_month = @agg_export.day - 1
      while days[day_of_week_of_month].blank?
        day_of_week_of_month -= 1
      end
      @agg_export.day = day_of_week_of_month + 1

      days[day_of_week_of_month] < (Time.now + 2.days) ? yearly_second_type_algorithm(today + @agg_export.frequency.to_i.years) : days[day_of_week_of_month]
    end

    def set_starts
      return @from > Time.now ? @from : Time.now
    end

    def run_at_by_frequency_type(options = {})
      frequency_shift = ((@agg_export.recurrence_type.to_i - 1) * 10)
      case @agg_export.frequency_type.to_i
        when (1 + frequency_shift)
          set_next_run_by_montrose_response(options[:first])
        when (2 + frequency_shift)
          set_next_run_by_montrose_response(options[:second])
      end
    end

    def set_next_run_by_montrose_response(response, index = 0)
      @montrose_response = response.until(@till).take(index + 1)[index]
      if @montrose_response.present?
        yield @montrose_response if block_given?
        if @montrose_response.to_time > set_starts.end_of_day && !hourly_type?
          set_next_run_at(@montrose_response.to_time)
        elsif @montrose_response.to_time > set_starts.end_of_hour && hourly_type?
          set_next_run_at(@montrose_response.to_time)
        else
          set_next_run_by_montrose_response(response, index + 1)
        end
      end
    end

    def day_of_week_to_sym
      if @agg_export.day_of_week == 7
        Date::DAYNAMES[0].downcase.to_sym
      else
        Date::DAYNAMES[@agg_export.day_of_week].downcase.to_sym
      end
    end

    def get_day_of_month(date)
     return unless date.end_of_month.day < @agg_export.day
     @agg_export.day = date.end_of_month.day
    end

    def set_next_run_at(time)
      time = time.change(correct_time) unless hourly_type?
      @next_run_at = time.change(min: 0, sec: 0)
      @completed = 0
    end

    def correct_time
      {
        hour: agg_export.email_send_time.to_i,
      }
    end

    def hourly_type?
      @agg_export.recurrence_type.to_i == 5
    end
  end
