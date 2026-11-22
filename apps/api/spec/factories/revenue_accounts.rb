FactoryBot.define do
  factory :revenue_account do
    name { "default" }
    association :user

    # 全ユーザーが使える共通科目
    trait :common do
      user { nil }
    end

    trait :salary do
      name { "給与" }
    end

    trait :bonus do
      name { "賞与" }
    end
  end
end
