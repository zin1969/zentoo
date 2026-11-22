# frozen_string_literal: true

module Journals
  class ReplaceJournalEntry
    class JournalNotFound < StandardError; end
    class DirectDebitJournalNotEditable < StandardError; end
    class JournalNotEditable < StandardError; end
    class ExpenseDebitsRequired < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # お買い物の仕訳を、新しい内容で作り直す。仕訳の ID は変わる
    #
    # 貸借の不一致・科目・カード設定の確認は登録と同じで、InsertJournalEntry の例外を送出する
    #
    # @return [Integer] 作り直した仕訳の ID
    def replace_journal_entry!(journal_id:, journal_data:)
      sql = "SELECT replace_journal_entry(?::INT, ?::JSONB)"
      sanitized_sql = @base.sanitize_sql_array([ sql, journal_id, journal_data.to_json ])

      @connection.select_value(sanitized_sql)
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      case error.cause&.message
      when /journal not found/
        JournalNotFound.new
      when /direct debit journal cannot be updated/
        DirectDebitJournalNotEditable.new
      when /journal is not a shopping journal/
        JournalNotEditable.new
      when /shopping journal must debit expenses only/
        ExpenseDebitsRequired.new
      when /unbalance debit and credit/
        InsertJournalEntry::UnbalancedJournal.new
      when /account not found/
        InsertJournalEntry::AccountNotFound.new
      when /credit_card setting not found/
        InsertJournalEntry::CreditCardSettingNotFound.new
      when /tag not found/
        InsertJournalEntry::TagNotFound.new
      when /tags are only for expense debits/
        InsertJournalEntry::TagsOnlyForExpenseDebits.new
      else
        error
      end
    end
  end
end
