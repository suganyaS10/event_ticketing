class Event < ApplicationRecord
  validates :name, :venue, :start_time, presence: true
  validates_comparison_of :end_time, greater_than: :start_time, allow_nil: true

  enum :status, { draft: "draft", published: "published" }, validate: true

  has_many :ticket_tiers, dependent: :restrict_with_error
end
