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

    trait :dividend do
      name { "配当金" }
    end

    # 株の売りで、取得額より高く売ったときに使う
    trait :stock_gain do
      name { "株式売却益" }
    end
  end
end
