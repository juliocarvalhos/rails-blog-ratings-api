class Blog::Api::PostsController < Blog::Api::BaseController
  def create
    result = PostCreationService.call(post_params)

    if result.success?
      render_success(
        {
          post: {
            id: result.post.id,
            title: result.post.title,
            body: result.post.body,
            ip: result.post.ip.to_s,
            avg_rating: result.post.avg_rating,
            created_at: result.post.created_at,
            updated_at: result.post.updated_at
          },
          user: {
            id: result.user.id,
            login: result.user.login,
            created_at: result.user.created_at,
            updated_at: result.user.updated_at
          }
        },
        :created
      )
    else
      render_error(result.errors.join(", "))
    end
  end

  def bulk_create
    posts_data = params.require(:posts).map do |post_params|
      post_params.permit(:title, :body, :login, :ip).to_h.symbolize_keys
    end

    batch_size = params[:batch_size]&.to_i || 1000

    result = BulkPostCreationService.call(posts_data, batch_size: batch_size)

    if result.success?
      render_success(
        {
          status: "created",
          total_posts: result.total_posts,
          total_users: result.total_users,
          batch_size: batch_size
        },
        :created
      )
    else
      render_error(result.errors.join(", "))
    end
  rescue ActionController::ParameterMissing => e
    render_error("Missing required parameter: #{e.param}")
  end

  def top
    limit = params[:limit] || 10
    limit = limit.to_i.clamp(1, 100)

    # Use database function for improved performance
    if params[:use_function] == "true"
      posts_data = Post.top_rated_via_function(limit)
      render_success(
        posts_data.map do |post|
          {
            id: post["id"],
            title: post["title"],
            body: post["body"]
          }
        end
      )
    else
      # Use ActiveRecord approach (cache counters)
      posts = Post.top_rated(limit).includes(:user)
      render_success(
        posts.map do |post|
          {
            id: post.id,
            title: post.title,
            body: post.body
          }
        end
      )
    end
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :login, :ip)
  end
end
