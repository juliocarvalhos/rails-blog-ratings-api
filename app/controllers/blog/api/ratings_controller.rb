class Blog::Api::RatingsController < Blog::Api::BaseController
  def create
    result = RatingCreationService.call(rating_params)

    if result.success?
      render_success(
        {
          rating: {
            id: result.rating.id,
            post_id: result.rating.post_id,
            user_id: result.rating.user_id,
            value: result.rating.value,
            created_at: result.rating.created_at,
            updated_at: result.rating.updated_at
          },
          avg_rating: result.avg_rating
        },
        :created
      )
    else
      status = result.error.include?("already rated") ? :conflict : :unprocessable_entity
      render_error(result.error, status)
    end
  end

  def bulk_create
    ratings_param = params.require(:ratings)

    # Handle empty arrays (Rails converts them to empty string arrays sometimes)
    if ratings_param.is_a?(Array) && ratings_param.empty?
      return render_error("Ratings data cannot be empty", :unprocessable_entity)
    elsif ratings_param.is_a?(String) && ratings_param.empty?
      return render_error("Ratings data cannot be empty", :unprocessable_entity)
    end

    # Ensure we have an array
    ratings_array = ratings_param.is_a?(Array) ? ratings_param : [ ratings_param ]

    # Filter out any empty or invalid elements
    ratings_array = ratings_array.reject { |r| r.blank? || (r.is_a?(String) && r.empty?) }

    if ratings_array.empty?
      return render_error("Ratings data cannot be empty", :unprocessable_entity)
    end

    ratings_data = ratings_array.map do |rating_params|
      if rating_params.respond_to?(:permit)
        rating_params.permit(:post_id, :user_id, :value).to_h.symbolize_keys
      elsif rating_params.respond_to?(:to_h)
        # Handle case where parameters come as hash
        rating_params.to_h.symbolize_keys.slice(:post_id, :user_id, :value)
      else
        # Skip invalid elements
        next
      end
    end.compact

    if ratings_data.empty?
      return render_error("Ratings data cannot be empty", :unprocessable_entity)
    end

    batch_size = params[:batch_size]&.to_i || 1000

    result = BulkRatingCreationService.call(ratings_data, batch_size: batch_size)

    if result.success?
      render_success(
        {
          status: "created",
          total_ratings: result.total_ratings,
          updated_posts: result.updated_posts,
          batch_size: batch_size
        },
        :created
      )
    else
      render_error(result.errors.join(", "), :unprocessable_entity)
    end
  rescue ActionController::ParameterMissing => e
    render_error("Missing required parameter: #{e.param}", :unprocessable_entity)
  end

  private

  def rating_params
    params.require(:rating).permit(:post_id, :user_id, :value)
  end
end
