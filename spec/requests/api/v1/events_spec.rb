require "rails_helper"

RSpec.describe "Api::V1::Events", type: :request do
  def data = response.parsed_body["data"]

  def listed_event(**attributes)
    create(:event, **attributes).tap { |event| create(:ticket_tier, event:) }
  end

  describe "GET /api/v1/events" do
    describe "which events are listed" do
      it "returns published events that have not started yet" do
        event = listed_event

        get "/api/v1/events"

        expect(response).to have_http_status(:ok)
        expect(data.pluck("id")).to eq([ event.id ])
      end

      it "excludes draft events" do
        listed_event(name: "Listed")
        create(:event, :draft, name: "Draft")

        get "/api/v1/events"

        expect(data.pluck("name")).to eq([ "Listed" ])
      end

      it "excludes events that have already started" do
        listed_event(name: "Listed")
        create(:event, :past, name: "Finished")

        get "/api/v1/events"

        expect(data.pluck("name")).to eq([ "Listed" ])
      end

      it "orders events by start time ascending" do
        listed_event(name: "Later", start_time: 4.weeks.from_now)
        listed_event(name: "Sooner", start_time: 1.week.from_now)

        get "/api/v1/events"

        expect(data.pluck("name")).to eq([ "Sooner", "Later" ])
      end

      it "returns an empty collection rather than a 404 when nothing is listable" do
        create(:event, :draft)

        get "/api/v1/events"

        expect(response).to have_http_status(:ok)
        expect(data).to eq([])
      end
    end

    describe "the response payload" do
      before { listed_event }

      it "wraps the collection in a data envelope" do
        get "/api/v1/events"

        expect(response.parsed_body.keys).to contain_exactly("data", "meta")
      end

      it "exposes exactly the summary fields, in the order the serializer declares them" do
        get "/api/v1/events"

        expect(data.first.keys).to eq(%w[
          id name venue short_description start_time end_time
          tickets_available price_starts_from currency
        ])
      end

      # The point of the summary view: detail belongs to the single-event endpoint.
      it "omits the detail reserved for a single event" do
        get "/api/v1/events"

        expect(data.first).not_to include("description", "ticket_tiers")
      end
    end

    describe "pricing and availability" do
      let(:event) { create(:event) }

      it "quotes the cheapest tier on sale" do
        create(:ticket_tier, event:, price_cents: 5_000)
        create(:ticket_tier, event:, price_cents: 2_200)

        get "/api/v1/events"

        expect(data.first["price_starts_from"]).to eq(2_200)
      end

      # Guards against advertising a price nobody can actually pay.
      it "ignores a cheaper tier whose sale window has closed" do
        create(:ticket_tier, :sales_ended, event:, price_cents: 1_500)
        create(:ticket_tier, event:, price_cents: 2_200)

        get "/api/v1/events"

        expect(data.first["price_starts_from"]).to eq(2_200)
      end

      it "reports tickets as available while a tier can be bought" do
        create(:ticket_tier, event:)

        get "/api/v1/events"

        expect(data.first["tickets_available"]).to be(true)
      end

      it "reports sold out, with no price, once every tier is exhausted" do
        create(:ticket_tier, :sold_out, event:)

        get "/api/v1/events"

        expect(data.first["tickets_available"]).to be(false)
        expect(data.first["price_starts_from"]).to be_nil
      end
    end
  end

  describe "GET /api/v1/events/:id" do
    it "returns the event" do
      event = listed_event

      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      expect(data["id"]).to eq(event.id)
      expect(data["name"]).to eq(event.name)
    end

    it "returns a published event that has already started" do
      event = create(:event, :past).tap { |e| create(:ticket_tier, event: e) }

      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      expect(data["id"]).to eq(event.id)
    end

    describe "the response payload" do
      before { get "/api/v1/events/#{listed_event.id}" }

      it "builds on the summary view rather than replacing it" do
        expect(data.keys).to eq(%w[
          id name venue short_description start_time end_time
          tickets_available price_starts_from currency
          description ticket_tiers
        ])
      end

      it "embeds the ticket tiers" do
        expect(data["ticket_tiers"].first.keys).to eq(%w[
          id name price_cents currency perks quantity_available on_sale
        ])
      end
    end

    it "returns 404 for a draft event" do
      event = create(:event, :draft)

      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end

    it "returns 404 for an id that does not exist" do
      get "/api/v1/events/#{Event.maximum(:id).to_i + 1}"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end
  end
end
