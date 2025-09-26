class Post < ApplicationRecord
  include DatabaseFunctions

  belongs_to :user
  has_many :ratings, dependent: :destroy

  validates :title, presence: true
  validates :body, presence: true
  validates :ip, presence: true
  validates :avg_rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  scope :top_rated, ->(limit = 10) {
    select("posts.*, CASE WHEN ratings_count > 0 THEN ratings_sum::float / ratings_count ELSE 0 END as calculated_avg_rating")
    .order("calculated_avg_rating DESC")
    .limit(limit)
  }

  def calculated_avg_rating
    return 0.0 if ratings_count == 0
    ratings_sum.to_f / ratings_count
  end

  def increment_rating_counters!(rating_value)
    increment!(:ratings_count, 1)
    increment!(:ratings_sum, rating_value)
    self.avg_rating = calculated_avg_rating
    save!
  end

  def update_avg_rating!
    self.avg_rating = calculated_avg_rating
    save!
  end
end
