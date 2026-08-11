require 'rails_helper'

RSpec.describe Order, type: :model do
  subject { build(:order) }

  it { is_expected.to validate_presence_of(:total_cents) }
  it { is_expected.to belong_to(:event) }
  it { is_expected.to belong_to(:customer) }

  describe 'status' do
    it 'defaults to initialised' do
      expect(Order.new.status).to eq('initialised')
    end

    it 'rejects a value outside the enum' do
      order = build(:order)
      expect { order.status = 'refunded' }.not_to raise_error
      expect(order).to be_invalid
      expect(order.errors).to be_of_kind(:status, :inclusion)
    end

    it 'accepts every declared state' do
      %w[initialised succeeded failed cancelled].each do |state|
        expect(build(:order, status: state)).to be_valid
      end
    end
  end

  describe 'order_ref' do
    it 'is generated when none is supplied' do
      expect(build(:order).tap(&:validate).order_ref).to match(/\AORD-[0-9A-F]{16}\z/)
    end

    it 'keeps a ref that was supplied explicitly' do
      order = build(:order, order_ref: 'ORD-KNOWNVALUE12345')
      order.validate
      expect(order.order_ref).to eq('ORD-KNOWNVALUE12345')
    end
  end
end
