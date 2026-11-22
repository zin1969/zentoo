# frozen_string_literal: true

module Journals
  class IncomeJournalService
    def initialize(repository: IncomeJournals.new)
      @repository = repository
    end

    # @return [Integer] journal_id
    def create(**attributes)
      run { @repository.create!(**attributes) }
    end

    # 仕訳は作り直されるので、新しい journal_id を返す
    #
    # @return [Integer] journal_id
    def replace(**attributes)
      run { @repository.replace!(**attributes) }
    end

    private

    def run
      ActiveRecord::Base.transaction { yield }
    rescue IncomeJournals::AssetAccountNotFound
      raise AssetAccountNotFoundError
    rescue IncomeJournals::RevenueAccountNotFound
      raise RevenueAccountNotFoundError
    rescue IncomeJournals::JournalNotFound
      raise JournalNotFoundError
    rescue IncomeJournals::NotIncomeJournal
      raise JournalNotEditableError
    end
  end
end
