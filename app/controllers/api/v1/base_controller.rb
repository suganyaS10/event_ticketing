module Api
  module V1
    class BaseController < ActionController::API
      include ResponseFormatter
    end
  end
end
