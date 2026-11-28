# frozen_string_literal: true

module Reports
  class StockHoldingsService
    def initialize(repository: StockHoldings.new)
      @repository = repository
    end

    # 平均取得単価は 取得額 ÷ 株数（小数第 2 位まで）。全部売って株数が 0 の銘柄は null
    def call(user_id:, as_of:)
      holdings = @repository.list(user_id: user_id, as_of: as_of).map do |holding|
        {
          account_id: holding.account_id,
          account_name: holding.account_name,
          shares: holding.shares,
          cost: holding.cost,
          average_price: average_price(holding)
        }
      end

      {
        date: as_of,
        holdings: holdings,
        total_cost: holdings.sum { |holding| holding[:cost] }
      }
    end

    private

    def average_price(holding)
      return nil unless holding.shares.positive?

      (BigDecimal(holding.cost) / holding.shares).round(2).to_f
    end
  end
end
