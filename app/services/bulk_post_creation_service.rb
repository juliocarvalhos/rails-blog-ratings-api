class BulkPostCreationService
  def self.call(posts_data, batch_size: 1000)
    new(posts_data, batch_size: batch_size).call
  end

  def initialize(posts_data, batch_size: 1000)
    @posts_data = posts_data
    @batch_size = batch_size
  end

  def call
    return Failure.new(errors: [ "Posts data cannot be empty" ]) if @posts_data.empty?

    created_posts = []
    created_users = []
    errors = []

    @posts_data.each_slice(@batch_size) do |batch|
      result = process_batch(batch)
      if result.success?
        created_posts << result.posts # posts is an integer count
        created_users.concat(result.users) # users is an array of new logins
      else
        errors.concat(result.errors)
      end
    end

    if errors.empty?
      Success.new(
        posts: created_posts,
        users: created_users,
        total_posts: created_posts.sum, # Sum of counts from each batch
        total_users: created_users.uniq.length
      )
    else
      Failure.new(errors: errors)
    end
  end

  private

  def process_batch(batch)
    # Group posts by login to optimize user creation
    posts_by_login = batch.group_by { |post_data| post_data[:login] }
    logins = posts_by_login.keys

    # Find existing users and create new ones
    existing_users = User.where(login: logins).index_by(&:login)
    new_logins = logins - existing_users.keys

    if new_logins.any?
      new_user_data = new_logins.map do |login|
        {
          login: login,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      User.insert_all(new_user_data)
    end

    # Get all users for this batch
    all_users = User.where(login: logins).index_by(&:login)

    # Validate posts data first
    batch.each do |post_data|
      if post_data[:title].blank? || post_data[:body].blank? || post_data[:ip].blank?
        raise StandardError, "Validation failed: title, body, and ip are required"
      end
    end

    # Prepare posts data for bulk insert
    posts_to_create = batch.map do |post_data|
      user = all_users[post_data[:login]]
      {
        title: post_data[:title],
        body: post_data[:body],
        ip: post_data[:ip],
        user_id: user.id,
        avg_rating: 0.0,
        ratings_count: 0,
        ratings_sum: 0,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Bulk insert posts
    Post.insert_all(posts_to_create)

    # Return the created data (simplified for performance)
    BatchSuccess.new(
      posts: batch.length,
      users: new_logins
    )
  rescue StandardError => e
    BatchFailure.new(errors: [ e.message ])
  end

  class Success
    attr_reader :posts, :users, :total_posts, :total_users

    def initialize(posts:, users:, total_posts:, total_users:)
      @posts = posts
      @users = users
      @total_posts = total_posts
      @total_users = total_users
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
    attr_reader :posts, :users

    def initialize(posts:, users:)
      @posts = posts
      @users = users
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
