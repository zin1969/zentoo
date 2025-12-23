FactoryBot.define do
  factory :expense_account do
    name { "default" }
    association :user

    trait :root do
      name { "root" }
      parent { nil }
    end

    trait :food do
      name { "食費" }
    end

    trait :entertainment do
      name { "娯楽費" }
    end

    trait :transportation do
      name { "交通費" }
    end

    trait :education do
      name { "教育費" }
    end

    trait :eating_out do
      name { "外食費" }
    end

    trait :movie do
      name { "映画" }
    end

    trait :streaming do
      name { "配信サービス" }
    end

    trait :manga do
      name { "漫画" }
    end
  end
end
