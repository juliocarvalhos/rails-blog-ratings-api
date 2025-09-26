require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:login) }

    describe 'uniqueness validation' do
      subject { build(:user) }

      it { is_expected.to validate_uniqueness_of(:login) }
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
    it { is_expected.to have_many(:ratings).dependent(:destroy) }
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'generates unique logins' do
      user1 = create(:user)
      user2 = create(:user)
      expect(user1.login).not_to eq(user2.login)
    end
  end
end
