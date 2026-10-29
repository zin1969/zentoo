# frozen_string_literal: true

module Journals
  class ListJournals
    Result = Struct.new(:journals, :total_count, :account_names, :direct_debit_links, keyword_init: true)

    # 認証済みユーザーの仕訳を、新しい日付順に取得する
    #
    # @param from [Date, nil] 期間の開始日（含む）
    # @param to [Date, nil] 期間の終了日（含む）
    def list(user_id:, from:, to:, page:, per_page:)
      scope = Journal.where(user_id: user_id)
      scope = scope.where(journal_dt: from..) if from
      scope = scope.where(journal_dt: ..to) if to

      journals = scope
                 .includes(:debits, :credits)
                 .order(journal_dt: :desc, id: :desc)
                 .offset((page - 1) * per_page)
                 .limit(per_page)
                 .to_a

      Result.new(
        journals: journals,
        total_count: scope.count,
        account_names: account_names_for(journals),
        direct_debit_links: direct_debit_links_for(journals, user_id)
      )
    end

    private

    # { [element_type, account_id] => name }
    def account_names_for(journals)
      entries = journals.flat_map { |journal| journal.debits.to_a + journal.credits.to_a }
      ids_by_element = entries.group_by { |entry| entry.element_type.to_i }.transform_values { |rows| rows.map(&:account_id).uniq }

      {
        ElementType::ASSETS => AssetAccount,
        ElementType::LIABILITIES => LiabilityAccount,
        ElementType::EQUITY => EquityAccount,
        ElementType::EXPENSES => ExpenseAccount
      }.each_with_object({}) do |(element_type, model), names|
        ids = ids_by_element[element_type]
        next if ids.blank?

        model.where(id: ids).pluck(:id, :name).each do |id, name|
          names[[ element_type, id ]] = name
        end
      end
    end

    # 表示する仕訳が絡む「カード払い仕訳 ⇔ 引き落とし仕訳」の紐付け
    def direct_debit_links_for(journals, user_id)
      ids = journals.map(&:id)

      DirectDebitJournal
        .where(user_id: user_id)
        .where(original_id: ids).or(DirectDebitJournal.where(user_id: user_id, direct_debit_id: ids))
        .to_a
    end
  end
end
