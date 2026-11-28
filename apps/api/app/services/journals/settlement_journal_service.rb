# frozen_string_literal: true

module Journals
  # 立替金の精算の登録・修正。エラーは SettlementJournals の例外のまま送出する（コントローラーがエラーコードにする）
  class SettlementJournalService
    def initialize(repository: SettlementJournals.new)
      @repository = repository
    end

    # @return [Integer] journal_id
    def create(**attributes)
      ActiveRecord::Base.transaction { @repository.create!(**attributes) }
    end

    # 仕訳は作り直されるので、新しい journal_id を返す
    #
    # @return [Integer] journal_id
    def replace(**attributes)
      ActiveRecord::Base.transaction { @repository.replace!(**attributes) }
    end
  end
end
