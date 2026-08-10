class Event < ApplicationRecord
  validates :name, :venue, :start_time, presence: true
  validates_comparison_of :end_time, greater_than: :start_time, allow_nil: true

  enum :status, { draft: "draft", published: "published" }, validate: true

  has_many :ticket_tiers, dependent: :restrict_with_error

  scope :upcoming, -> { where("start_time > ?", Time.zone.now) }


  def available_tiers
    ticket_tiers.select { |tier| tier.available? && tier.sale_window_live? }
  end

  def min_ticket_price
    available_tiers.map(&:price_cents).min
  end

  def tickets_purchaseable?
    available_tiers.any?
  end
end
