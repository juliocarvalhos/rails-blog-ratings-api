require 'rails_helper'

RSpec.describe Rating, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_inclusion_of(:value).in_range(1..5) }

    describe 'uniqueness validation' do
      let(:user) { create(:user) }
      let(:post) { create(:post) }

      it 'validates uniqueness of user_id scoped to post_id' do
        create(:rating, user: user, post: post, value: 5)
        duplicate_rating = build(:rating, user: user, post: post, value: 3)
        expect(duplicate_rating).not_to be_valid
        expect(duplicate_rating.errors[:user_id]).to include('has already been taken')
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:post) }
  end

  describe 'callbacks' do
    let(:post) { create(:post) }
    let(:user) { create(:user) }

    it 'updates post avg_rating after create' do
      expect(post).to receive(:update_avg_rating!).once
      create(:rating, post: post, user: user, value: 4)
    end

    it 'updates post avg_rating after update' do
      rating = create(:rating, post: post, user: user, value: 4)
      expect(post).to receive(:update_avg_rating!).once
      rating.update(value: 5)
    end

    it 'updates post avg_rating after destroy' do
      rating = create(:rating, post: post, user: user, value: 4)
      expect(post).to receive(:update_avg_rating!).once
      rating.destroy
    end
  end
end
