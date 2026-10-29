# frozen_string_literal: true

module Journals
  class ListJournalsService
    PER_PAGE = 50

    def initialize(repository: ListJournals.new)
      @repository = repository
    end

    def call(user_id:, from:, to:, page:)
      result = @repository.list(user_id: user_id, from: from, to: to, page: page, per_page: PER_PAGE)

      {
        journals: result.journals.map { |journal| present(journal, result) },
        page: page,
        per_page: PER_PAGE,
        total_count: result.total_count
      }
    end

    private

    def present(journal, result)
      {
        id: journal.id,
        journal_date: journal.journal_dt,
        store_name: journal.store_name,
        debits: journal.debits.sort_by(&:id).map do |debit|
          {
            element_type: debit.element_type.to_i,
            account_id: debit.account_id,
            account_name: account_name(result, debit),
            item_name: debit.item_name,
            amount: debit.amount.to_i
          }
        end,
        credits: journal.credits.sort_by(&:id).map do |credit|
          {
            element_type: credit.element_type.to_i,
            payment_method_type: credit.payment_method_type,
            account_id: credit.account_id,
            account_name: account_name(result, credit),
            amount: credit.amount.to_i
          }
        end,
        # この仕訳が引き落とし仕訳の場合、元のカード払い仕訳の ID
        original_journal_id: result.direct_debit_links.find { |link| link.direct_debit_id == journal.id }&.original_id,
        # この仕訳がカード払いの場合、引き落とし仕訳の ID
        direct_debit_journal_id: result.direct_debit_links.find { |link| link.original_id == journal.id }&.direct_debit_id
      }
    end

    def account_name(result, entry)
      result.account_names[[ entry.element_type.to_i, entry.account_id ]]
    end
  end
end
