require 'rails_helper'

RSpec.describe Event, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:venue) }
  it { is_expected.to validate_presence_of(:start_time) }

  describe "end_time comparison" do
    let(:start_time) { Time.zone.parse("2026-09-01 19:00") }
    subject(:event) { Event.new(name: "Gig", venue: "The Lexington", start_time:) }

    it "is valid when end_time is after start_time" do
      event.end_time = start_time + 2.hours
      expect(event).to be_valid
    end

    it "is valid when end_time is nil" do
      event.end_time = nil
      expect(event).to be_valid
    end

    it "is invalid when end_time is before start_time" do
      event.end_time = start_time - 1.hour
      expect(event).to be_invalid
      expect(event.errors).to be_of_kind(:end_time, :greater_than)
    end

    it "is invalid when end_time equals start_time" do
      event.end_time = start_time
      expect(event).to be_invalid
      expect(event.errors).to be_of_kind(:end_time, :greater_than)
    end
  end

  describe "#available_tiers" do
    let(:event) { create(:event) }

    it "includes a tier with stock and a live sale window" do
      tier = create(:ticket_tier, event:)
      expect(event.available_tiers).to eq([ tier ])
    end

    it "excludes a sold out tier" do
      create(:ticket_tier, :sold_out, event:)
      expect(event.available_tiers).to be_empty
    end

    it "excludes a tier whose sale window has closed" do
      create(:ticket_tier, :sales_ended, event:)
      expect(event.available_tiers).to be_empty
    end

    it "excludes a tier whose sale window has not opened" do
      create(:ticket_tier, :not_yet_on_sale, event:)
      expect(event.available_tiers).to be_empty
    end

    it "is empty when the event has no tiers" do
      expect(event.available_tiers).to be_empty
    end
  end

  describe "#min_ticket_price" do
    let(:event) { create(:event) }

    it "is the cheapest available tier price" do
      create(:ticket_tier, event:, price_cents: 5_000)
      create(:ticket_tier, event:, price_cents: 2_500)
      expect(event.min_ticket_price).to eq(2_500)
    end

    it "ignores a cheaper tier that is no longer on sale" do
      create(:ticket_tier, :sales_ended, event:, price_cents: 1_500)
      create(:ticket_tier, event:, price_cents: 2_200)
      expect(event.min_ticket_price).to eq(2_200)
    end

    it "ignores a cheaper tier that is sold out" do
      create(:ticket_tier, :sold_out, event:, price_cents: 1_000)
      create(:ticket_tier, event:, price_cents: 2_500)
      expect(event.min_ticket_price).to eq(2_500)
    end

    it "is nil when nothing is available" do
      create(:ticket_tier, :sold_out, event:)
      expect(event.min_ticket_price).to be_nil
    end
  end

  describe "#tickets_purchaseable?" do
    let(:event) { create(:event) }

    it "is true when at least one tier is available" do
      create(:ticket_tier, :sold_out, event:)
      create(:ticket_tier, event:)
      expect(event).to be_tickets_purchaseable
    end

    it "is false when every tier is sold out" do
      create_list(:ticket_tier, 2, :sold_out, event:)
      expect(event).not_to be_tickets_purchaseable
    end

    it "is false when every sale window has closed" do
      create(:ticket_tier, :sales_ended, event:)
      expect(event).not_to be_tickets_purchaseable
    end

    it "is false when the event has no tiers" do
      expect(event).not_to be_tickets_purchaseable
    end
  end
end
