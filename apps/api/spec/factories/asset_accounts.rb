FactoryBot.define do
  factory :asset_account do
    asset_type { :cash }
    name { "default_asset" }
    association :user

    trait :cash do
      asset_type { :cash }
      name { "現金" }
    end

    trait :mufg_yoga do
      asset_type { :deposit }
      name { "三菱UFJ銀行 用賀出張所" }
    end

    trait :mizuho_tamagawa do
      asset_type { :deposit }
      name { "みずほ銀行 玉川支店" }
    end

    trait :suica do
      asset_type { :e_money }
      name { "Suica" }
    end

    trait :securities do
      asset_type { :securities }
      name { "証券口座" }
    end

    trait :nisa do
      asset_type { :investment }
      name { "積立 NISA" }
    end

    trait :ideco do
      asset_type { :investment }
      name { "iDeCo" }
    end

    # 現物株の銘柄（種別「投資」）
    trait :toyota do
      asset_type { :investment }
      name { "トヨタ 7203" }
    end

    trait :sony do
      asset_type { :investment }
      name { "ソニー 6758" }
    end
  end
end
