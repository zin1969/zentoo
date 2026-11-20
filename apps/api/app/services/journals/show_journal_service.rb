# frozen_string_literal: true

module Journals
  class ShowJournalService
    def initialize(repository: ListJournals.new)
      @repository = repository
    end

    def call(user_id:, journal_id:)
      result = @repository.find(user_id: user_id, journal_id: journal_id)
      raise JournalNotFoundError unless result

      JournalPresenter.present(result.journals.first, result)
    end
  end
end
