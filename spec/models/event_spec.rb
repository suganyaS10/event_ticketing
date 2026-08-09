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
end
