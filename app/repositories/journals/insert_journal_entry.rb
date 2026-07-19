# frozen_string_literal: true

module Journals
  class InsertJournalEntry
    class UnbalancedJournal < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 開始資産を登録する
    #
    # @param journal_data [json]
    def insert_journal_entry!(
      journal_data:
    )
      sql = "SELECT insert_journal_entry(?::JSONB)"
      sanitized_sql = @base.sanitize_sql_array([sql, journal_data.to_json])

      @connection.select_value(sanitized_sql)
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      case error.cause&.message
      when /unbalance debit and credit/
        UnbalancedJournal.new
      else
        error
      end
    end
  end
end
