# frozen_string_literal: true

module Journals
  class SettlementJournals
    class ReceivableAccountNotFound < StandardError; end
    class ToAccountNotFound < StandardError; end
    class DifferenceAccountNotFound < StandardError; end
    class JournalNotFound < StandardError; end
    class NotSettlementJournal < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 立替金の精算（借方: 入金先・差額の費用、貸方: 立替金・差額の収益）を登録する
    #
    # @param settled_amount [Integer] 立替金から減らす額
    # @param received_amount [Integer] 受け取った額（0 なら入金先は使わない）
    # @param difference_account_id [Integer, nil] 差額の科目。少なく受け取ったら費用科目、多く受け取ったら収益科目
    # @return [Integer] journal_id
    def create!(journal_date:, receivable_account_id:, settled_amount:, received_amount:, to_account_id:,
                difference_account_id:, description:, user_id:)
      call(
        "SELECT create_settlement_journal(?::DATE, ?::INT, ?::INT, ?::INT, ?::INT, ?::INT, ?::TEXT, ?::INT)",
        journal_date, receivable_account_id, settled_amount, received_amount, to_account_id,
        difference_account_id, description, user_id
      )
    end

    # 精算の仕訳を、新しい内容で作り直す。仕訳の ID は変わる
    #
    # @return [Integer] 作り直した仕訳の ID
    def replace!(journal_id:, journal_date:, receivable_account_id:, settled_amount:, received_amount:, to_account_id:,
                 difference_account_id:, description:, user_id:)
      call(
        "SELECT replace_settlement_journal(?::INT, ?::DATE, ?::INT, ?::INT, ?::INT, ?::INT, ?::INT, ?::TEXT, ?::INT)",
        journal_id, journal_date, receivable_account_id, settled_amount, received_amount, to_account_id,
        difference_account_id, description, user_id
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
      when /receivable account not found/
        ReceivableAccountNotFound.new
      when /to account not found/
        ToAccountNotFound.new
      when /difference account not found/
        DifferenceAccountNotFound.new
      when /journal not found/
        JournalNotFound.new
      when /journal is not a settlement journal/
        NotSettlementJournal.new
      else
        error
      end
    end
  end
end
