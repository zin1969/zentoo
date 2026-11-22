# frozen_string_literal: true

module Accounts
  # 収益科目の追加・変更・削除
  class RevenueAccountsService < TwoLevelAccountsService
    def initialize
      super(model: RevenueAccount, element_type: ElementType::REVENUE)
    end
  end
end
