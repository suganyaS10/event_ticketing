require "rails_helper"

RSpec.describe Orders::TicketsService do
  def purchase(event:, items:, email: "buyer@example.com")
    described_class.call(
      event: event,
      customer_params: { email: email },
      order_item_params: items
    )
  end

  # Defaults to quoting the tier's current price, so a stale quote has to be asked for.
  def item(tier, quantity: 1, price: tier.price_cents)
    { ticket_tier_id: tier.id, quantity: quantity, expected_unit_price_cents: price }
  end

  let(:event) { create(:event) }
  let(:tier) { create(:ticket_tier, event: event, price_cents: 2_500, quantity_total: 10, quantity_sold: 4) }

  describe "a successful purchase" do
    it "creates a succeeded order totalled from its lines" do
      order = purchase(event: event, items: [ item(tier, quantity: 2) ])

      expect(order).to have_attributes(status: "succeeded", total_cents: 5_000, failure_reason: nil)
      expect(order.order_ref).to match(/\AORD-[0-9A-F]{16}\z/)
    end

    it "snapshots the unit price from the tier rather than the quote" do
      order = purchase(event: event, items: [ item(tier, quantity: 2) ])

      expect(order.order_items.sole).to have_attributes(
        ticket_tier: tier, quantity: 2, unit_price_cents: 2_500, total_cents: 5_000
      )
    end

    it "consumes the tier inventory" do
      expect { purchase(event: event, items: [ item(tier, quantity: 2) ]) }
        .to change { tier.reload.quantity_sold }.from(4).to(6)
    end

    it "spans several tiers of the same event" do
      vip = create(:ticket_tier, :vip, event: event, price_cents: 7_500, quantity_total: 5, quantity_sold: 0)

      order = purchase(event: event, items: [ item(tier, quantity: 2), item(vip, quantity: 1) ])

      expect(order.total_cents).to eq(12_500)
      expect(order.order_items.count).to eq(2)
      expect(vip.reload.quantity_sold).to eq(1)
    end

    it "reuses an existing customer with the same email" do
      customer = create(:customer, email: "repeat@example.com")

      expect { purchase(event: event, items: [ item(tier) ], email: "repeat@example.com") }
        .not_to change(Customer, :count)
      expect(Order.sole.customer).to eq(customer)
    end
  end

  describe "requests rejected before an order exists" do
    it "rejects a tier belonging to another event" do
      other_event_tier = create(:ticket_tier)

      expect { purchase(event: event, items: [ item(other_event_tier) ]) }
        .to raise_error(Orders::Errors::UnknownTier, /does not belong to the event/)
    end

    it "rejects the same tier listed twice" do
      expect { purchase(event: event, items: [ item(tier), item(tier) ]) }
        .to raise_error(Orders::Errors::InvalidTier, /Duplicate tier ids/)
    end

    it "rejects a tier whose sale window has closed" do
      closed = create(:ticket_tier, :sales_ended, event: event)

      expect { purchase(event: event, items: [ item(closed) ]) }
        .to raise_error(Orders::Errors::InvalidTier, /sale window has been closed/)
    end

    it "rejects a tier that is not on sale yet" do
      upcoming = create(:ticket_tier, :not_yet_on_sale, event: event)

      expect { purchase(event: event, items: [ item(upcoming) ]) }
        .to raise_error(Orders::Errors::InvalidTier, /sale window has been closed/)
    end

    it "leaves no order behind" do
      expect { purchase(event: event, items: [ item(tier), item(tier) ]) }
        .to raise_error(Orders::Errors::InvalidTier)

      expect(Order.count).to be_zero
    end
  end

  describe "requests that fail once the order exists" do
    it "rejects a stale price and records why" do
      expect { purchase(event: event, items: [ item(tier, price: 2_000) ]) }
        .to raise_error(Orders::Errors::PriceMismatch, /have new price/)

      expect(Order.sole).to have_attributes(status: "failed", total_cents: 0)
      expect(Order.sole.failure_reason).to match(/have new price/)
    end

    # The quote is correct when the request arrives and only goes stale part-way
    # through it. This passes only because the comparison reads the locked row —
    # the tiers loaded during validate_request! still hold the old price.
    it "rejects a price that changes after validation but before the lock" do
      service = described_class.new(
        event: event,
        customer_params: { email: "buyer@example.com" },
        order_item_params: [ item(tier) ] # quotes 2_500, the price at request time
      )

      allow(service).to receive(:lock_tiers!).and_wrap_original do |original|
        tier.update!(price_cents: 3_000)
        original.call
      end

      expect { service.call }.to raise_error(Orders::Errors::PriceMismatch, /have new price/)
      expect(Order.sole).to have_attributes(status: "failed", total_cents: 0)
      expect(tier.reload.quantity_sold).to eq(4)
    end

    it "rejects a quantity larger than the remaining stock" do
      expect { purchase(event: event, items: [ item(tier, quantity: 7) ]) }
        .to raise_error(Orders::Errors::StockMismatch, /Not enough tickets remain/)

      expect(Order.sole.status).to eq("failed")
    end

    it "rejects a sold out tier" do
      sold_out = create(:ticket_tier, :sold_out, event: event)

      expect { purchase(event: event, items: [ item(sold_out) ]) }
        .to raise_error(Orders::Errors::StockMismatch, /Not enough tickets remain/)
    end

    it "rolls back the inventory and the order lines" do
      expect { purchase(event: event, items: [ item(tier, quantity: 7) ]) }
        .to raise_error(Orders::Errors::StockMismatch)

      expect(tier.reload.quantity_sold).to eq(4)
      expect(OrderItem.count).to be_zero
    end

    it "rejects the whole basket when only one line is unaffordable" do
      vip = create(:ticket_tier, :vip, event: event, quantity_total: 1, quantity_sold: 1)

      expect { purchase(event: event, items: [ item(tier), item(vip) ]) }
        .to raise_error(Orders::Errors::StockMismatch)

      expect(tier.reload.quantity_sold).to eq(4)
    end
  end

  # Needs committed rows: two transactions cannot see each other's uncommitted work,
  # so the race will not reproduce under transactional tests.
  describe "two customers buying the last ticket at once" do
    self.use_transactional_tests = false

    after do
      OrderItem.delete_all
      Order.delete_all
      TicketTier.delete_all
      Customer.delete_all
      Event.delete_all
    end

    it "sells it exactly once" do
      event = create(:event)
      tier = create(:ticket_tier, event: event, price_cents: 1_800, quantity_total: 10, quantity_sold: 9)

      start = Queue.new
      outcomes = Queue.new

      threads = 2.times.map do |i|
        Thread.new do
          start.pop
          ActiveRecord::Base.connection_pool.with_connection do
            purchase(event: event, items: [ item(tier) ], email: "racer#{i}@example.com")
            outcomes << :sold
          rescue Orders::Errors::StockMismatch
            outcomes << :rejected
          end
        end
      end

      2.times { start << :go }
      threads.each(&:join)

      expect([ outcomes.pop, outcomes.pop ]).to contain_exactly(:sold, :rejected)
      expect(tier.reload.quantity_sold).to eq(10)
      expect(Order.where(status: :succeeded).count).to eq(1)
    end
  end
end
