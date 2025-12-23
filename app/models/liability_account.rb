class LiabilityAccount < ApplicationRecord
  enum :liability_type, {
    loan: 1,          # 借入金
    cashing: 2,       # キャッシング
    credit_card: 3    # クレジットカード払い
  }

  has_many :credit_cards
  belongs_to :user
end
