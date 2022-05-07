# -*- encoding : utf-8 -*-
# Aggregates page Helper
module AggregatesHelper
  def mapped_destination_groups(destinationgroups)
    [[_('Any'), 0]] + destinationgroups.map { |dg| [dg.name, dg.id] }
  end

  def options_for_search_template(default_state)
    options_for_select([[_('None'), -1]] + AggregateTemplate.where(user_id: current_user.id).map { |temp| [temp.name, temp.id] }, default_state)
  end
end