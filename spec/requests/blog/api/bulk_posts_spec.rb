require 'rails_helper'

RSpec.describe "Blog::Api::Posts Bulk Operations", type: :request do
  describe "POST /blog/api/posts/bulk_create" do
    context "with valid data" do
      scenario "creates multiple posts successfully" do
        valid_posts_data = build_valid_posts_data

        expect {
          post "/blog/api/posts/bulk_create", params: { posts: valid_posts_data }
        }.to change(Post, :count).by(2)
         .and change(User, :count).by(2)
      end

      scenario "returns created status" do
        valid_posts_data = build_valid_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: valid_posts_data }

        expect(response).to have_http_status(:created)
      end

      scenario "returns correct response data" do
        valid_posts_data = build_valid_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: valid_posts_data }

        expect(json_response['status']).to eq('created')
        expect(json_response['total_posts']).to eq(2)
        expect(json_response['total_users']).to eq(2)
      end

      scenario "creates users automatically" do
        valid_posts_data = build_valid_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: valid_posts_data }

        expect(User.find_by(login: "user1")).to be_present
        expect(User.find_by(login: "user2")).to be_present
      end

      scenario "handles existing users correctly" do
        create(:user, login: "user1")
        valid_posts_data = build_valid_posts_data

        expect {
          post "/blog/api/posts/bulk_create", params: { posts: valid_posts_data }
        }.to change(User, :count).by(1)
      end

      scenario "counts only new users created" do
        create(:user, login: "user1")
        valid_posts_data = build_valid_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: valid_posts_data }

        expect(json_response['total_users']).to eq(1)
      end

      scenario "respects custom batch size" do
        large_posts_data = build_large_posts_data

        post "/blog/api/posts/bulk_create", params: {
          posts: large_posts_data,
          batch_size: 25
        }

        expect(response).to have_http_status(:created)
      end

      scenario "returns correct batch size in response" do
        large_posts_data = build_large_posts_data

        post "/blog/api/posts/bulk_create", params: {
          posts: large_posts_data,
          batch_size: 25
        }

        expect(json_response['batch_size']).to eq(25)
        expect(json_response['total_posts']).to eq(50)
      end
    end

    context "with invalid data" do
      scenario "returns error for missing posts parameter" do
        post "/blog/api/posts/bulk_create", params: {}

        expect(response).to have_http_status(:unprocessable_entity)
      end

      scenario "returns appropriate error message for missing posts" do
        post "/blog/api/posts/bulk_create", params: {}

        expect(json_response['error']).to include('Missing required parameter')
      end

      scenario "returns error for empty posts array" do
        post "/blog/api/posts/bulk_create", params: { posts: [] }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      scenario "returns appropriate error message for empty posts" do
        post "/blog/api/posts/bulk_create", params: { posts: [] }

        expect(json_response['error']).to include('Posts data cannot be empty')
      end

      scenario "handles validation errors" do
        invalid_posts_data = build_invalid_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: invalid_posts_data }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to be_present
      end
    end

    context "when testing performance" do
      scenario "handles large batches efficiently" do
        large_posts_data = build_performance_posts_data

        start_time = Time.current
        post "/blog/api/posts/bulk_create", params: { posts: large_posts_data }
        end_time = Time.current

        expect(response).to have_http_status(:created)
      end

      scenario "creates correct number of posts and users" do
        large_posts_data = build_performance_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: large_posts_data }

        expect(json_response['total_posts']).to eq(100)
        expect(User.count).to eq(10)
      end

      scenario "creates correct number of unique IPs" do
        large_posts_data = build_performance_posts_data

        post "/blog/api/posts/bulk_create", params: { posts: large_posts_data }

        expect(Post.distinct.count(:ip)).to eq(5)
      end

      scenario "completes within reasonable time" do
        large_posts_data = build_performance_posts_data

        start_time = Time.current
        post "/blog/api/posts/bulk_create", params: { posts: large_posts_data }
        end_time = Time.current

        expect(end_time - start_time).to be < 2.0
      end
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end

  def build_valid_posts_data
    [
      {
        title: "First Post",
        body: "First post content",
        login: "user1",
        ip: "192.168.1.1"
      },
      {
        title: "Second Post",
        body: "Second post content",
        login: "user2",
        ip: "192.168.1.2"
      }
    ]
  end

  def build_invalid_posts_data
    [
      {
        title: "",
        body: "Content",
        login: "user1",
        ip: "192.168.1.1"
      }
    ]
  end

  def build_large_posts_data
    Array.new(50) do |i|
      {
        title: "Post #{i}",
        body: "Content #{i}",
        login: "user#{i}",
        ip: "192.168.1.#{i}"
      }
    end
  end

  def build_performance_posts_data
    Array.new(100) do |i|
      {
        title: "Performance Post #{i}",
        body: "Performance test content #{i}",
        login: "perf_user#{i % 10}",
        ip: "10.0.0.#{i % 5}"
      }
    end
  end
end
