# frozen_string_literal: true

module Journals
  class CreateCashDeposit
    class AssetAccountNotFound < StandardError; end
    class CashAccountNotDetermined < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 現金を預金口座に預け入れる仕訳（借方: 預金口座、貸方: 現金）を登録する
    #
    # @return [Integer] journal_id
    def create_cash_deposit!(journal_date:, bank_account_id:, amount:, user_id:)
      sql = "SELECT create_cash_deposit_journal(?::DATE, ?::INT, ?::INT, ?::INT)"
      sanitized_sql = @base.sanitize_sql_array([ sql, journal_date, bank_account_id, amount, user_id ])

      @connection.select_value(sanitized_sql)
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      case error.cause&.message
      when /asset_account not found/
        AssetAccountNotFound.new
      when /cash account not determined/
        CashAccountNotDetermined.new
      else
        error
      end
    end
  end
end
