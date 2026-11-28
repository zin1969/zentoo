# frozen_string_literal: true

module Budgets
  # 予算の一覧と予算の集計で、予算を同じ形の JSON にする
  module BudgetPresenter
    module_function

    def present(budget)
      {
        id: budget.id,
        name: budget.name,
        target_type: budget.target_type,
        expense_account_id: budget.expense_account_id,
        tag_id: budget.tag_id,
        # 対象の科目かタグの名前
        target_name: budget.expense_account&.name || budget.tag&.name,
        period_type: budget.period_type,
        amount: budget.amount,
        # 1〜12 月で月ごとに決めた額（月の予算だけ）。毎月同じ額なら null
        monthly_amounts: budget.monthly_amounts,
        excluded_tags: budget.excluded_tags.sort_by(&:id).map { |tag| { id: tag.id, name: tag.name } }
      }
    end
  end
end
