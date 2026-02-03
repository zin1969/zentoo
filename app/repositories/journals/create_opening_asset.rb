# frozen_string_literal: true

module Journals
  class CreateOpeningAsset
    class OpeningAssetAlreadyExists < StandardError; end

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
    # @return [Integer] journal_id
    def create_opening_asset_balance!(
      journal_date:,
      asset_type:,
      asset_account_id:,
      amount:,
      user_id:
    )
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
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      return error unless error.cause.is_a?(PG::RaiseException)

      case error.cause&.message
      when /opening asset already exists/
        OpeningAssetAlreadyExists.new
      else
        error
      end
    end
  end
end
