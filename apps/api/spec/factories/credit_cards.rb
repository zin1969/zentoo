FactoryBot.define do
  factory :credit_card do
    cutoff_day  { 15 }
    payment_day { 10 }

    association :user
    association :liability_account
    association :bank_account, factory: :asset_account

    trait :jal do
      association :liability_account, :jal
      cutoff_day  { 15 }
      payment_day { 10 }
    end

    trait :enoteca do
      association :liability_account, :enoteca
      cutoff_day  { 15 }
      payment_day { 10 }
    end

    trait :tcard do
      association :liability_account, :tcard
      cutoff_day  { 10 }
      payment_day { 27 }
    end

    trait :paypay do
      association :liability_account, :paypay
      cutoff_day  { 31 }
      payment_day { 27 }
    end
  end
end
