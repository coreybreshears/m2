# Tariff Import v2 Templates
module TariffTemplatesHelper
  def tariff_template_columns_selection(include_blank = false)
    options = %w[A B C D E F G H I J K L M N O P Q R S T U V X Y W Z]
    include_blank ? options.unshift(' ') : options
  end

  def tariff_template_field_selection
    %w[\  1 2 3]
  end

  def tariff_template_rate_sheet_selection(include_blank = false)
    options = (1..9).to_a
    include_blank ? options.unshift(' ') : options
  end

  def tariff_template_effective_date_format_selection
    [
      [' ', ''],
      ['DD-MMM-YYYY (20-Jan-2019)', '%d-%b-%Y', {class: 'dropdown_selection_word_spacing'}],
      ['DD.MM.YY (20.02.19)', '%d.%m.%y', {class: 'dropdown_selection_word_spacing'}],

      ['YYYY-MM-DD (2019-02-20)', '%Y-%m-%d', {class: 'dropdown_selection_word_spacing'}],
      ['YYYY/MM/DD (2019/02/20)', '%Y/%m/%d', {class: 'dropdown_selection_word_spacing'}],
      ['YYYY,MM,DD (2019,02,20)', '%Y,%m,%d', {class: 'dropdown_selection_word_spacing'}],
      ['YYYY.MM.DD (2019.02.20)', '%Y.%m.%d', {class: 'dropdown_selection_word_spacing'}],

      ['DD-MM-YYYY (20-02-2019)', '%d-%m-%Y', {class: 'dropdown_selection_word_spacing'}],
      ['DD/MM/YYYY (20/02/2019)', '%d/%m/%Y', {class: 'dropdown_selection_word_spacing'}],
      ['DD,MM,YYYY (20,02,2019)', '%d,%m,%Y', {class: 'dropdown_selection_word_spacing'}],
      ['DD.MM.YYYY (20.02.2019)', '%d.%m.%Y', {class: 'dropdown_selection_word_spacing'}],

      ['MM-DD-YYYY (02-20-2019)', '%m-%d-%Y', {class: 'dropdown_selection_word_spacing'}],
      ['MM/DD/YYYY (02/20/2019)', '%m/%d/%Y', {class: 'dropdown_selection_word_spacing'}],
      ['MM,DD,YYYY (02,20,2019)', '%m,%d,%Y', {class: 'dropdown_selection_word_spacing'}],
      ['MM.DD.YYYY (02.20.2019)', '%m.%d.%Y', {class: 'dropdown_selection_word_spacing'}],

      [_('Custom'), 'custom']
    ]
  end

  def tariff_templates_additional_interval_options_selected?(tariff_template)
    [
        tariff_template.second_interval_rate_column,
        tariff_template.second_interval_mintime_column,
        tariff_template.second_interval_increment_column,
        tariff_template.off_peak_first_interval_rate_column,
        tariff_template.off_peak_first_interval_mintime_column,
        tariff_template.off_peak_first_interval_increment_column,
        tariff_template.off_peak_second_interval_rate_column,
        tariff_template.off_peak_second_interval_mintime_column,
        tariff_template.off_peak_second_interval_increment_column
    ].uniq.any?(&:present?)
  end

  def tariff_template_exceptions_type_selection
    # Currently hidden
    # [
    #   [_('Second_Interval_Rate'), 'second_interval_rate_change'],
    #   [_('Second_Interval_Increment'), 'second_interval_increment_change'],
    #   [_('Second_Interval_Mintime'), 'second_interval_mintime_change'],
    #   [_('Off_Peak_First_Interval_Rate'), 'off_peak_first_interval_rate_change'],
    #   [_('Off_Peak_First_Interval_Increment'), 'off_peak_first_interval_increment_change'],
    #   [_('Off_Peak_First_Interval_Mintime'), 'off_peak_first_interval_mintime_change'],
    #   [_('Off_Peak_Second_Interval_Rate'), 'off_peak_second_interval_rate_change'],
    #   [_('Off_Peak_Second_Interval_Increment'), 'off_peak_second_interval_increment_change'],
    #   [_('Off_Peak_Second_Interval_Mintime'), 'off_peak_second_interval_mintime_change']
    # ]

    # Currently renamed to be without First Interval Suffix
    # [
    #   [_('Connection_Fee'), 'connection_fee_change'],
    #   [_('First_Interval_Rate'), 'first_interval_rate_change'],
    #   [_('First_Interval_Increment'), 'first_interval_increment_change'],
    #   [_('First_Interval_Mintime'), 'first_interval_mintime_change']
    # ]
    [
      [_('Connection_Fee'), 'connection_fee_change'],
      [_('Rate'), 'first_interval_rate_change'],
      [_('Increment'), 'first_interval_increment_change'],
      [_('Mintime'), 'first_interval_mintime_change']
    ]
  end
end
