# frozen_string_literal: true

module Reports
  class AccountBalances
    Balance = Struct.new(:element_type, :account_id, :account_name, :balance, keyword_init: true)

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 指定日（含む）時点の、ユーザーの資産・負債科目ごとの残高を取得する
    # 資産は「借方 - 貸方」、負債は「貸方 - 借方」（未払いの額）
    #
    # @param as_of [Date]
    # @return [Array<Balance>]
    def list(user_id:, as_of:)
      sql = @base.sanitize_sql_array([ "SELECT * FROM get_account_balances(?, ?::DATE)", user_id, as_of ])

      @connection.select_all(sql).to_a.map { |row| Balance.new(**row.symbolize_keys) }
    end
  end
end
