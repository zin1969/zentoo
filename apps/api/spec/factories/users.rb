FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "user_#{n}" }
    password { "password" }

    trait :system do
      name { "system" }
      password { nil }
    end

    trait :masa do
      name { "masa" }
    end
  end
end
