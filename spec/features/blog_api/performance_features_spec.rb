require 'rails_helper'

RSpec.feature 'Blog API Performance Features', type: :request do
  let!(:users) { create_list(:user, 5) }
  let!(:posts) { create_list(:post, 10) }

  scenario 'Top posts endpoint returns success' do
    setup_posts_with_ratings
    get '/blog/api/posts/top', params: { limit: 3 }

    expect(response).to have_http_status(:ok)
  end

  scenario 'Top posts endpoint returns correct number of results' do
    setup_posts_with_ratings
    get '/blog/api/posts/top', params: { limit: 3 }

    posts_data = JSON.parse(response.body)
    expect(posts_data.length).to eq(3)
  end

  scenario 'Top posts are ordered by rating descending' do
    setup_posts_with_ratings
    get '/blog/api/posts/top', params: { limit: 3 }

    posts_data = JSON.parse(response.body)
    ratings = posts_data.map { |p| Post.find(p['id']).calculated_avg_rating }
    expect(ratings).to eq(ratings.sort.reverse)
  end

  scenario 'Top post has highest rating' do
    setup_posts_with_ratings
    get '/blog/api/posts/top', params: { limit: 3 }

    posts_data = JSON.parse(response.body)
    ratings = posts_data.map { |p| Post.find(p['id']).calculated_avg_rating }
    expect(ratings.first).to eq(5.0)
  end

  scenario 'Database function approach returns success' do
    setup_posts_with_ratings
    get '/blog/api/posts/top', params: { limit: 5, use_function: 'true' }

    expect(response).to have_http_status(:ok)
  end

  scenario 'Database function and cache approaches return consistent results' do
    setup_posts_with_ratings
    get '/blog/api/posts/top', params: { limit: 5, use_function: 'true' }
    db_results = JSON.parse(response.body)

    get '/blog/api/posts/top', params: { limit: 5 }
    cache_results = JSON.parse(response.body)

    db_ids = db_results.map { |p| p['id'] }
    cache_ids = cache_results.map { |p| p['id'] }
    expect(db_ids).to eq(cache_ids)
  end

  context 'when analyzing shared IP addresses' do
    let(:shared_ip) { '192.168.1.100' }

    before do
      create(:post, user: users[0], ip: shared_ip, title: 'Post from User 1')
      create(:post, user: users[1], ip: shared_ip, title: 'Post from User 2')
      create(:post, user: users[2], ip: '192.168.1.200', title: 'Post from User 3')
    end

    scenario 'IP analysis endpoint returns success' do
      get '/blog/api/ips'
      expect(response).to have_http_status(:ok)
    end

    scenario 'IP analysis identifies shared IPs' do
      get '/blog/api/ips'
      ips_data = JSON.parse(response.body)
      shared_ip_data = ips_data.find { |ip| ip['ip'].include?(shared_ip) }

      expect(shared_ip_data).to be_present
    end

    scenario 'IP analysis includes all authors for shared IP' do
      get '/blog/api/ips'
      ips_data = JSON.parse(response.body)
      shared_ip_data = ips_data.find { |ip| ip['ip'].include?(shared_ip) }

      expect(shared_ip_data['authors']).to include(users[0].login)
      expect(shared_ip_data['authors']).to include(users[1].login)
      expect(shared_ip_data['authors'].length).to eq(2)
    end
  end

  context 'when using database function for IP analysis' do
    let(:test_shared_ip) { '10.0.0.1' }

    before do
      create(:post, user: users[0], ip: test_shared_ip)
      create(:post, user: users[1], ip: test_shared_ip)
    end

    scenario 'database function and ActiveRecord return same count' do
      get '/blog/api/ips', params: { use_function: 'true' }
      db_results = JSON.parse(response.body)

      get '/blog/api/ips'
      ar_results = JSON.parse(response.body)

      expect(db_results.length).to eq(ar_results.length)
    end

    scenario 'both approaches identify same IPs when data exists' do
      get '/blog/api/ips', params: { use_function: 'true' }
      db_results = JSON.parse(response.body)

      get '/blog/api/ips'
      ar_results = JSON.parse(response.body)

      if db_results.any?
        db_ips = db_results.map { |r| r['ip'] }.sort
        ar_ips = ar_results.map { |r| r['ip'] }.sort
        expect(db_ips).to eq(ar_ips)
      end
    end
  end

  context 'when testing cache counter accuracy under load' do
    let(:test_post) { create(:post, user: users[0]) }
    let(:ratings_to_add) { [ 5, 4, 3, 5, 4 ] }

    scenario 'all rating creation requests succeed' do
      ratings_to_add.each_with_index do |value, index|
        rating_data = {
          rating: {
            post_id: test_post.id,
            user_id: users[index].id,
            value: value
          }
        }
        post '/blog/api/ratings', params: rating_data, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    scenario 'cache counters maintain correct count' do
      create_test_ratings_for_post
      test_post.reload
      expect(test_post.ratings_count).to eq(5)
    end

    scenario 'cache counters maintain correct sum' do
      create_test_ratings_for_post
      test_post.reload
      expect(test_post.ratings_sum).to eq(21)
    end

    scenario 'cache counters calculate correct average' do
      create_test_ratings_for_post
      test_post.reload
      expect(test_post.calculated_avg_rating).to eq(4.2)
    end

    scenario 'database function matches cache counter' do
      create_test_ratings_for_post
      test_post.reload
      db_avg = test_post.avg_rating_via_function
      expect(db_avg).to be_within(0.01).of(4.2)
    end

    private

    def create_test_ratings_for_post
      ratings_to_add.each_with_index do |value, index|
        rating_data = {
          rating: {
            post_id: test_post.id,
            user_id: users[index].id,
            value: value
          }
        }
        post '/blog/api/ratings', params: rating_data, as: :json
      end
    end
  end

  private

  def setup_posts_with_ratings
    create(:rating, post: posts[0], user: users[0], value: 5)
    create(:rating, post: posts[0], user: users[1], value: 5)
    create(:rating, post: posts[1], user: users[0], value: 4)
    create(:rating, post: posts[1], user: users[1], value: 4)
    create(:rating, post: posts[1], user: users[2], value: 5)
    create(:rating, post: posts[2], user: users[0], value: 3)
  end
end
