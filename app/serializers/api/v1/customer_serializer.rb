module Api
  module V1
    class CustomerSerializer < ApplicationSerializer
      fields :first_name, :last_name, :email, :mobile
    end
  end
end
