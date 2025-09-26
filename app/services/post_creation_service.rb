class PostCreationService
  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @title = params[:title]
    @body = params[:body]
    @login = params[:login]
    @ip = params[:ip]
  end

  def call
    user = find_or_create_user(@login)
    post = build_post(user)

    if post.save
      Success.new(post: post, user: user)
    else
      Failure.new(errors: post.errors.full_messages)
    end
  end

  private

  def find_or_create_user(login)
    User.find_or_create_by(login: login)
  end

  def build_post(user)
    user.posts.build(
      title: @title,
      body: @body,
      ip: @ip
    )
  end

  class Success
    attr_reader :post, :user

    def initialize(post:, user:)
      @post = post
      @user = user
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
end
