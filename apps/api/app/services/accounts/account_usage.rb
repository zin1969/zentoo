# frozen_string_literal: true

module Accounts
  # 科目が仕訳で使われているか。仕訳の明細は科目を ID で参照していて外部キーが無いため、ここで確かめる
  module AccountUsage
    module_function

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
  end
end
