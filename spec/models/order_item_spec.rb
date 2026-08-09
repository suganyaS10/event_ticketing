require 'rails_helper'

RSpec.describe OrderItem, type: :model do
  subject { build(:order_item) }

  it { is_expected.to belong_to(:order) }
  it { is_expected.to belong_to(:ticket_tier) }

  it { is_expected.to validate_presence_of(:quantity) }
  it { is_expected.to validate_presence_of(:unit_price_cents) }
  it { is_expected.to validate_presence_of(:total_cents) }

  describe 'numericality' do
    it 'rejects a negative quantity' do
      expect(build(:order_item, quantity: -1)).to be_invalid
    end

    it 'rejects a fractional quantity' do
      expect(build(:order_item, quantity: 1.5)).to be_invalid
    end

    it 'rejects a negative unit_price_cents' do
      expect(build(:order_item, unit_price_cents: -1)).to be_invalid
    end
  end

  # An order is scoped to one event, so a line may only draw on that event's tiers.
  describe 'the tier must belong to the order event' do
    let(:order) { create(:order) }

    it 'is valid for a tier of the order event' do
      tier = create(:ticket_tier, event: order.event)
      expect(build(:order_item, order: order, ticket_tier: tier)).to be_valid
    end

    it 'is invalid for a tier of a different event' do
      item = build(:order_item, order: order, ticket_tier: create(:ticket_tier))
      expect(item).to be_invalid
      expect(item.errors[:ticket_tier]).to include("must belong to the order's event")
    end
  end
end
