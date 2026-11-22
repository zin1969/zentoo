# frozen_string_literal: true

module Reports
  class TagReports
    class TagNotFound < StandardError; end

    MonthlyTotal = Struct.new(:month, :amount, keyword_init: true)
    Item = Struct.new(:journal_id, :journal_date, :store_name, :item_name, :account_id, :account_name, :amount,
                      keyword_init: true)

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # タグが付いた費用の明細の、年の月ごとの合計（1〜12 月の 12 件。明細の無い月は 0）
    #
    # @return [Array<MonthlyTotal>]
    def monthly_totals(user_id:, tag_id:, year:)
      rows("SELECT * FROM get_tag_monthly_totals(?::INT, ?::INT, ?::INT)", user_id, tag_id, year)
        .map { |row| MonthlyTotal.new(**row) }
    end

    # 期間内に、タグが付いた費用の明細（仕訳日・明細の順）
    #
    # @return [Array<Item>]
    def items(user_id:, tag_id:, from:, to:)
      rows("SELECT * FROM get_tag_items(?::INT, ?::INT, ?::DATE, ?::DATE)", user_id, tag_id, from, to)
        .map { |row| Item.new(**row) }
    end

    private

    # 日付などを Ruby の値にするため、列の型で変換する
    def rows(sql, *values)
      result = @connection.select_all(@base.sanitize_sql_array([ sql, *values ]))
      result.cast_values.map { |row_values| result.columns.map(&:to_sym).zip(Array(row_values)).to_h }
    rescue ActiveRecord::StatementInvalid => e
      raise TagNotFound if e.cause&.message&.include?("tag not found")

      raise
    end
  end
end
