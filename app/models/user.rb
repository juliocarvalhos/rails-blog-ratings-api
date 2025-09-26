class User < ApplicationRecord
  validates :login, presence: true, uniqueness: true

  has_many :posts, dependent: :destroy
  has_many :ratings, dependent: :destroy
end
