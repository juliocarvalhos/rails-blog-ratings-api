class Rating < ApplicationRecord
  belongs_to :post
  belongs_to :user

  validates :value, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :post_id }

  after_create :increment_post_counters
  after_update :update_post_counters_on_change
  after_destroy :decrement_post_counters

  private

  def increment_post_counters
    post.increment_rating_counters!(value)
  end

  def update_post_counters_on_change
    if saved_change_to_value?
      old_value, new_value = saved_change_to_value
      post.increment!(:ratings_sum, new_value - old_value)
      post.update_avg_rating!
    end
  end

  def decrement_post_counters
    post.increment!(:ratings_count, -1)
    post.increment!(:ratings_sum, -value)
    post.update_avg_rating!
  end
end
