# frozen_string_literal: true

module Reports
  class StockHoldings
    Holding = Struct.new(:account_id, :account_name, :shares, :cost, keyword_init: true)

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 指定日（含む）時点の、銘柄（株数を持つ種別「投資」の口座）ごとの株数と取得額を取得する
    #
    # @param as_of [Date]
    # @return [Array<Holding>]
    def list(user_id:, as_of:)
      sql = @base.sanitize_sql_array([ "SELECT * FROM get_stock_holdings(?, ?::DATE)", user_id, as_of ])

      @connection.select_all(sql).to_a.map { |row| Holding.new(**row.symbolize_keys) }
    end
  end
end
