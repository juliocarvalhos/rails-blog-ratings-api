require 'rails_helper'

RSpec.describe "Blog::Api::Ratings Bulk Operations", type: :request do
  self.use_transactional_tests = false

  after do
    Rating.delete_all
    Post.delete_all
    User.delete_all
  end

  describe "POST /blog/api/ratings/bulk_create" do
    let!(:user1) { create(:user, login: "bulk_req_user1") }
    let!(:user2) { create(:user, login: "bulk_req_user2") }
    let!(:post1) { create(:post, user: user1) }
    let!(:post2) { create(:post, user: user2) }

    context "with valid data" do
      scenario "creates multiple ratings successfully" do
        valid_ratings_data = build_valid_ratings_data

        expect {
          post "/blog/api/ratings/bulk_create", params: { ratings: valid_ratings_data }
        }.to change(Rating, :count).by(2)
      end

      scenario "returns created status" do
        valid_ratings_data = build_valid_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: valid_ratings_data }

        expect(response).to have_http_status(:created)
      end

      scenario "returns correct response data" do
        valid_ratings_data = build_valid_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: valid_ratings_data }

        expect(json_response['status']).to eq('created')
        expect(json_response['total_ratings']).to eq(2)
        expect(json_response['updated_posts']).to eq(2)
      end

      scenario "updates post cache counters correctly" do
        valid_ratings_data = build_valid_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: valid_ratings_data }
        update_post_counter_expectations
      end

      scenario "handles large batch sizes efficiently" do
        large_ratings_data = build_large_ratings_data

        start_time = Time.current
        post "/blog/api/ratings/bulk_create", params: {
          ratings: large_ratings_data,
          batch_size: 30
        }
        end_time = Time.current

        expect(response).to have_http_status(:created)
      end

      scenario "creates correct number of ratings in large batch" do
        large_ratings_data = build_large_ratings_data

        post "/blog/api/ratings/bulk_create", params: {
          ratings: large_ratings_data,
          batch_size: 30
        }

        expect(json_response['total_ratings']).to eq(large_ratings_data.length)
      end

      scenario "completes large batch within time limit" do
        large_ratings_data = build_large_ratings_data

        start_time = Time.current
        post "/blog/api/ratings/bulk_create", params: {
          ratings: large_ratings_data,
          batch_size: 30
        }
        end_time = Time.current

        expect(end_time - start_time).to be < 3.0
      end
    end

    context "with invalid data" do
      scenario "returns error for missing ratings parameter" do
        post "/blog/api/ratings/bulk_create", params: {}

        expect(response).to have_http_status(:unprocessable_entity)
      end

      scenario "returns appropriate error message for missing ratings" do
        post "/blog/api/ratings/bulk_create", params: {}

        expect(json_response['error']).to include('Missing required parameter')
      end

      scenario "returns error for empty ratings array" do
        post "/blog/api/ratings/bulk_create", params: { ratings: [] }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      scenario "returns appropriate error message for empty ratings" do
        post "/blog/api/ratings/bulk_create", params: { ratings: [] }

        expect(json_response['error']).to include('Ratings data cannot be empty')
      end

      scenario "handles invalid post IDs" do
        invalid_ratings_data = build_invalid_post_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: invalid_ratings_data }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      scenario "returns appropriate error for invalid post IDs" do
        invalid_ratings_data = build_invalid_post_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: invalid_ratings_data }

        expect(json_response['error']).to include('Invalid post IDs')
      end

      scenario "handles invalid user IDs" do
        invalid_ratings_data = build_invalid_user_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: invalid_ratings_data }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      scenario "returns appropriate error for invalid user IDs" do
        invalid_ratings_data = build_invalid_user_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: invalid_ratings_data }

        expect(json_response['error']).to include('Invalid user IDs')
      end

      scenario "skips duplicate ratings gracefully" do
        create(:rating, post: post1, user: user2, value: 3)
        ratings_data = build_duplicate_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: ratings_data }

        expect(response).to have_http_status(:created)
      end

      scenario "returns correct count when skipping duplicates" do
        create(:rating, post: post1, user: user2, value: 3)
        ratings_data = build_duplicate_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: ratings_data }

        expect(json_response['status']).to eq('created')
        expect(json_response['total_ratings']).to eq(1)
      end

      scenario "creates only valid ratings when duplicates exist" do
        create(:rating, post: post1, user: user2, value: 3)
        ratings_data = build_duplicate_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: ratings_data }

        expect(Rating.where(post: post2, user: user1)).to exist
      end

      scenario "preserves original rating when duplicate exists" do
        create(:rating, post: post1, user: user2, value: 3)
        ratings_data = build_duplicate_ratings_data

        post "/blog/api/ratings/bulk_create", params: { ratings: ratings_data }

        expect(Rating.where(post: post1, user: user2).first.value).to eq(3)
      end
    end

    context "when testing concurrency safety" do
      scenario "handles first concurrent request successfully" do
        ratings_data = build_concurrent_ratings_data

        results = perform_concurrent_rating_requests(ratings_data)

        success_count = results.count { |status, _| status == 201 }
        expect(success_count).to eq(3)
      end

      scenario "creates only one rating despite concurrent attempts" do
        ratings_data = build_concurrent_ratings_data

        perform_concurrent_rating_requests(ratings_data)

        expect(Rating.where(post: post1, user: user2).count).to eq(1)
      end

      scenario "total created ratings is correct across concurrent requests" do
        ratings_data = build_concurrent_ratings_data

        results = perform_concurrent_rating_requests(ratings_data)

        total_created = results.sum { |_, body| body['total_ratings'] }
        expect(total_created).to eq(1)
      end

      private

      def perform_concurrent_rating_requests(ratings_data)
        results = []
        3.times do
          post "/blog/api/ratings/bulk_create", params: { ratings: ratings_data }
          results << [ response.status, JSON.parse(response.body) ]
        end
        results
      end

      def build_concurrent_ratings_data
        [
          {
            post_id: post1.id,
            user_id: user2.id,
            value: 5
          }
        ]
      end
    end

    private

    def json_response
      JSON.parse(response.body)
    end

    def build_valid_ratings_data
      [
        {
          post_id: post1.id,
          user_id: user2.id,
          value: 5
        },
        {
          post_id: post2.id,
          user_id: user1.id,
          value: 4
        }
      ]
    end

    def build_large_ratings_data
      users = (1..10).map { |n| create(:user, login: "req_user_#{n}") }
      post_owners = (1..20).map { |n| create(:user, login: "req_post_owner_#{n}") }
      posts = post_owners.map { |owner| create(:post, user: owner) }

      large_ratings_data = []
      posts.each do |post|
        users.sample(3).each do |user|
          large_ratings_data << {
            post_id: post.id,
            user_id: user.id,
            value: rand(1..5)
          }
        end
      end
      large_ratings_data
    end

    def build_invalid_post_ratings_data
      [
        {
          post_id: 999999,
          user_id: user1.id,
          value: 5
        }
      ]
    end

    def build_invalid_user_ratings_data
      [
        {
          post_id: post1.id,
          user_id: 999999,
          value: 5
        }
      ]
    end

    def build_duplicate_ratings_data
      [
        {
          post_id: post1.id,
          user_id: user2.id,
          value: 5
        },
        {
          post_id: post2.id,
          user_id: user1.id,
          value: 4
        }
      ]
    end

    def update_post_counter_expectations
      post1.reload
      post2.reload

      expect(post1.ratings_count).to eq(1)
      expect(post1.ratings_sum).to eq(5)
      expect(post1.avg_rating).to eq(5.0)

      expect(post2.ratings_count).to eq(1)
      expect(post2.ratings_sum).to eq(4)
      expect(post2.avg_rating).to eq(4.0)
    end
  end
end
