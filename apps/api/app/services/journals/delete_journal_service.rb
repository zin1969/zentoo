# frozen_string_literal: true

module Journals
  class DeleteJournalService
    def initialize(repository: DeleteJournal.new)
      @repository = repository
    end

    def call(journal_id:, user_id:)
      ActiveRecord::Base.transaction do
        @repository.delete!(journal_id: journal_id, user_id: user_id)
      end
    rescue DeleteJournal::JournalNotFound
      raise JournalNotFoundError
    rescue DeleteJournal::DirectDebitJournalNotDeletable
      raise DirectDebitJournalNotDeletableError
    end
  end
end
