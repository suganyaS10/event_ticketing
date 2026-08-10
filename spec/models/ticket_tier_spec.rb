require 'rails_helper'

RSpec.describe TicketTier, type: :model do
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

  describe '#quantity_available' do
    it 'is the unsold remainder of the allocation' do
      expect(build(:ticket_tier, quantity_total: 10, quantity_sold: 3).quantity_available).to eq(7)
    end

    it 'is zero once every ticket is sold' do
      expect(build(:ticket_tier, quantity_total: 10, quantity_sold: 10).quantity_available).to eq(0)
    end

    it 'is the full allocation before anything sells' do
      expect(build(:ticket_tier, quantity_total: 10, quantity_sold: 0).quantity_available).to eq(10)
    end
  end

  describe '#available?' do
    it 'is true while at least one ticket remains' do
      expect(build(:ticket_tier, quantity_total: 10, quantity_sold: 9)).to be_available
    end

    it 'is false once sold out' do
      expect(build(:ticket_tier, quantity_total: 10, quantity_sold: 10)).not_to be_available
    end

    it 'reports stock only, ignoring a closed sale window' do
      tier = build(:ticket_tier, quantity_total: 10, quantity_sold: 0,
                                 sale_starts_at: 30.days.ago, sale_ends_at: 1.day.ago)

      expect(tier).to be_available
    end
  end

  describe '#sale_window_live?' do
    let(:now) { Time.zone.parse('2026-09-01 12:00:00') }

    def tier(**window) = build(:ticket_tier, **window)

    it 'is true when no window is set at all' do
      expect(tier(sale_starts_at: nil, sale_ends_at: nil).sale_window_live?(now)).to be(true)
    end

    it 'is true inside the window' do
      expect(tier(sale_starts_at: now - 1.hour, sale_ends_at: now + 1.hour)
               .sale_window_live?(now)).to be(true)
    end

    it 'is false before the window opens' do
      expect(tier(sale_starts_at: now + 1.hour).sale_window_live?(now)).to be(false)
    end

    it 'is false after the window closes' do
      expect(tier(sale_ends_at: now - 1.hour).sale_window_live?(now)).to be(false)
    end

    it 'treats a nil start as open-ended in the past' do
      expect(tier(sale_starts_at: nil, sale_ends_at: now + 1.hour)
               .sale_window_live?(now)).to be(true)
    end

    it 'treats a nil end as open-ended in the future' do
      expect(tier(sale_starts_at: now - 1.hour, sale_ends_at: nil)
               .sale_window_live?(now)).to be(true)
    end

    it 'is live at the exact instant sales open' do
      expect(tier(sale_starts_at: now).sale_window_live?(now)).to be(true)
    end

    it 'is live 1 minute before the sales end' do
      expect(tier(sale_ends_at: now + 1.minute).sale_window_live?(now)).to be(true)
    end

    it 'is closed at the exact instant sales end' do
      expect(tier(sale_ends_at: now).sale_window_live?(now)).to be(false)
    end

    it 'defaults to the current time when no instant is given' do
      expect(tier(sale_starts_at: 1.hour.ago, sale_ends_at: 1.hour.from_now)).to be_sale_window_live
      expect(tier(sale_starts_at: 2.hours.ago, sale_ends_at: 1.hour.ago)).not_to be_sale_window_live
    end
  end
end
