# frozen_string_literal: true

module Journals
  class UpdateDirectDebitDate
    class JournalNotFound < StandardError; end
    class NotDirectDebitJournal < StandardError; end
    class PaymentDateBeforeJournalDate < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # カード払いの引き落とし仕訳の日付を変える。金額・科目は変えない
    #
    # @return [Integer] 引き落とし仕訳の ID（変わらない）
    def update_direct_debit_date!(journal_id:, payment_date:, user_id:)
      sql = "SELECT update_direct_debit_date(?::INT, ?::DATE, ?::INT)"
      sanitized_sql = @base.sanitize_sql_array([ sql, journal_id, payment_date, user_id ])

      @connection.select_value(sanitized_sql)
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      case error.cause&.message
      when /journal not found/
        JournalNotFound.new
      when /journal is not a direct debit journal/
        NotDirectDebitJournal.new
      when /payment date must not be before journal date/
        PaymentDateBeforeJournalDate.new
      else
        error
      end
    end
  end
end
