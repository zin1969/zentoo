# frozen_string_literal: true

module Journals
  class ListJournals
    Result = Struct.new(:journals, :total_count, :account_names, :direct_debit_links, keyword_init: true)

    # 費用科目・収益科目は、親の科目を指定すると子科目の仕訳も含める
    TWO_LEVEL_MODELS = {
      ElementType::EXPENSES => ExpenseAccount,
      ElementType::REVENUE => RevenueAccount
    }.freeze

    # 認証済みユーザーの仕訳を、新しい日付順に取得する。条件はすべて AND で絞り込む
    #
    # @param from [Date, nil] 期間の開始日（含む）
    # @param to [Date, nil] 期間の終了日（含む）
    # @param keyword [String, nil] 店舗名（摘要）か明細の品目に含まれる文字列（大文字小文字を区別しない）
    # @param account [Hash, nil] { element_type:, account_id: } 借方・貸方のどちらかでこの科目を使っている仕訳
    # @param tag_id [Integer, nil] このタグが付いた明細のある仕訳
    def list(user_id:, from:, to:, page:, per_page:, keyword: nil, account: nil, tag_id: nil)
      scope = Journal.where(user_id: user_id)
      scope = scope.where(journal_dt: from..) if from
      scope = scope.where(journal_dt: ..to) if to
      scope = filter_by_keyword(scope, keyword) if keyword
      scope = filter_by_account(scope, user_id, account) if account
      scope = filter_by_tag(scope, user_id, tag_id) if tag_id

      journals = scope
                 .includes(:credits, debits: :tags)
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

    # 認証済みユーザーの仕訳を 1 件取得する。他ユーザーの仕訳と存在しない仕訳は区別せず nil を返す
    def find(user_id:, journal_id:)
      journal = Journal.where(user_id: user_id).includes(:credits, debits: :tags).find_by(id: journal_id)
      return nil unless journal

      Result.new(
        journals: [ journal ],
        total_count: 1,
        account_names: account_names_for([ journal ]),
        direct_debit_links: direct_debit_links_for([ journal ], user_id)
      )
    end

    private

    # 明細・タグの副問い合わせは仕訳 ID で結ぶだけ。本人の仕訳かどうかは scope（journals.user_id）で絞っている

    # % と _ は文字として扱う
    def filter_by_keyword(scope, keyword)
      pattern = "%#{Journal.sanitize_sql_like(keyword)}%"
      matched_items = Debit.where("debits.item_name ILIKE ?", pattern).select(:journal_id)

      scope.where("journals.store_name ILIKE ?", pattern).or(scope.where(id: matched_items))
    end

    def filter_by_account(scope, user_id, account)
      element_type = account[:element_type]
      account_ids = account_ids_with_children(user_id, element_type, account[:account_id])

      # element_type の属性は ElementTypeType（値オブジェクトに変換する）なので、ハッシュの条件では整数と比べられない。SQL で比べる
      debits = Debit.where("debits.element_type = ?", element_type).where(account_id: account_ids).select(:journal_id)
      credits = Credit.where("credits.element_type = ?", element_type).where(account_id: account_ids).select(:journal_id)

      scope.where(id: debits).or(scope.where(id: credits))
    end

    # 費用科目・収益科目は、共通科目か本人の科目だけを指定でき、子科目も含める。
    # 口座・カード（資産・負債）は本人の仕訳にしか出てこないので、ID のまま絞れば本人のものだけになる
    def account_ids_with_children(user_id, element_type, account_id)
      model = TWO_LEVEL_MODELS[element_type]
      return [ account_id ] unless model

      available = model.where(user_id: [ nil, user_id ])
      selected = available.where(id: account_id).select(:id)

      available.where(id: selected).or(available.where(parent_id: selected)).pluck(:id)
    end

    # 他人のタグを指定しても何も出ない
    def filter_by_tag(scope, user_id, tag_id)
      tagged = Debit.joins(debit_tags: :tag).where(tags: { id: tag_id, user_id: user_id }).select(:journal_id)

      scope.where(id: tagged)
    end

    # { [element_type, account_id] => name }
    def account_names_for(journals)
      entries = journals.flat_map { |journal| journal.debits.to_a + journal.credits.to_a }
      ids_by_element = entries.group_by { |entry| entry.element_type.to_i }.transform_values { |rows| rows.map(&:account_id).uniq }

      {
        ElementType::ASSETS => AssetAccount,
        ElementType::LIABILITIES => LiabilityAccount,
        ElementType::EQUITY => EquityAccount,
        ElementType::REVENUE => RevenueAccount,
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
