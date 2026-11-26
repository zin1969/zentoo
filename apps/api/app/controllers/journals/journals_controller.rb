# app/controllers/journals/journals_controller.rb

module Journals
  class JournalsController < ApplicationController
    include Authenticatable
    include JournalIdParam

    # 存在しない仕訳と他ユーザーの仕訳は区別しない
    rescue_from Journals::JournalNotFoundError do
      render json: { error: "journal_not_found" }, status: :not_found
    end

    # 期間・キーワード・科目・タグで絞り込める（すべて AND）。
    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def index
      form = ListJournalsForm.new(params.permit(:from, :to, :page, :q, :element_type, :account_id, :tag_id).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Journals::ListJournalsService.new.call(
        user_id: current_user.id,
        from: form.from_date,
        to: form.to_date,
        page: form.page_number,
        keyword: form.keyword,
        account: form.account,
        tag_id: form.tag
      )
    end

    # 修正画面の初期値に使う。形は一覧の 1 件と同じ
    def show
      render json: Journals::ShowJournalService.new.call(journal_id: journal_id_param, user_id: current_user.id)
    end

    # 削除も、新しいトークンは X-Next-Token ヘッダで返す（成功時は本文なし）
    def destroy
      Journals::DeleteJournalService.new.call(journal_id: journal_id_param, user_id: current_user.id)

      head :no_content

    rescue Journals::DirectDebitJournalNotDeletableError
      render json: { error: "direct_debit_journal_not_deletable" }, status: :unprocessable_content
    end
  end
end
