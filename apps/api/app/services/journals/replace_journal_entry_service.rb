# frozen_string_literal: true

module Journals
  class ReplaceJournalEntryService
    def initialize(repository: ReplaceJournalEntry.new)
      @repository = repository
    end

    # 貸借の不一致・科目・カード設定のエラーは、登録と同じ InsertJournalEntry の例外のまま送出する
    def call(journal_id:, journal_data:)
      ActiveRecord::Base.transaction do
        @repository.replace_journal_entry!(journal_id: journal_id, journal_data: journal_data)
      end
    rescue ReplaceJournalEntry::JournalNotFound
      raise JournalNotFoundError
    rescue ReplaceJournalEntry::DirectDebitJournalNotEditable
      raise DirectDebitJournalNotEditableError
    rescue ReplaceJournalEntry::JournalNotEditable
      raise JournalNotEditableError
    rescue ReplaceJournalEntry::ExpenseDebitsRequired
      raise ExpenseDebitsRequiredError
    end
  end
end
