FactoryBot.define do
  factory :post do
    association :user
    sequence(:title) { |n| "Post Title #{n}" }
    sequence(:body) { |n| "This is the body of post #{n}." }
    ip { "192.168.1.#{rand(1..254)}" }
    avg_rating { 0 }
  end
end
