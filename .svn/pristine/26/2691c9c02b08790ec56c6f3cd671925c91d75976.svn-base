# Dids controller
class DidsController < ApplicationController
	layout :determine_layout

  before_action :authorize
  before_action :check_localization
  before_filter :dids_enabled?

  def dids
    redirect_to(action: :inventory) && (return false)
  end

	def inventory
	end

  def buying_pricing_groups
  end

  def selling_pricing_groups
  end

  def tags
    @tags = DidTag.get_tags
  end
end
