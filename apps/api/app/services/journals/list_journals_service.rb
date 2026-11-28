# frozen_string_literal: true

module Journals
  class ListJournalsService
    PER_PAGE = 50

    def initialize(repository: ListJournals.new)
      @repository = repository
    end

    def call(user_id:, from:, to:, page:, keyword: nil, account: nil, tag_id: nil)
      result = @repository.list(
        user_id: user_id, from: from, to: to, page: page, per_page: PER_PAGE,
        keyword: keyword, account: account, tag_id: tag_id
      )

      {
        journals: result.journals.map { |journal| JournalPresenter.present(journal, result) },
        page: page,
        per_page: PER_PAGE,
        total_count: result.total_count,
        # 科目で絞り込んだときだけ、条件に合う仕訳全体でのその科目の借方合計・貸方合計。それ以外は null
        account_totals: result.account_totals
      }
    end
  end
end
