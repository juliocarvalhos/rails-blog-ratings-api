require 'rails_helper'

RSpec.feature 'Blog API Post Creation', type: :request do
  scenario 'User creates a new blog post successfully' do
    post_data = build_valid_post_data

    post '/blog/api/posts', params: post_data, as: :json

    expect(response).to have_http_status(:created)
  end

  scenario 'Created post has correct title and body' do
    post_data = build_valid_post_data

    post '/blog/api/posts', params: post_data, as: :json
    response_data = JSON.parse(response.body)

    expect(response_data['post']['title']).to eq('My First Blog Post')
    expect(response_data['post']['body']).to include('insights')
  end

  scenario 'Created post has correct user information' do
    post_data = build_valid_post_data

    post '/blog/api/posts', params: post_data, as: :json
    response_data = JSON.parse(response.body)

    expect(response_data['user']['login']).to eq('john_blogger')
  end

  scenario 'User is auto-created during post creation' do
    post_data = build_valid_post_data

    post '/blog/api/posts', params: post_data, as: :json

    expect(User.find_by(login: 'john_blogger')).to be_present
  end

  scenario 'Post exists in database after creation' do
    post_data = build_valid_post_data

    post '/blog/api/posts', params: post_data, as: :json
    response_data = JSON.parse(response.body)

    created_post = Post.find(response_data['post']['id'])
    expect(created_post.title).to eq('My First Blog Post')
  end

  context 'when multiple users post from same IP' do
    scenario 'Both posts are created successfully' do
      create_posts_from_same_ip

      expect(response).to have_http_status(:created)
    end

    scenario 'Both users are created' do
      create_posts_from_same_ip

      expect(User.count).to eq(2)
    end

    scenario 'Both posts are created' do
      create_posts_from_same_ip

      expect(Post.count).to eq(2)
    end

    scenario 'Posts share the same IP address' do
      create_posts_from_same_ip

      expect(Post.pluck(:ip).uniq).to eq([ '192.168.1.200/32' ])
    end

    private

    def create_posts_from_same_ip
      first_post = build_first_user_post_data
      second_post = build_second_user_post_data

      post '/blog/api/posts', params: first_post, as: :json
      post '/blog/api/posts', params: second_post, as: :json
    end

    def build_first_user_post_data
      {
        post: {
          title: 'First Post',
          body: 'Content from first user',
          login: 'user_one',
          ip: '192.168.1.200'
        }
      }
    end

    def build_second_user_post_data
      {
        post: {
          title: 'Second Post',
          body: 'Content from second user',
          login: 'user_two',
          ip: '192.168.1.200'
        }
      }
    end
  end

  context 'when post creation fails' do
    scenario 'Returns error status for invalid data' do
      invalid_data = build_invalid_post_data

      post '/blog/api/posts', params: invalid_data, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    scenario 'Returns error message for invalid data' do
      invalid_data = build_invalid_post_data

      post '/blog/api/posts', params: invalid_data, as: :json
      error_data = JSON.parse(response.body)

      expect(error_data['error']).to include("can't be blank")
    end

    scenario 'No post is created when validation fails' do
      invalid_data = build_invalid_post_data

      post '/blog/api/posts', params: invalid_data, as: :json

      expect(Post.count).to eq(0)
    end

    private

    def build_invalid_post_data
      {
        post: {
          title: '',
          body: 'Content without title',
          login: 'test_user',
          ip: '192.168.1.300'
        }
      }
    end
  end

  context 'when using service-based post creation' do
    scenario 'Service handles creation properly' do
      post_data = build_service_test_post_data

      post '/blog/api/posts', params: post_data, as: :json

      expect(response).to have_http_status(:created)
    end

    scenario 'Service logic maintains default values' do
      post_data = build_service_test_post_data

      post '/blog/api/posts', params: post_data, as: :json
      created_post = Post.last

      expect(created_post.avg_rating).to eq(0.0)
      expect(created_post.ratings_count).to eq(0)
      expect(created_post.ratings_sum).to eq(0)
    end

    private

    def build_service_test_post_data
      {
        post: {
          title: 'Service Integration Test',
          body: 'Testing service object integration',
          login: 'service_user',
          ip: '10.0.0.1'
        }
      }
    end
  end

  private

  def build_valid_post_data
    {
      post: {
        title: 'My First Blog Post',
        body: 'This is the content of my blog post with some insights.',
        login: 'john_blogger',
        ip: '192.168.1.100'
      }
    }
  end
end
