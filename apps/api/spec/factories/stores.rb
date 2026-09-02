FactoryBot.define do
  factory :store do
    sequence(:name) { |n| "store_#{n}" }

    trait :aquavit do
      name { "Aquavit" }
    end

    trait :maibasuketto do
      name { "まいばすけっと" }
    end
  end
end
