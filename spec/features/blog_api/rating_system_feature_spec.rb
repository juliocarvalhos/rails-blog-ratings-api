require 'rails_helper'

RSpec.feature 'Blog API Rating System', type: :request do
  let!(:first_user) { create(:user, login: 'rater_one') }
  let!(:second_user) { create(:user, login: 'rater_two') }
  let!(:post1) { create(:post, title: 'Great Post', user: first_user) }

  scenario 'User successfully rates a blog post' do
    rating_data = build_valid_rating_data

    post '/blog/api/ratings', params: rating_data, as: :json

    expect(response).to have_http_status(:created)
  end

  scenario 'Rating response contains correct value' do
    rating_data = build_valid_rating_data

    post '/blog/api/ratings', params: rating_data, as: :json
    response_data = JSON.parse(response.body)

    expect(response_data['rating']['value']).to eq(5)
  end

  scenario 'Rating response contains correct average' do
    rating_data = build_valid_rating_data

    post '/blog/api/ratings', params: rating_data, as: :json
    response_data = JSON.parse(response.body)

    expect(response_data['avg_rating']).to eq(5.0)
  end

  scenario 'Post counters are updated after rating' do
    rating_data = build_valid_rating_data

    post '/blog/api/ratings', params: rating_data, as: :json
    post1.reload

    expect(post1.ratings_count).to eq(1)
    expect(post1.ratings_sum).to eq(5)
    expect(post1.calculated_avg_rating).to eq(5.0)
  end

  context 'when multiple users rate same post' do
    scenario 'Both rating requests succeed' do
      create_multiple_ratings_for_post

      expect(response).to have_http_status(:created)
    end

    scenario 'Post has correct ratings count' do
      create_multiple_ratings_for_post
      post1.reload

      expect(post1.ratings_count).to eq(2)
    end

    scenario 'Post has correct ratings sum' do
      create_multiple_ratings_for_post
      post1.reload

      expect(post1.ratings_sum).to eq(6)
    end

    scenario 'Post has correct average rating' do
      create_multiple_ratings_for_post
      post1.reload

      expect(post1.calculated_avg_rating).to eq(3.0)
    end

    private

    def create_multiple_ratings_for_post
      first_rating = build_first_user_rating_data
      second_rating = build_second_user_rating_data

      post '/blog/api/ratings', params: first_rating, as: :json
      post '/blog/api/ratings', params: second_rating, as: :json
    end

    def build_first_user_rating_data
      {
        rating: {
          post_id: post1.id,
          user_id: first_user.id,
          value: 4
        }
      }
    end

    def build_second_user_rating_data
      {
        rating: {
          post_id: post1.id,
          user_id: second_user.id,
          value: 2
        }
      }
    end
  end

  context 'when user attempts duplicate rating' do
    before do
      create(:rating, post: post1, user: first_user, value: 3)
    end

    scenario 'Request is rejected with conflict status' do
      duplicate_rating = build_duplicate_rating_data

      post '/blog/api/ratings', params: duplicate_rating, as: :json

      expect(response).to have_http_status(:conflict)
    end

    scenario 'Returns appropriate error message' do
      duplicate_rating = build_duplicate_rating_data

      post '/blog/api/ratings', params: duplicate_rating, as: :json
      error_data = JSON.parse(response.body)

      expect(error_data['error']).to include('already rated')
    end

    scenario 'No additional rating is created' do
      duplicate_rating = build_duplicate_rating_data

      post '/blog/api/ratings', params: duplicate_rating, as: :json

      expect(post1.ratings.count).to eq(1)
    end

    private

    def build_duplicate_rating_data
      {
        rating: {
          post_id: post1.id,
          user_id: first_user.id,
          value: 5
        }
      }
    end
  end

  context 'when using database function for rating calculation' do
    before do
      create(:rating, post: post1, user: first_user, value: 5)
      create(:rating, post: post1, user: second_user, value: 3)
    end

    scenario 'Database function calculates ratings accurately' do
      db_avg_rating = post1.avg_rating_via_function

      expect(db_avg_rating).to eq(4.0)
    end

    scenario 'Database function matches cache counters' do
      cache_avg_rating = post1.calculated_avg_rating
      db_avg_rating = post1.avg_rating_via_function

      expect(db_avg_rating).to be_within(0.01).of(cache_avg_rating)
    end
  end

  context 'when testing concurrent request safety' do
    scenario 'Service handles first concurrent request successfully' do
      rating_params = build_rating_service_params

      first_result = RatingCreationService.call(rating_params)

      expect(first_result.success?).to be true
    end

    scenario 'Service rejects duplicate concurrent request' do
      rating_params = build_rating_service_params

      RatingCreationService.call(rating_params)
      second_result = RatingCreationService.call(rating_params)

      expect(second_result.failure?).to be true
      expect(second_result.error).to include('already rated')
    end

    scenario 'Only one rating exists after concurrent attempts' do
      rating_params = build_rating_service_params

      RatingCreationService.call(rating_params)
      RatingCreationService.call(rating_params)

      expect(Rating.where(post: post1, user: first_user).count).to eq(1)
    end

    private

    def build_rating_service_params
      {
        post_id: post1.id,
        user_id: user1.id,
        value: 4
      }
    end
  end

  private

  def build_valid_rating_data
    {
      rating: {
        post_id: post1.id,
        user_id: user2.id,
        value: 5
      }
    }
  end
end
