# frozen_string_literal: true

module Reports
  # 予算ごとの、指定日を含む期間の予算額・使った額・残り
  class BudgetReportService
    def initialize(repository: BudgetReports.new, budgets: Budgets::BudgetsService.new)
      @repository = repository
      @budgets = budgets
    end

    def call(user:, as_of:)
      rows = @repository.list(user_id: user.id, as_of: as_of).index_by(&:budget_id)

      items = @budgets.list(user: user).filter_map do |budget|
        row = rows[budget.id]
        next unless row

        Budgets::BudgetPresenter.present(budget).merge(
          period_start: row.period_start,
          period_end: row.period_end,
          # その期間の予算額（月ごとに決めた額なら、その月の額）
          budget_amount: row.budget_amount,
          used_amount: row.used_amount,
          remaining_amount: row.budget_amount - row.used_amount
        )
      end

      { date: as_of, budgets: items }
    end
  end
end
