# frozen_string_literal: true

module Reports
  class MonthlyIncomes
    Income = Struct.new(:account_id, :account_name, :amount, keyword_init: true)

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 指定月の、ユーザーの収入を収益科目ごとに集計する（金額の大きい順）
    #
    # @param month [Date] 月内のどの日付でもよい
    # @return [Array<Income>]
    def list(user_id:, month:)
      sql = @base.sanitize_sql_array([ "SELECT * FROM get_monthly_incomes(?, ?::DATE)", user_id, month ])

      @connection.select_all(sql).to_a.map { |row| Income.new(**row.symbolize_keys) }
    end
  end
end
