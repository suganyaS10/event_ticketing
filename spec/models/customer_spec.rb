require 'rails_helper'

RSpec.describe Customer, type: :model do
  subject { build(:customer) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }

  describe 'email format' do
    it 'accepts a well-formed address' do
      expect(build(:customer, email: 'alex.fern+tickets@example.co.uk')).to be_valid
    end

    it 'rejects an address with no domain' do
      customer = build(:customer, email: 'alex@')
      expect(customer).to be_invalid
      expect(customer.errors).to be_of_kind(:email, :invalid)
    end

    it 'rejects a value that is not an address at all' do
      expect(build(:customer, email: 'not an email')).to be_invalid
    end

    it 'does not allow nil email' do
      expect(build(:customer, email: nil)).to be_invalid
    end
  end

  describe 'email normalisation' do
    it 'strips surrounding whitespace and downcases' do
      expect(build(:customer, email: '  Alex.Fern@Example.COM  ').email)
        .to eq('alex.fern@example.com')
    end

    it 'treats differently-cased addresses as the same customer' do
      create(:customer, email: 'alex@example.com')
      expect(build(:customer, email: 'ALEX@Example.com ')).to be_invalid
    end
  end

  describe 'everything other than email' do
    it 'is valid with an email alone' do
      expect(build(:customer, :minimal)).to be_valid
    end
  end
end
