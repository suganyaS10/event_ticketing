require "rails_helper"

RSpec.describe "Api::V1::Orders", type: :request do
  def data = response.parsed_body["data"]
  def error = response.parsed_body["error"]

  def post_order(event, items, email: "buyer@example.com")
    post "/api/v1/events/#{event.id}/orders",
         params: { customer: { email: email }, items: items }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
  end

  def item(tier, quantity: 1, price: tier.price_cents)
    { ticket_tier_id: tier.id, quantity: quantity, expected_unit_price_cents: price }
  end

  let(:event) { create(:event) }
  let(:tier) { create(:ticket_tier, event: event, price_cents: 2_500, quantity_total: 10, quantity_sold: 4) }

  describe "POST /api/v1/events/:event_id/orders" do
    describe "a successful purchase" do
      it "returns 201 with the order" do
        post_order(event, [ item(tier, quantity: 2) ])

        expect(response).to have_http_status(:created)
        expect(data).to include("status" => "succeeded", "total_cents" => 5_000)
        expect(data["order_ref"]).to match(/\AORD-[0-9A-F]{16}\z/)
      end

      it "embeds the lines and the customer" do
        post_order(event, [ item(tier, quantity: 2) ])

        expect(data["order_items"].sole).to include(
          "quantity" => 2, "unit_price_cents" => 2_500, "total_cents" => 5_000
        )
        expect(data.dig("customer", "email")).to eq("buyer@example.com")
      end

      it "consumes the tier inventory" do
        expect { post_order(event, [ item(tier, quantity: 2) ]) }
          .to change { tier.reload.quantity_sold }.from(4).to(6)
      end

      it "accepts a basket spanning several tiers of the event" do
        vip = create(:ticket_tier, :vip, event: event, price_cents: 7_500, quantity_total: 5, quantity_sold: 0)

        post_order(event, [ item(tier, quantity: 2), item(vip, quantity: 1) ])

        expect(response).to have_http_status(:created)
        expect(data["total_cents"]).to eq(12_500)
        expect(data["order_items"].size).to eq(2)
      end
    end

    describe "409 conflicts - the request is valid but the tier data has been updated" do
      it "rejects a stale price" do
        post_order(event, [ item(tier, price: 2_000) ])

        expect(response).to have_http_status(:conflict)
        expect(error).to include("code" => "purchase_conflict")
        expect(error["message"]).to match(/new price/)
      end

      it "rejects a quantity larger than the remaining stock" do
        post_order(event, [ item(tier, quantity: 7) ])

        expect(response).to have_http_status(:conflict)
        expect(error["message"]).to match(/Not enough tickets remain/)
      end

      it "rejects a sold out tier" do
        sold_out = create(:ticket_tier, :sold_out, event: event)

        post_order(event, [ item(sold_out) ])

        expect(response).to have_http_status(:conflict)
      end

      it "records the failed order and leaves inventory untouched" do
        post_order(event, [ item(tier, quantity: 7) ])

        expect(Order.sole).to have_attributes(status: "failed", total_cents: 0)
        expect(tier.reload.quantity_sold).to eq(4)
      end
    end

    describe "422 rejections - the request itself is wrong" do
      it "rejects a tier belonging to another event" do
        post_order(event, [ item(create(:ticket_tier)) ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(error).to include("code" => "invalid_request")
        expect(error["message"]).to match(/does not belong to the event/)
      end

      it "rejects the same tier listed twice" do
        post_order(event, [ item(tier), item(tier) ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(error["message"]).to match(/Duplicate tier ids/)
      end

      it "rejects a tier whose sale window has closed" do
        post_order(event, [ item(create(:ticket_tier, :sales_ended, event: event)) ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(error["message"]).to match(/sale window has been closed/)
      end

      it "rejects a non-numeric quantity" do
        post_order(event, [ item(tier).merge(quantity: "abc") ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(error["message"]).to match(/whole numbers/)
      end

      it "rejects a fractional quantity" do
        post_order(event, [ item(tier).merge(quantity: 2.5) ])

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects a quantity of zero" do
        post_order(event, [ item(tier).merge(quantity: 0) ])

        expect(response).to have_http_status(:unprocessable_content)
        expect(error["message"]).to match(/positive whole number/)
      end

      it "creates no order when the request is rejected" do
        post_order(event, [ item(tier), item(tier) ])

        expect(Order.count).to be_zero
      end
    end

    describe "400 bad requests" do
      it "rejects a body with no items" do
        post "/api/v1/events/#{event.id}/orders",
             params: { customer: { email: "buyer@example.com" } }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end

      it "rejects a body with no customer" do
        post "/api/v1/events/#{event.id}/orders",
             params: { items: [ item(tier) ] }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    describe "404 for events that cannot be bought from" do
      it "returns 404 for an unknown event" do
        post "/api/v1/events/#{Event.maximum(:id).to_i + 1}/orders",
             params: { customer: { email: "buyer@example.com" }, items: [ item(tier) ] }.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for a draft event" do
        draft = create(:event, :draft)
        draft_tier = create(:ticket_tier, event: draft)

        post_order(draft, [ item(draft_tier) ])

        expect(response).to have_http_status(:not_found)
        expect(error).to include("code" => "not_found")
      end
    end
  end

  describe "GET /api/v1/orders/:order_ref" do
    it "returns the order" do
      post_order(event, [ item(tier, quantity: 2) ])
      order_ref = data["order_ref"]

      get "/api/v1/orders/#{order_ref}"

      expect(response).to have_http_status(:ok)
      expect(data).to include("order_ref" => order_ref, "status" => "succeeded", "total_cents" => 5_000)
      expect(data["order_items"].sole["unit_price_cents"]).to eq(2_500)
    end

    it "returns 404 for an unknown reference" do
      get "/api/v1/orders/ORD-DOESNOTEXIST01"

      expect(response).to have_http_status(:not_found)
      expect(error).to include("code" => "not_found")
    end
  end

  describe "GET /api/v1/orders" do
    it "lists that customer's orders, most recently updated first" do
      post_order(event, [ item(tier) ], email: "alex@example.com")
      first_ref = data["order_ref"]
      post_order(event, [ item(tier) ], email: "alex@example.com")
      second_ref = data["order_ref"]

      get "/api/v1/orders", params: { email: "alex@example.com" }

      expect(response).to have_http_status(:ok)
      expect(data.pluck("order_ref")).to eq([ second_ref, first_ref ])
    end

    it "does not leak another customer's orders" do
      post_order(event, [ item(tier) ], email: "alex@example.com")
      post_order(event, [ item(tier) ], email: "sam@example.com")

      get "/api/v1/orders", params: { email: "sam@example.com" }

      expect(data.size).to eq(1)
      expect(data.sole.dig("customer", "email")).to eq("sam@example.com")
    end

    it "returns 404 for an email with no customer" do
      get "/api/v1/orders", params: { email: "nobody@example.com" }

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when no email is given" do
      get "/api/v1/orders"

      expect(response).to have_http_status(:not_found)
    end
  end
end
