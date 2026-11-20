# frozen_string_literal: true

module Journals
  class DeleteJournal
    class JournalNotFound < StandardError; end
    class DirectDebitJournalNotDeletable < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 仕訳を削除する。カード払いの仕訳なら、自動で作られた引き落とし仕訳も一緒に削除する
    #
    # @return [Integer] 削除した仕訳の数
    def delete!(journal_id:, user_id:)
      sql = "SELECT delete_journal(?::INT, ?::INT)"
      sanitized_sql = @base.sanitize_sql_array([ sql, journal_id, user_id ])

      @connection.select_value(sanitized_sql)
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      case error.cause&.message
      when /journal not found/
        JournalNotFound.new
      when /direct debit journal cannot be deleted/
        DirectDebitJournalNotDeletable.new
      else
        error
      end
    end
  end
end
