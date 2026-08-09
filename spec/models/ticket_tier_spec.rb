require 'rails_helper'

RSpec.describe TicketTier, type: :model do
  # validate_uniqueness_of persists the subject to compare against, so it needs a
  # record whose required associations are already filled in.
  subject { build(:ticket_tier) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:price_cents) }
  it { is_expected.to validate_presence_of(:currency) }
  it { is_expected.to validate_presence_of(:quantity_total) }
  it { is_expected.to validate_presence_of(:quantity_sold) }

  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:event_id) }

  describe 'quantity_sold must not exceed quantity_total' do
    subject(:tier) { build(:ticket_tier, quantity_total: 100, quantity_sold: 0) }

    it 'is valid while tickets remain' do
      tier.quantity_sold = 99
      expect(tier).to be_valid
    end

    it 'is valid when the tier is exactly sold out' do
      tier.quantity_sold = 100
      expect(tier).to be_valid
    end

    it 'is invalid when oversold by a single ticket' do
      tier.quantity_sold = 101
      expect(tier).to be_invalid
      expect(tier.errors).to be_of_kind(:quantity_sold, :less_than_or_equal_to)
    end
  end

  describe 'the ticket_inventory_within_capacity check constraint' do
    let(:tier) { create(:ticket_tier, quantity_total: 100, quantity_sold: 99) }

    it 'permits selling the last ticket' do
      expect { tier.update_column(:quantity_sold, 100) }.not_to raise_error
    end

    it 'rejects an oversell even with Active Record validations bypassed' do
      expect { tier.update_column(:quantity_sold, 101) }
        .to raise_error(ActiveRecord::StatementInvalid, /ticket_inventory_within_capacity/)
    end

    it 'rejects a negative quantity_sold' do
      expect { tier.update_column(:quantity_sold, -1) }
        .to raise_error(ActiveRecord::StatementInvalid, /ticket_inventory_within_capacity/)
    end
  end
end
