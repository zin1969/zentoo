# frozen_string_literal: true

module Reports
  class BankAccountLedger
    class AssetAccountNotFound < StandardError; end

    # row_type: "carried_over"（繰越。1 行目）、"journal"（1 つの仕訳）、"card_payment"（同じ日・同じカードの引き落としのまとめ）
    # journal_ids: カードの行は元のお買い物の仕訳、それ以外はその仕訳
    Row = Struct.new(
      :row_type, :entry_date, :card_account_id, :description, :deposit, :withdrawal, :balance, :journal_ids,
      keyword_init: true
    )

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 預金口座の通帳の行（繰越と、期間内の出入金）を、残高を積み上げて取得する
    #
    # @return [Array<Row>]
    def list(user_id:, asset_account_id:, from:, to:)
      sql = @base.sanitize_sql_array(
        [ "SELECT * FROM get_bank_account_ledger(?::INT, ?::INT, ?::DATE, ?::DATE)", user_id, asset_account_id, from, to ]
      )
      result = @connection.select_all(sql)

      # journal_ids（BIGINT[]）や日付を Ruby の値にするため、列の型で変換する
      result.cast_values.map { |values| Row.new(**result.columns.map(&:to_sym).zip(values).to_h) }
    rescue ActiveRecord::StatementInvalid => e
      raise AssetAccountNotFound if e.cause&.message&.include?("asset_account not found")

      raise
    end

    # 口座が動く最後の日（未来の引き落とし予定を含む）。動きが無ければ nil
    def last_entry_date(user_id:, asset_account_id:)
      [ Debit, Credit ].filter_map do |model|
        model.joins(:journal)
             .where(journals: { user_id: user_id }, account_id: asset_account_id)
             .where("#{model.table_name}.element_type = ?", ElementType::ASSETS)
             .maximum("journals.journal_dt")
      end.max
    end
  end
end
