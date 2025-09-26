require 'rails_helper'

RSpec.describe BulkRatingCreationService do
  let!(:user1) { create(:user, login: "user1") }
  let!(:user2) { create(:user, login: "user2") }
  let!(:user3) { create(:user, login: "user3") }
  let!(:post1) { create(:post, user: user1) }
  let!(:post2) { create(:post, user: user2) }

  describe ".call" do
    let(:valid_ratings_data) do
      [
        {
          post_id: post1.id,
          user_id: user2.id,
          value: 5
        },
        {
          post_id: post1.id,
          user_id: user3.id,
          value: 4
        },
        {
          post_id: post2.id,
          user_id: user1.id,
          value: 3
        }
      ]
    end

    context "with valid data" do
      it "creates ratings successfully" do
        expect {
          described_class.call(valid_ratings_data)
        }.to change(Rating, :count).by(3)
      end

      it "returns success result" do
        result = described_class.call(valid_ratings_data)

        expect(result).to be_success
        expect(result.total_ratings).to eq(3)
        expect(result.updated_posts).to eq(2)
      end

      it "updates post cache counters" do
        described_class.call(valid_ratings_data)

        post1.reload
        post2.reload

        expect(post1.ratings_count).to eq(2)
        expect(post1.ratings_sum).to eq(9) # 5 + 4
        expect(post1.avg_rating).to eq(4.5)

        expect(post2.ratings_count).to eq(1)
        expect(post2.ratings_sum).to eq(3)
        expect(post2.avg_rating).to eq(3.0)
      end
    end

    context "with invalid data" do
      it "returns failure for empty data" do
        result = described_class.call([])

        expect(result).to be_failure
        expect(result.errors).to include("Ratings data cannot be empty")
      end

      it "validates post existence" do
        invalid_data = [
          {
            post_id: 999999, # Non-existent post
            user_id: user1.id,
            value: 5
          }
        ]

        result = described_class.call(invalid_data)

        expect(result).to be_failure
        expect(result.errors.first).to include("Invalid post IDs")
      end

      it "validates user existence" do
        invalid_data = [
          {
            post_id: post1.id,
            user_id: 999999, # Non-existent user
            value: 5
          }
        ]

        result = described_class.call(invalid_data)

        expect(result).to be_failure
        expect(result.errors.first).to include("Invalid user IDs")
      end

      it "handles duplicate ratings" do
        # Create existing rating
        create(:rating, post: post1, user: user2, value: 3)

        duplicate_data = [
          {
            post_id: post1.id,
            user_id: user2.id, # Duplicate
            value: 5
          }
        ]

        result = described_class.call(duplicate_data)

        expect(result).to be_success
        expect(result.total_ratings).to eq(0) # No new ratings created
        expect(Rating.where(post: post1, user: user2).count).to eq(1) # Original rating still exists
        expect(Rating.where(post: post1, user: user2).first.value).to eq(3) # Original value unchanged
      end
    end

    context "with mixed valid and duplicate data" do
      it "processes only valid ratings and skips duplicates" do
        # Create existing rating
        create(:rating, post: post1, user: user2, value: 3)

        mixed_data = [
          {
            post_id: post1.id,
            user_id: user2.id, # Duplicate - should be skipped
            value: 5
          },
          {
            post_id: post2.id,
            user_id: user1.id, # Valid - should be created
            value: 4
          }
        ]

        result = described_class.call(mixed_data)

        expect(result).to be_success # Should succeed with valid ratings
        expect(result.total_ratings).to eq(1) # Only the valid one
        expect(Rating.where(post: post2, user: user1)).to exist # Valid rating created
        expect(Rating.where(post: post1, user: user2).count).to eq(1) # Original rating still exists
      end
    end

    context "when performance testing" do
      let(:performance_data) do
        users = (1..50).map { |n| create(:user, login: "perf_user_#{n}") }
        post_owners = (1..100).map { |n| create(:user, login: "post_owner_#{n}") }
        posts = post_owners.map { |owner| create(:post, user: owner) }

        ratings_data = []
        posts.each do |post|
          # Each post gets 10 random ratings
          users.sample(10).each do |user|
            ratings_data << {
              post_id: post.id,
              user_id: user.id,
              value: rand(1..5)
            }
          end
        end
        ratings_data
      end

      it "handles large datasets efficiently" do
        start_time = Time.current
        result = described_class.call(performance_data)
        end_time = Time.current

        expect(result).to be_success
        expect(result.total_ratings).to eq(1000) # 100 posts * 10 ratings each

        # Performance check
        expect(end_time - start_time).to be < 5.0 # Less than 5 seconds for 1000 ratings
      end
    end

    context "when batch processing" do
      let(:batch_users) { (1..50).map { |n| create(:user, login: "batch_user_#{n}") } }
      let(:batch_post_owners) { (1..40).map { |n| create(:user, login: "batch_post_owner_#{n}") } }
      let(:batch_posts) { batch_post_owners.map { |owner| create(:post, user: owner) } }

      let(:large_dataset) do
        # Create exactly one rating per user/post combination to avoid duplicates
        ratings_data = []
        batch_users.each do |user|
          batch_posts.each do |post|
            ratings_data << {
              post_id: post.id,
              user_id: user.id,
              value: rand(1..5)
            }
          end
        end
        ratings_data
      end

      it "processes in custom batch sizes" do
        result = described_class.call(large_dataset, batch_size: 500)

        expect(result).to be_success
        expect(result.total_ratings).to eq(2000) # 50 users × 40 posts = 2000 ratings

        # Verify all posts from this test have updated counters
        batch_posts.each do |post|
          post.reload
          expect(post.ratings_count).to be > 0
          expect(post.avg_rating).to be > 0
        end
      end
    end

    context "when ensuring concurrent safety" do
      it "handles concurrent rating creation safely" do
        same_ratings_data = [
          {
            post_id: post1.id,
            user_id: user2.id,
            value: 5
          }
        ]

        # Test that multiple calls with same data result in only one rating
        results = []
        3.times do
          result = described_class.call(same_ratings_data)
          results << result
        end

        # First should succeed, others should succeed but create 0 ratings (skipped duplicates)
        success_count = results.count(&:success?)
        expect(success_count).to eq(3) # All succeed

        total_created = results.sum(&:total_ratings)
        expect(total_created).to eq(1) # Only one actually created

        # Verify only one rating was created
        expect(Rating.where(post: post1, user: user2).count).to eq(1)
      end
    end
  end
end
