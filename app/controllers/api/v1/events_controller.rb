module Api
  module V1
    class EventsController < BaseController
      def index
        events = Event.
          includes(:ticket_tiers).
          published.
          upcoming.
          order(start_time: :asc)

        json_response(
          data: Api::V1::EventSerializer.render_as_hash(events, view: :summary)
        )
      end

      def show
        event = Event.published.find(params[:id])

        json_response(
          data: Api::V1::EventSerializer.render_as_hash(event, view: :detailed)
        )
      end
    end
  end
end
