module Api
  module V1
    class OrdersController < BaseController
      rescue_from Orders::Errors::UnknownTier, with: :handle_invalid_tier
      rescue_from Orders::Errors::InvalidTier, with: :handle_invalid_tier
      rescue_from Orders::Errors::PriceMismatch, with: :handle_data_conflict
      rescue_from Orders::Errors::StockMismatch, with: :handle_data_conflict

      def index
        customer = Customer.find_by!(email: customer_params[:email])
        customer_orders = customer.orders.order(updated_at: :desc)

        json_response(
          data: Api::V1::OrderSerializer.render_as_hash(customer_orders)
        )
      end

      def show
        order = Order.find_by!(order_ref: params[:order_ref])

        json_response(
          data: Api::V1::OrderSerializer.render_as_hash(order)
        )
      end

      def create
        event = Event.published.find(params[:event_id])
        customer_params, order_item_params = order_params
        order_item_params = sanitize_request!(order_item_params)
        purchased_order = Orders::TicketsService.call(
            event:,
            customer_params:,
            order_item_params:,
          )

        json_response(
          data: Api::V1::OrderSerializer.render_as_hash(purchased_order),
          status: :created
        )
      end

      private

      def customer_params
        params.permit(:email)
      end

      def order_params
        params.expect(
          customer: [ :email, :first_name, :last_name, :mobile ],
          items: [ [ :ticket_tier_id, :quantity, :expected_unit_price_cents ] ],
        )
      end

      def sanitize_request!(order_item_params)
        order_item_params.map do |item|
          {
            ticket_tier_id: Integer(item[:ticket_tier_id].to_s),
            quantity: Integer(item[:quantity].to_s),
            expected_unit_price_cents: Integer(item[:expected_unit_price_cents].to_s)
          }.tap do |line|
            raise Orders::Errors::InvalidTier, "Quantity must be a positive whole number" unless line[:quantity].positive?
          end
        end
      rescue TypeError, ArgumentError
        raise Orders::Errors::InvalidTier, "Ticket tier, quantity and price must be whole numbers"
      end

      def handle_invalid_tier(exception)
        render_error(
          status: :unprocessable_content,
          code: "invalid_request",
          message: exception.message
        )
      end

      def handle_data_conflict(exception)
        render_error(
          status: :conflict,
          code: "purchase_conflict",
          message: exception.message
        )
      end
    end
  end
end
