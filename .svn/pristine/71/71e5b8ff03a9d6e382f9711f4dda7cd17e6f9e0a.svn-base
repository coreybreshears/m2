# -*- encoding : utf-8 -*-
# Show annoying messages
class LicenseController < ApplicationController
  layout :false

  before_filter :secret_param, only: [:license]

  def license
    value = case @secret
              when '9fc25dee70d5b7810635f6680209b931d3031328'
                1
              when '219d9f5a1ec7e03a434852eb53473ab7d5edd536'
                0
            end

    Confline.set_value('unlicensed', value) if value
  end

  private

  def secret_param
    license = params[:license]
    @secret = Digest::SHA1.hexdigest(license[:psw].to_s) if license.present?
  end
end