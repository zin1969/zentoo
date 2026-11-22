# frozen_string_literal: true

module Accounts
  # 科目が仕訳か決まった支払いで使われているか。どちらも科目を ID で参照していて外部キーが無いため、ここで確かめる
  module AccountUsage
    # 決まった支払いの借方の科目の種別（支出は費用、収入は入金先の資産）
    RECURRING_DEBIT_KINDS = { ElementType::EXPENSES => 1, ElementType::ASSETS => 2 }.freeze

    module_function

    # 仕訳か決まった支払いで使われている科目。使われている科目は削除させない
    #
    # @return [Set<Integer>] ids のうち、使われている科目の ID
    def used(element_type:, ids:, user_id: nil)
      used_in_journals(element_type: element_type, ids: ids, user_id: user_id) |
        used_in_recurring_entries(element_type: element_type, ids: ids, user_id: user_id)
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
      debit_kind = RECURRING_DEBIT_KINDS[element_type]
      debit_ids = debit_kind ? entries.where(kind: debit_kind, debit_account_id: ids).distinct.pluck(:debit_account_id) : []
      credit_ids = entries.where(credit_element_type: element_type, credit_account_id: ids).distinct.pluck(:credit_account_id)

      (debit_ids + credit_ids).to_set
    end
  end
end
