FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "user_#{n}" }

    trait :system do
      name { "system" }
    end

    trait :masa do
      name { "masa" }
    end
  end
end
