# frozen_string_literal: true

module Accounts
  # 科目が仕訳か決まった支払いか予算で使われているか。仕訳と決まった支払いは科目を ID で参照していて外部キーが無いため、ここで確かめる
  module AccountUsage
    # 決まった支払いの借方の科目の種別（支出は費用、収入と振替は入金先の資産）
    RECURRING_DEBIT_KINDS = { ElementType::EXPENSES => [ 1 ], ElementType::ASSETS => [ 2, 3 ] }.freeze

    module_function

    # 仕訳か決まった支払いか予算で使われている科目。使われている科目は削除させない
    #
    # @return [Set<Integer>] ids のうち、使われている科目の ID
    def used(element_type:, ids:, user_id: nil)
      used_in_journals(element_type: element_type, ids: ids, user_id: user_id) |
        used_in_recurring_entries(element_type: element_type, ids: ids, user_id: user_id) |
        used_in_budgets(element_type: element_type, ids: ids, user_id: user_id)
    end

    # 予算の対象は費用科目だけ（外部キーがあるので、使っている科目は DB でも消せない）
    #
    # @return [Set<Integer>] ids のうち、予算で使われている科目の ID
    def used_in_budgets(element_type:, ids:, user_id: nil)
      return Set.new if ids.empty? || element_type != ElementType::EXPENSES

      budgets = user_id ? Budget.where(user_id: user_id) : Budget.all
      budgets.where(expense_account_id: ids).distinct.pluck(:expense_account_id).to_set
    end

    # @param user_id [Integer, nil] 指定すると、そのユーザーの仕訳だけを見る（共通の費用科目は全員の仕訳を見る）
    # @return [Set<Integer>] ids のうち、仕訳で使われている科目の ID
    def used_in_journals(element_type:, ids:, user_id: nil)
      return Set.new if ids.empty?

      [ Debit, Credit ].flat_map do |model|
        # element_type は値オブジェクトの型で読み書きしているので、条件は SQL で書く
        scope = model.where("element_type = ?", element_type).where(account_id: ids)
        scope = scope.where(user_id: user_id) if user_id
        scope.distinct.pluck(:account_id)
      end.to_set
    end

    # @return [Set<Integer>] ids のうち、決まった支払いで使われている科目の ID
    def used_in_recurring_entries(element_type:, ids:, user_id: nil)
      return Set.new if ids.empty?

      entries = user_id ? RecurringEntry.where(user_id: user_id) : RecurringEntry.all
      debit_kinds = RECURRING_DEBIT_KINDS[element_type]
      debit_ids = debit_kinds ? entries.where(kind: debit_kinds, debit_account_id: ids).distinct.pluck(:debit_account_id) : []
      credit_ids = entries.where(credit_element_type: element_type, credit_account_id: ids).distinct.pluck(:credit_account_id)

      (debit_ids + credit_ids).to_set
    end
  end
end
