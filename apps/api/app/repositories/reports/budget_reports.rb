# frozen_string_literal: true

module Reports
  class BudgetReports
    Row = Struct.new(:budget_id, :period_start, :period_end, :budget_amount, :used_amount, keyword_init: true)

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 予算ごとに、指定日を含む期間（週・月・年）の予算額と使った額を取得する
    #
    # @param as_of [Date]
    # @return [Array<Row>]
    def list(user_id:, as_of:)
      sql = @base.sanitize_sql_array([ "SELECT * FROM get_budget_report(?, ?::DATE)", user_id, as_of ])

      @connection.select_all(sql).to_a.map do |row|
        Row.new(**row.symbolize_keys.merge(period_start: row["period_start"].to_date, period_end: row["period_end"].to_date))
      end
    end
  end
end
