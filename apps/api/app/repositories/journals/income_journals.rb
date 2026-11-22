# frozen_string_literal: true

module Journals
  class IncomeJournals
    class AssetAccountNotFound < StandardError; end
    class RevenueAccountNotFound < StandardError; end
    class JournalNotFound < StandardError; end
    class NotIncomeJournal < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 収入の仕訳（借方: 入金先の口座、貸方: 収益科目）を登録する
    #
    # @return [Integer] journal_id
    def create!(journal_date:, asset_account_id:, revenue_account_id:, amount:, description:, user_id:)
      call(
        "SELECT create_income_journal(?::DATE, ?::INT, ?::INT, ?::INT, ?::TEXT, ?::INT)",
        journal_date, asset_account_id, revenue_account_id, amount, description, user_id
      )
    end

    # 収入の仕訳を、新しい内容で作り直す。仕訳の ID は変わる
    #
    # @return [Integer] 作り直した仕訳の ID
    def replace!(journal_id:, journal_date:, asset_account_id:, revenue_account_id:, amount:, description:, user_id:)
      call(
        "SELECT replace_income_journal(?::INT, ?::DATE, ?::INT, ?::INT, ?::INT, ?::TEXT, ?::INT)",
        journal_id, journal_date, asset_account_id, revenue_account_id, amount, description, user_id
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
      when /asset_account not found/
        AssetAccountNotFound.new
      when /revenue_account not found/
        RevenueAccountNotFound.new
      when /journal not found/
        JournalNotFound.new
      when /journal is not an income journal/
        NotIncomeJournal.new
      else
        error
      end
    end
  end
end
