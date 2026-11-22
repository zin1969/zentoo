FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "tag_#{n}" }
    association :user

    trait :study do
      name { "勉強" }
    end

    trait :fun do
      name { "娯楽" }
    end
  end
end
