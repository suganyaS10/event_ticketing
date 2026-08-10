# frozen_string_literal: true

module Api
  module V1
    module ResponseFormatter
      extend ActiveSupport::Concern

      included do
        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      end

      def json_response(data: nil, message: nil, status: :ok, meta_data: {})
        response = {
          message:,
          data:,
          meta: meta_data
        }.compact

        render(json: response, status:)
      end

      def json_error_response(errors:, status:)
        render(json: { errors: }, status:)
      end

      private

      def render_not_found(_error)
        render_error(status: :not_found,
                     code: "not_found",
                     message: "The requested resource does not exist.")
      end


      def render_error(status:, code:, message:, details: nil)
        body = { error: { code: code, message: message } }
        body[:error][:details] = details if details.present?

        render json: body, status: status
      end
    end
  end
end
