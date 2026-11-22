# frozen_string_literal: true

module Reports
  # 月ごとの支出（費用科目ごと）と収入（収益科目ごと）、収支（収入 − 支出）
  class MonthlyExpensesService
    def initialize(repository: MonthlyExpenses.new, income_repository: MonthlyIncomes.new)
      @repository = repository
      @income_repository = income_repository
    end

    def call(user_id:, month:)
      expenses = @repository.list(user_id: user_id, month: month)
      incomes = @income_repository.list(user_id: user_id, month: month)

      total = expenses.sum(&:amount)
      income_total = incomes.sum(&:amount)

      {
        month: month.strftime("%Y-%m"),
        # total・items は支出（以前からの項目名のまま）
        total: total,
        items: expenses.map { |expense| present(expense) },
        income_total: income_total,
        income_items: incomes.map { |income| present(income) },
        net: income_total - total
      }
    end

    private

    def present(row)
      { account_id: row.account_id, account_name: row.account_name, amount: row.amount }
    end
  end
end
