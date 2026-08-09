class Customer < ApplicationRecord
  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_many :orders
end
