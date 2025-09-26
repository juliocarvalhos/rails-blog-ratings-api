require 'rails_helper'

RSpec.describe BulkPostCreationService do
  describe ".call" do
    let(:valid_posts_data) do
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

    context "with valid data" do
      it "creates posts successfully" do
        expect {
          described_class.call(valid_posts_data)
        }.to change(Post, :count).by(2)
         .and change(User, :count).by(2)
      end

      it "returns success result" do
        result = described_class.call(valid_posts_data)

        expect(result).to be_success
        expect(result.total_posts).to eq(2)
        expect(result.total_users).to eq(2)
      end

      it "creates users automatically" do
        described_class.call(valid_posts_data)

        expect(User.find_by(login: "user1")).to be_present
        expect(User.find_by(login: "user2")).to be_present
      end

      it "handles existing users correctly" do
        create(:user, login: "user1")

        expect {
          described_class.call(valid_posts_data)
        }.to change(User, :count).by(1) # Only creates user2
      end

      it "sets default values for posts" do
        described_class.call(valid_posts_data)

        posts = Post.all
        expect(posts.all? { |p| p.avg_rating == 0.0 }).to be true
        expect(posts.all? { |p| p.ratings_count == 0 }).to be true
        expect(posts.all? { |p| p.ratings_sum == 0 }).to be true
      end
    end

    context "with custom batch size" do
      let(:large_dataset) do
        Array.new(2500) do |i|
          {
            title: "Post #{i}",
            body: "Content #{i}",
            login: "user#{i % 10}", # 10 users, 250 posts each
            ip: "192.168.#{i % 256}.#{(i / 256) % 256}"
          }
        end
      end

      it "processes in batches" do
        result = described_class.call(large_dataset, batch_size: 500)

        expect(result).to be_success
        expect(result.total_posts).to eq(2500)
        expect(User.count).to eq(10)
      end
    end

    context "with invalid data" do
      it "returns failure for empty data" do
        result = described_class.call([])

        expect(result).to be_failure
        expect(result.errors).to include("Posts data cannot be empty")
      end

      it "handles validation errors" do
        invalid_data = [
          {
            title: "", # Invalid - empty title
            body: "Content",
            login: "user1",
            ip: "192.168.1.1"
          }
        ]

        result = described_class.call(invalid_data)

        expect(result).to be_failure
        expect(result.errors).to be_present
      end
    end

    context "performance testing" do
      let(:performance_dataset) do
        Array.new(1000) do |i|
          {
            title: "Performance Post #{i}",
            body: "Performance content #{i}",
            login: "perf_user#{i % 20}", # 20 users
            ip: "10.0.#{i % 10}.#{(i / 10) % 256}" # Various IPs
          }
        end
      end

      it "handles large datasets efficiently" do
        start_time = Time.current
        result = described_class.call(performance_dataset)
        end_time = Time.current

        expect(result).to be_success
        expect(result.total_posts).to eq(1000)
        expect(User.count).to eq(20)

        # Should be much faster than individual creation
        expect(end_time - start_time).to be < 3.0 # Less than 3 seconds
      end
    end

    context "database constraints" do
      it "handles unique constraint violations gracefully" do
        # This tests edge cases where duplicate data might cause issues
        duplicate_user_data = [
          {
            title: "Post 1",
            body: "Content 1",
            login: "duplicate_user",
            ip: "192.168.1.1"
          },
          {
            title: "Post 2",
            body: "Content 2",
            login: "duplicate_user", # Same user
            ip: "192.168.1.2"
          }
        ]

        expect {
          described_class.call(duplicate_user_data)
        }.to change(User, :count).by(1) # Only one user created
         .and change(Post, :count).by(2) # Both posts created

        user = User.find_by(login: "duplicate_user")
        expect(user.posts.count).to eq(2)
      end
    end
  end
end
