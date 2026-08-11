module Orders
  class TicketsService < BaseService
    def initialize(event:, customer_params:, order_item_params:)
      @event = event
      @customer_params = customer_params
      @order_item_params = order_item_params
    end

    def call
      validate_request!
      place_orders!
    end

    private

    attr_reader :event, :customer_params, :order_item_params

    def validate_request!
      reject_if_unknown_tier!
      reject_if_contains_duplicate_tiers!
      reject_if_tier_is_outside_sale_window!
    end

    def reject_if_tier_is_outside_sale_window!
      tiers_outside_sale_window = event_tiers.select { |tier| !tier.sale_window_live? }
      return if tiers_outside_sale_window.empty?

      raise Errors::InvalidTier, "the following tiers sale window has been closed - #{tiers_outside_sale_window.map(&:id)}"
    end

    def reject_if_contains_duplicate_tiers!
      duplicate_tier_ids = requested_tier_ids.tally.select { |_id, count| count > 1 }.keys
      return if duplicate_tier_ids.empty?

      raise Errors::InvalidTier, "Duplicate tier ids in the request - #{duplicate_tier_ids}"
    end

    def reject_if_unknown_tier!
      unknown_tier_ids = requested_tier_ids - event_tiers.map(&:id)
      return if unknown_tier_ids.empty?

      raise Errors::UnknownTier, "The following tiers does not belong to the event - #{unknown_tier_ids}"
    end

    def place_orders!
      customer = create_customer
      order = create_order(customer)
      purchase_tickets!(order)
      order
    end

    def create_customer
      Customer.find_or_create_by!(email: customer_params[:email]) do |customer|
        customer.assign_attributes(customer_params.to_h.except("email", :email))
      end
    end

    def create_order(customer)
      Order.create!(
        event: event,
        customer: customer,
      )
    end

    def purchase_tickets!(order)
      ActiveRecord::Base.transaction do
        tiers = lock_tiers!
        check_purchaseability(tiers)
        update_inventory!(order, tiers)
        update_order_total!(order)
        update_order_status!(order)
      end
    rescue Errors::TierDataMismatch, ActiveRecord::RecordInvalid => e
      order.update_columns(
        status: Order.statuses["failed"],
        failure_reason: e.message,
        updated_at: Time.current
      )
      raise
    end

    def lock_tiers!
      event.ticket_tiers
              .where(id: requested_tier_ids)
              .order(:id)
              .lock
              .index_by(&:id)
    end

    def update_inventory!(order, tiers)
      order_item_params.each do |item|
        tier = tiers[item[:ticket_tier_id]]
        total_cents = item[:quantity] * tier.price_cents

        order.order_items.create!(
          quantity: item[:quantity],
          unit_price_cents: tier.price_cents,
          ticket_tier: tier,
          total_cents: total_cents
        )

        tier.update!(quantity_sold: tier.quantity_sold + item[:quantity])
      end
    end

    def update_order_total!(order)
      total_cents = order.order_items.sum(:total_cents)
      order.update!(total_cents: total_cents)
    end

    def update_order_status!(order)
      order.update!(status: Order.statuses["succeeded"])
    end

    def check_purchaseability(tiers)
      reject_if_price_changed!(tiers)
      reject_if_stock_unavailable!(tiers)
    end

    def reject_if_price_changed!(tiers)
      price_changed_tiers = order_item_params.filter_map do |item_param|
        tier = tiers[item_param[:ticket_tier_id]]
        next if tier.price_cents == item_param[:expected_unit_price_cents]
        tier
      end
      return if price_changed_tiers.empty?

      error_message = "The following tiers have new price - #{price_changed_tiers.map(&:id)}"
      raise Errors::PriceMismatch, error_message
    end

    def reject_if_stock_unavailable!(tiers)
      out_of_stock_tiers = order_item_params.filter_map do |item_param|
        tier = tiers[item_param[:ticket_tier_id]]
        next if tier.quantity_available >= item_param[:quantity]
        tier
      end
      return if out_of_stock_tiers.empty?

      error_message = "Not enough tickets remain for the quantity requested - #{out_of_stock_tiers.map(&:id)}"
      raise Errors::StockMismatch, error_message
    end

    def requested_tier_ids
      order_item_params.map { |item| item[:ticket_tier_id] }
    end

    def event_tiers
      @event_tiers ||= event.ticket_tiers.where(id: requested_tier_ids)
    end
  end
end
