# frozen_string_literal: true

module Accounts
  # 費用科目の追加・変更・削除
  class ExpenseAccountsService < TwoLevelAccountsService
    def initialize
      super(model: ExpenseAccount, element_type: ElementType::EXPENSES)
    end
  end
end
