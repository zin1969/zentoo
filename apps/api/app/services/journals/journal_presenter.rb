# frozen_string_literal: true

module Journals
  # 仕訳一覧・仕訳 1 件の API で、仕訳を同じ形の JSON にする
  module JournalPresenter
    module_function

    def present(journal, result)
      # この仕訳が引き落とし仕訳の場合の、元のカード払い仕訳との紐付け
      direct_debit_link = result.direct_debit_links.find { |link| link.direct_debit_id == journal.id }

      {
        id: journal.id,
        journal_date: journal.journal_dt,
        store_name: journal.store_name,
        debits: journal.debits.sort_by(&:id).map do |debit|
          {
            element_type: debit.element_type.to_i,
            account_id: debit.account_id,
            account_name: account_name(result, debit),
            item_name: debit.item_name,
            amount: debit.amount.to_i,
            # 外税のレシートで登録した明細の税率（%）と税抜の金額。内税の明細は null。消費税は amount - tax_excluded_amount
            tax_rate: debit.tax_rate,
            tax_excluded_amount: debit.tax_excluded_amount,
            # 株の銘柄の株数（開始残高・買い）。それ以外の明細は null
            shares: debit.shares,
            # 明細に付いているタグ（お買い物の費用の明細だけ）
            tags: debit.tags.sort_by(&:id).map { |tag| { id: tag.id, name: tag.name } }
          }
        end,
        credits: journal.credits.sort_by(&:id).map do |credit|
          {
            element_type: credit.element_type.to_i,
            payment_method_type: credit.payment_method_type,
            account_id: credit.account_id,
            account_name: account_name(result, credit),
            amount: credit.amount.to_i,
            # 株の銘柄の株数（売り）。それ以外の明細は null
            shares: credit.shares
          }
        end,
        # この仕訳が引き落とし仕訳の場合、元のカード払い仕訳の ID
        original_journal_id: direct_debit_link&.original_id,
        # 引き落とし仕訳の日付を手で変えたか（引き落とし仕訳以外は false）
        payment_date_overridden: direct_debit_link&.payment_date_overridden || false,
        # この仕訳がカード払いの場合、引き落とし仕訳の ID
        direct_debit_journal_id: result.direct_debit_links.find { |link| link.original_id == journal.id }&.direct_debit_id
      }
    end

    def account_name(result, entry)
      result.account_names[[ entry.element_type.to_i, entry.account_id ]]
    end
  end
end
