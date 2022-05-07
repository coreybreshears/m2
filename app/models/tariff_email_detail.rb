# Tariff Import v2 Tariff Email Details
class TariffEmailDetail < ActiveRecord::Base
  attr_protected

  belongs_to :email

  def self.new_by_params(params)
    email_detail = self.new
    email_detail.update_by_params(params)
  end

  def update_by_params(params)
    columns_hash = TariffEmailDetail.columns_hash.except('id', 'email_id')
    columns_hash.each_value do |attribute|
    self[attribute.name] = if attribute.type == :string
                             params[attribute.name].to_s
                           elsif attribute.type == :boolean
                             params.include?(attribute.name) ? 1 : 0
                           end
  	end
    self
  end
end
