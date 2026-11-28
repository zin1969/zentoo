# frozen_string_literal: true

module Journals
  class StockTrades
    class StockAccountNotFound < StandardError; end
    class SecuritiesAccountNotFound < StandardError; end
    class InsufficientShares < StandardError; end
    class LaterSaleExists < StandardError; end
    class StockGainAccountNotFound < StandardError; end
    class StockLossAccountNotFound < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 株の買い（借方: 銘柄（株数 +n）、貸方: 証券口座（預り金））を登録する
    #
    # @param amount [Integer] 証券口座から出ていった額（手数料を含む）
    # @return [Integer] journal_id
    def create_buy!(journal_date:, stock_account_id:, securities_account_id:, shares:, amount:, user_id:)
      call(
        "SELECT create_stock_buy_journal(?::DATE, ?::INT, ?::INT, ?::INT, ?::INT, ?::INT)",
        journal_date, stock_account_id, securities_account_id, shares, amount, user_id
      )
    end

    # 株の売り（借方: 証券口座（受け取った額）、貸方: 銘柄（株数 −n、移動平均の取得額））を登録する。
    # 差額は売却益（収益）か売却損（費用）になる
    #
    # @param amount [Integer] 証券口座に入った額（手数料・税金を引いたあと）
    # @return [Integer] journal_id
    def create_sell!(journal_date:, stock_account_id:, securities_account_id:, shares:, amount:, user_id:)
      call(
        "SELECT create_stock_sell_journal(?::DATE, ?::INT, ?::INT, ?::INT, ?::INT, ?::INT)",
        journal_date, stock_account_id, securities_account_id, shares, amount, user_id
      )
    end

    private

    def call(sql, *values)
      @connection.select_value(@base.sanitize_sql_array([ sql, *values ]))
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    def map_exception(error)
      case error.cause&.message
      when /stock account not found/
        StockAccountNotFound.new
      when /securities account not found/
        SecuritiesAccountNotFound.new
      when /insufficient shares/
        InsufficientShares.new
      when /later stock sale exists/
        LaterSaleExists.new
      when /stock gain account not found/
        StockGainAccountNotFound.new
      when /stock loss account not found/
        StockLossAccountNotFound.new
      else
        error
      end
    end
  end
end
