# -*- encoding : utf-8 -*-
# For ActiveRecord relation
class Usergroup < ActiveRecord::Base
  attr_protected

  belongs_to :user
end
