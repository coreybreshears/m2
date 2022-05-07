# -*- encoding : utf-8 -*-
# Aggregates page Helper
module AggregateExportHelper
  def options_for_rec_type(default_state)
    options_for_select([[_('Hourly'), 5], [_('Daily'), 1], [_('Weekly'), 2], [_('Monthly'), 3], [_('Yearly'), 4]], default_state)
  end

  def options_for_day_of_week(default_state)
  	options_for_select([[_('Monday'), 1], [_('Tuesday'), 2], [_('Wednesday'), 3], [_('Thursday'), 4], [_('Friday'), 5], [_('Saturday'), 6], [_('Sunday'), 7]], default_state)
  end

  def options_for_days(default_state)
  	options_for_select([[_('First'), 1], [_('Second'), 2], [_('Third'), 3], [_('Fourth'), 4], [_('Fifth'), 5]], default_state)
  end

  def options_for_months(default_state)
  	options_for_select([[_('January'), 1], [_('February'), 2], [_('March'), 3], [_('April'), 4], [_('May'), 5], [_('June'), 6], [_('July'), 7], [_('August'), 8], [_('September'), 9], [_('October'), 10], [_('November'), 11], [_('December'), 12]], default_state)
  end

  def options_for_agg_period(default_state)
    options_for_select([[_('Hours'), 1], [_('Days'), 2], [_('Months'), 3]], default_state)
  end

  def options_for_hours(default_state)
    options_for_select((0..23).map{|day| [day, day]}, default_state)
  end

  def options_for_minute(default_state)
    options_for_select((0..23).map{|day| ['%02d' % day, day]}, default_state)
  end
end