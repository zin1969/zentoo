# frozen_string_literal: true

module Journals
  class CreateOpeningAsset
    class OpeningAssetAlreadyExists < StandardError; end
    class AssetAccountNotFound < StandardError; end
    class SharesRequireInvestmentAccount < StandardError; end
    class LaterStockSaleExists < StandardError; end

    def initialize(connection: ActiveRecord::Base.connection)
      @connection = connection
    end

    # 開始資産を登録する
    #
    # @param journal_date [Date]
    # @param asset_type [ElementType]
    # @param asset_account_id [Integer]
    # @param amount [Amount]
    # @param user_id [Integer]
    # @param shares [Integer, nil] 株数。渡すと株の銘柄（種別「投資」の口座）の開始残高になる（金額は 株数 × 平均取得単価）
    # @return [Integer] journal_id
    def create_opening_asset_balance!(
      journal_date:,
      asset_type:,
      asset_account_id:,
      amount:,
      user_id:,
      shares: nil
    )
      return create_opening_stock_balance!(journal_date:, asset_account_id:, shares:, amount:, user_id:) if shares

      sql = <<~SQL
        SELECT create_opening_asset_balance_journal(
          $1::DATE,
          $2::INT,
          $3::INT,
          $4::INT,
          $5::INT
        ) AS journal_id
      SQL

      binds = [
        journal_date,
        asset_type.to_i,
        asset_account_id,
        amount.to_i,
        user_id
      ]

      result = @connection.raw_connection.exec_params(sql, binds)

      result.getvalue(0, 0).to_i
    # raw_connection 経由のため、DB 関数の RAISE EXCEPTION は PG::RaiseException として届く
    rescue PG::RaiseException => e
      raise map_exception(e)
    end

    private

    # 株の銘柄の開始残高。開始資産と同じ仕訳に、借方の株数を足す
    def create_opening_stock_balance!(journal_date:, asset_account_id:, shares:, amount:, user_id:)
      sql = <<~SQL
        SELECT create_opening_stock_balance_journal(
          $1::DATE,
          $2::INT,
          $3::INT,
          $4::INT,
          $5::INT
        ) AS journal_id
      SQL

      result = @connection.raw_connection.exec_params(sql, [ journal_date, asset_account_id, shares, amount.to_i, user_id ])

      result.getvalue(0, 0).to_i
    rescue PG::RaiseException => e
      raise map_exception(e)
    end

    def map_exception(error)
      case error.message
      when /opening asset already exists/
        OpeningAssetAlreadyExists.new
      when /asset_account not found/
        AssetAccountNotFound.new
      when /shares require an investment account/
        SharesRequireInvestmentAccount.new
      when /later stock sale exists/
        LaterStockSaleExists.new
      else
        error
      end
    end
  end
end
