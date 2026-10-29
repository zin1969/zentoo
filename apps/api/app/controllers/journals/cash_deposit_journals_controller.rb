# app/controllers/journals/cash_deposit_journals_controller.rb

module Journals
  class CashDepositJournalsController < ApplicationController
    def create
      # 1. Authorization ヘッダ取得
      token = request.headers["Authorization"]&.split(" ")&.last

      # 2. 認証
      user = TokenAuthenticator.new.authenticate!(token)

      # 3. 次トークン発行
      next_token = TokenManager.new.issue_next_token(user)

      # 4. Form 生成（持ち主は認証済みユーザーなので、user_id は受け取らない）
      form = CreateCashDepositJournalForm.new(
        params.permit(:journal_date, :bank_account_id, :amount).to_h
      )

      unless form.valid?
        return render json: {
          errors: form.errors.full_messages,
          next_token: next_token
        }, status: :unprocessable_content
      end

      # 5. Service 実行
      journal_id = Journals::CreateCashDepositService.new.call(
        journal_date: form.journal_date,
        bank_account_id: form.bank_account_id,
        amount: form.amount,
        user_id: user.id
      )

      render json: {
        journal_id: journal_id,
        next_token: next_token
      }, status: :created

    rescue Journals::AssetAccountNotFoundError
      # 存在しない科目、他ユーザーの科目、預金口座ではない科目は区別しない
      render json: {
        error: "asset_account_not_found",
        next_token: next_token
      }, status: :not_found

    rescue Journals::CashAccountNotDeterminedError
      render json: {
        error: "cash_account_not_determined",
        next_token: next_token
      }, status: :unprocessable_content
    end
  end
end
