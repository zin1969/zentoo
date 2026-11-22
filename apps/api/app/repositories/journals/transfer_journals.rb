# frozen_string_literal: true

module Journals
  class TransferJournals
    class FromAccountNotFound < StandardError; end
    class ToAccountNotFound < StandardError; end
    class SameAccount < StandardError; end
    class CreditCardChargeRequiresEMoney < StandardError; end
    class CreditCardSettingNotFound < StandardError; end
    class JournalNotFound < StandardError; end
    class NotTransferJournal < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 振替の仕訳（借方: 入れる先の口座、貸方: 出す元の口座かクレジットカード）を登録する
    #
    # @param from_element_type [Integer] ElementType::ASSETS（口座から）か ElementType::LIABILITIES（カードから）
    # @return [Integer] journal_id
    def create!(journal_date:, from_element_type:, from_account_id:, to_account_id:, amount:, description:, user_id:)
      call(
        "SELECT create_transfer_journal(?::DATE, ?::INT, ?::INT, ?::INT, ?::INT, ?::TEXT, ?::INT)",
        journal_date, from_element_type, from_account_id, to_account_id, amount, description, user_id
      )
    end

    # 振替の仕訳を、新しい内容で作り直す。仕訳の ID は変わる
    #
    # @return [Integer] 作り直した仕訳の ID
    def replace!(journal_id:, journal_date:, from_element_type:, from_account_id:, to_account_id:, amount:,
                 description:, user_id:)
      call(
        "SELECT replace_transfer_journal(?::INT, ?::DATE, ?::INT, ?::INT, ?::INT, ?::INT, ?::TEXT, ?::INT)",
        journal_id, journal_date, from_element_type, from_account_id, to_account_id, amount, description, user_id
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
      when /from account not found/
        FromAccountNotFound.new
      when /to account not found/
        ToAccountNotFound.new
      when /from and to accounts must differ/
        SameAccount.new
      when /credit card can only charge e-money/
        CreditCardChargeRequiresEMoney.new
      when /credit_card setting not found/
        CreditCardSettingNotFound.new
      when /journal not found/
        JournalNotFound.new
      when /journal is not a transfer journal/
        NotTransferJournal.new
      else
        error
      end
    end
  end
end
