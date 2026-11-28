# frozen_string_literal: true

module Journals
  # 株の売買の登録。エラーは StockTrades の例外のまま送出する（コントローラーがエラーコードにする）
  class StockTradeService
    def initialize(repository: StockTrades.new)
      @repository = repository
    end

    # @param trade_type [String] "buy" か "sell"
    # @return [Integer] journal_id
    def create(trade_type:, **attributes)
      ActiveRecord::Base.transaction do
        trade_type == "sell" ? @repository.create_sell!(**attributes) : @repository.create_buy!(**attributes)
      end
    end
  end
end
