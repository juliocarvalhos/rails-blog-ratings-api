class BulkRatingCreationService
  def self.call(ratings_data, batch_size: 1000)
    new(ratings_data, batch_size: batch_size).call
  end

  def initialize(ratings_data, batch_size: 1000)
    @ratings_data = ratings_data
    @batch_size = batch_size
  end

  def call
    return Failure.new(errors: [ "Ratings data cannot be empty" ]) if @ratings_data.empty?

    created_ratings = 0
    updated_posts = Set.new
    errors = []

    @ratings_data.each_slice(@batch_size) do |batch|
      result = process_batch(batch)
      if result.success?
        created_ratings += result.ratings_count
        updated_posts.merge(result.updated_posts)
      else
        errors.concat(result.errors)
      end
    end

    # Update avg_rating for all affected posts
    update_post_ratings(updated_posts)

    if errors.empty?
      Success.new(
        total_ratings: created_ratings,
        updated_posts: updated_posts.size
      )
    else
      Failure.new(errors: errors)
    end
  end

  private

  def process_batch(batch)
    # Validate that all posts and users exist
    post_ids = batch.map { |r| r[:post_id] }.uniq
    user_ids = batch.map { |r| r[:user_id] }.uniq

    existing_posts = Post.where(id: post_ids).pluck(:id).to_set
    existing_users = User.where(id: user_ids).pluck(:id).to_set

    invalid_posts = post_ids - existing_posts.to_a
    invalid_users = user_ids - existing_users.to_a

    errors = []
    errors << "Invalid post IDs: #{invalid_posts.join(', ')}" unless invalid_posts.empty?
    errors << "Invalid user IDs: #{invalid_users.join(', ')}" unless invalid_users.empty?

    return BatchFailure.new(errors: errors) unless errors.empty?

    # Filter out existing ratings to avoid duplicates
    existing_combinations = Rating.where(
      post_id: post_ids,
      user_id: user_ids
    ).pluck(:post_id, :user_id).to_set

    valid_ratings = batch.reject do |rating_data|
      existing_combinations.include?([ rating_data[:post_id], rating_data[:user_id] ])
    end

    # If no valid ratings, that's not necessarily an error for bulk operations
    # We just return success with 0 ratings created
    if valid_ratings.empty?
      return BatchSuccess.new(
        ratings_count: 0,
        updated_posts: []
      )
    end

    # Prepare ratings data for bulk insert
    ratings_to_create = valid_ratings.map do |rating_data|
      {
        post_id: rating_data[:post_id],
        user_id: rating_data[:user_id],
        value: rating_data[:value],
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Bulk insert ratings
    Rating.insert_all(ratings_to_create)

    # Update cache counters for affected posts
    post_rating_updates = valid_ratings.group_by { |r| r[:post_id] }
    post_rating_updates.each do |post_id, ratings|
      ratings_count = ratings.size
      ratings_sum = ratings.sum { |r| r[:value] }

      Post.where(id: post_id).update_all(
        "ratings_count = ratings_count + #{ratings_count},
         ratings_sum = ratings_sum + #{ratings_sum}"
      )
    end

    BatchSuccess.new(
      ratings_count: valid_ratings.size,
      updated_posts: post_rating_updates.keys
    )
  rescue StandardError => e
    BatchFailure.new(errors: [ e.message ])
  end

  def update_post_ratings(post_ids)
    return if post_ids.empty?

    # Update avg_rating for all affected posts
    Post.where(id: post_ids.to_a).find_each do |post|
      if post.ratings_count > 0
        post.update_column(:avg_rating, post.ratings_sum.to_f / post.ratings_count)
      end
    end
  end

  class Success
    attr_reader :total_ratings, :updated_posts

    def initialize(total_ratings:, updated_posts:)
      @total_ratings = total_ratings
      @updated_posts = updated_posts
    end

    def success?
      true
    end

    def failure?
      false
    end
  end

  class Failure
    attr_reader :errors

    def initialize(errors:)
      @errors = errors
    end

    def success?
      false
    end

    def failure?
      true
    end
  end

  class BatchSuccess
    attr_reader :ratings_count, :updated_posts

    def initialize(ratings_count:, updated_posts:)
      @ratings_count = ratings_count
      @updated_posts = updated_posts
    end

    def success?
      true
    end

    def failure?
      false
    end
  end

  class BatchFailure
    attr_reader :errors

    def initialize(errors:)
      @errors = errors
    end

    def success?
      false
    end

    def failure?
      true
    end
  end
end
