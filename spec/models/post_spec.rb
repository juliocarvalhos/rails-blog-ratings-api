require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:ip) }
    it { is_expected.to validate_numericality_of(:avg_rating).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(5) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:ratings).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:post1) { create(:post, avg_rating: 4.5) }
    let!(:post2) { create(:post, avg_rating: 3.0) }
    let!(:post3) { create(:post, avg_rating: 5.0) }

    describe '.top_rated' do
      it 'returns posts ordered by avg_rating descending' do
        top_posts = described_class.top_rated(2)
        expect(top_posts.first).to eq(post3)
        expect(top_posts.second).to eq(post1)
        expect(top_posts.count).to eq(2)
      end
    end
  end

  describe '#update_avg_rating!' do
    let(:post) { create(:post) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    context 'with no ratings' do
      it 'sets avg_rating to 0' do
        post.update_avg_rating!
        expect(post.avg_rating).to eq(0)
      end
    end

    context 'with one rating' do
      it 'sets avg_rating to that rating value' do
        create(:rating, post: post, user: user1, value: 4)
        post.update_avg_rating!
        expect(post.avg_rating).to eq(4.0)
      end
    end

    context 'with multiple ratings' do
      it 'calculates correct average' do
        create(:rating, post: post, user: user1, value: 4)
        create(:rating, post: post, user: user2, value: 2)
        post.update_avg_rating!
        expect(post.avg_rating).to eq(3.0)
      end
    end
  end
end
