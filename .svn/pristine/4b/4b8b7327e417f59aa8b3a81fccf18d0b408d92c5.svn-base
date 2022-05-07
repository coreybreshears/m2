# Address
class Address < ActiveRecord::Base
  belongs_to :direction
  has_one :user

  attr_protected

  def self.assign_imported_address(r_arr, session)
    address = Address.new
    address.direction_id = Direction.get_direction_by_country(address.clean_value_all(r_arr[session[:imp_user_country]]))
    address.state = address.clean_value_all r_arr[session[:imp_user_state]] if session[:imp_user_state] >= 0
    address.county = address.clean_value_all r_arr[session[:imp_user_country]]
    address.city = address.clean_value_all r_arr[session[:imp_user_city]] if session[:imp_user_city] >= 0
    address.postcode = address.clean_value_all r_arr[session[:imp_user_postcode]] if session[:imp_user_postcode] >= 0
    address.address = address.clean_value_all r_arr[session[:imp_user_address]] if session[:imp_user_address] >= 0
    address.phone = address.clean_value_all r_arr[session[:imp_user_phone]] if session[:imp_user_phone] >= 0
    address.mob_phone = address.clean_value_all r_arr[session[:imp_user_mob_phone]] if session[:imp_user_mob_phone] >= 0
    address.fax = address.clean_value_all r_arr[session[:imp_user_fax]] if session[:imp_user_fax] >= 0
    address
  end

  def clean_value_all(value)
    cv = value.to_s
    while cv[0, 1] == "\"" or cv[0] == "'" do
      cv = cv[1..cv.length]
    end
    while cv[cv.length - 1, 1] == "\"" or cv[cv.length - 1, 1] == "'" do
      cv = cv[0..cv.length - 2]
    end
    cv
  end
end
