# frozen_string_literal: true

module Journals
  class CreateOpeningLiability
    class LiabilityAccountNotFound < StandardError; end
    class OpeningLiabilityAlreadyExists < StandardError; end
    class PaymentDateBeforeJournalDate < StandardError; end
    class CreditCardSettingNotFound < StandardError; end

    def initialize(base: ActiveRecord::Base)
      @base = base
      @connection = base.connection
    end

    # 開始時点で未払いのカードの残高を登録する
    # 借方: 元入金、貸方: カード（負債）。引き落とし仕訳は、指定した引き落とし日で自動的に作られる
    #
    # @return [Integer] journal_id
    def create_opening_liability_balance!(journal_date:, liability_account_id:, amount:, payment_date:, user_id:)
      sql = "SELECT create_opening_liability_balance_journal(?::DATE, ?::INT, ?::INT, ?::DATE, ?::INT)"
      sanitized_sql = @base.sanitize_sql_array(
        [ sql, journal_date, liability_account_id, amount, payment_date, user_id ]
      )

      @connection.select_value(sanitized_sql)
    rescue ActiveRecord::StatementInvalid => e
      raise map_exception(e)
    end

    private

    def map_exception(error)
      case error.cause&.message
      when /liability_account not found/
        LiabilityAccountNotFound.new
      when /opening liability already exists/
        OpeningLiabilityAlreadyExists.new
      when /payment date must not be before journal date/
        PaymentDateBeforeJournalDate.new
      when /credit_card setting not found/
        CreditCardSettingNotFound.new
      else
        error
      end
    end
  end
end
