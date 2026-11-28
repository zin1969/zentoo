# frozen_string_literal: true

module Budgets
  # 予算の一覧・追加・変更・削除。予算はユーザーごと
  class BudgetsService
    class NotFound < StandardError; end
    class ExpenseAccountNotFound < StandardError; end
    class TagNotFound < StandardError; end

    # 周期の順（週・月・年）、同じ周期は作った順に返す
    def list(user:)
      user.budgets.includes(:expense_account, :tag, :excluded_tags).order(:period_type, :id).to_a
    end

    def create!(user:, attributes:, excluded_tag_ids:)
      Budget.transaction do
        check_targets!(user, attributes, excluded_tag_ids)
        budget = user.budgets.create!(attributes)
        replace_excluded_tags!(budget, excluded_tag_ids)
        budget
      end
    end

    def update!(user:, id:, attributes:, excluded_tag_ids:)
      Budget.transaction do
        budget = lock!(user, id)
        check_targets!(user, attributes, excluded_tag_ids)
        budget.update!(attributes)
        replace_excluded_tags!(budget, excluded_tag_ids)
        budget
      end
    end

    # 除くタグの指定も消える（DB の ON DELETE CASCADE）。仕訳は変わらない
    def destroy!(user:, id:)
      lock!(user, id).destroy!
    end

    private

    # 他ユーザーの予算と存在しない予算は区別しない。同時に変更・削除されないよう、行をロックする
    def lock!(user, id)
      user.budgets.lock.find_by(id: id) || raise(NotFound)
    end

    # 費用科目は共通科目か本人の科目、タグは本人のものだけ。他人のものと存在しないものは区別しない
    def check_targets!(user, attributes, excluded_tag_ids)
      if attributes[:expense_account_id] && !ExpenseAccount.available_to(user).exists?(id: attributes[:expense_account_id])
        raise ExpenseAccountNotFound
      end

      tag_ids = [ attributes[:tag_id], *excluded_tag_ids ].compact.uniq
      raise TagNotFound unless user.tags.where(id: tag_ids).count == tag_ids.size
    end

    def replace_excluded_tags!(budget, tag_ids)
      budget.budget_excluded_tags.delete_all
      tag_ids.each { |tag_id| budget.budget_excluded_tags.create!(tag_id: tag_id) }
    end
  end
end
