FactoryBot.define do
  factory :equity_account do
    name { "default_equity" }
    association :user

    # 全ユーザーが使える共通科目
    trait :common do
      user { nil }
    end

    trait :original_deposit do
      name { "元入金" }
    end
  end
end
