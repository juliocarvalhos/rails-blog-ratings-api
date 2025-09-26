FactoryBot.define do
  factory :rating do
    association :post
    association :user
    value { rand(1..5) }
  end
end
