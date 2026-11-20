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
        journals: result.journals.map { |journal| JournalPresenter.present(journal, result) },
        page: page,
        per_page: PER_PAGE,
        total_count: result.total_count
      }
    end
  end
end
