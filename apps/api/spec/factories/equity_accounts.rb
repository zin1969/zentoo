FactoryBot.define do
  factory :equity_account do
    name { "default_equity" }
    association :user

    trait :original_deposit do
      name { "元入金" }
    end
  end
end
