class RatingCreationService
  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @post_id = params[:post_id]
    @user_id = params[:user_id]
    @value = params[:value]
  end

  def call
    post = Post.find(@post_id)
    user = User.find(@user_id)

    if rating_exists?(post, user)
      return Failure.new(error: "User has already rated this post")
    end

    rating = build_rating(post, user)

    begin
      if rating.save
        post.reload
        Success.new(rating: rating, avg_rating: post.calculated_avg_rating)
      else
        Failure.new(error: rating.errors.full_messages.join(", "))
      end
    rescue ActiveRecord::RecordNotUnique
      Failure.new(error: "User has already rated this post")
    end
  end

  private

  def rating_exists?(post, user)
    Rating.exists?(post: post, user: user)
  end

  def build_rating(post, user)
    Rating.new(
      post: post,
      user: user,
      value: @value
    )
  end

  class Success
    attr_reader :rating, :avg_rating

    def initialize(rating:, avg_rating:)
      @rating = rating
      @avg_rating = avg_rating
    end

    def success?
      true
    end

    def failure?
      false
    end
  end

  class Failure
    attr_reader :error

    def initialize(error:)
      @error = error
    end

    def success?
      false
    end

    def failure?
      true
    end
  end
end
