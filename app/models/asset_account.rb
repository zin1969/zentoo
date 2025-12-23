class AssetAccount < ApplicationRecord
  enum :asset_type, {
    cash: 1,        # 現金
    deposit: 2,     # 預貯金（銀行・信用金庫・郵貯など）
    e_money: 3      # 電子マネー
  }

  has_many :credit_cards
  belongs_to :user
end
