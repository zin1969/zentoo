FactoryBot.define do
  factory :liability_account do
    liability_type { :credit_card }
    name { "default_liability" }
    association :user

    trait :jal do
      name { "JAL" }
    end

    trait :enoteca do
      name { "enoteca" }
    end

    trait :tcard do
      name { "tcard" }
    end

    trait :paypay do
      name { "PayPay" }
    end
  end
end
