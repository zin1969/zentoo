# app/controllers/journals/journals_controller.rb

module Journals
  class JournalsController < ApplicationController
    include Authenticatable

    # DB 関数の引数は INT なので、これより大きい ID の仕訳は存在しない
    MAX_JOURNAL_ID = 2_147_483_647
    private_constant :MAX_JOURNAL_ID

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def index
      form = ListJournalsForm.new(params.permit(:from, :to, :page).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Journals::ListJournalsService.new.call(
        user_id: current_user.id,
        from: form.from_date,
        to: form.to_date,
        page: form.page_number
      )
    end

    # 削除も、新しいトークンは X-Next-Token ヘッダで返す（成功時は本文なし）
    def destroy
      journal_id = Integer(params[:id])

      raise Journals::JournalNotFoundError unless journal_id.between?(1, MAX_JOURNAL_ID)

      Journals::DeleteJournalService.new.call(journal_id: journal_id, user_id: current_user.id)

      head :no_content

    rescue Journals::JournalNotFoundError
      # 存在しない仕訳と他ユーザーの仕訳は区別しない
      render json: { error: "journal_not_found" }, status: :not_found

    rescue Journals::DirectDebitJournalNotDeletableError
      render json: { error: "direct_debit_journal_not_deletable" }, status: :unprocessable_content
    end
  end
end
