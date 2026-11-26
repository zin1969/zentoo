class AssetAccount < ApplicationRecord
  enum :asset_type, {
    cash: 1,        # 現金
    deposit: 2,     # 預貯金（銀行・信用金庫・郵貯など）
    e_money: 3,     # 電子マネー
    securities: 4,  # 証券口座の預り金（値動きしない）
    investment: 5   # 投資（iDeCo・積立 NISA・株式など。値動きする）
  }

  has_many :credit_cards
  belongs_to :user
end
