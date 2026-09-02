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
  end
end
