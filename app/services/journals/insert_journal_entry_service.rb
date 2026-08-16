# frozen_string_literal: true

module Journals
  class InsertJournalEntryService
    def initialize(
      repository: InsertJournalEntry.new
    )
      @repository = repository
    end

    def call(
      journal_data:
    )
      ActiveRecord::Base.transaction do
        @repository.insert_journal_entry!(
          journal_data: journal_data
        )
      end
    end
  end
end
