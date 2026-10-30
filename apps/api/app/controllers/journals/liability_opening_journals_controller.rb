# app/controllers/journals/liability_opening_journals_controller.rb

module Journals
  class LiabilityOpeningJournalsController < ApplicationController
    def create
      # 1. Authorization ヘッダ取得
      token = request.headers["Authorization"]&.split(" ")&.last

      # 2. 認証
      user = TokenAuthenticator.new.authenticate!(token)

      # 3. 次トークン発行
      next_token = TokenManager.new.issue_next_token(user)

      # 4. Form 生成
      form = CreateOpeningLiabilityBalanceJournalForm.new(
        params.permit(:journal_date, :liability_account_id, :amount, :payment_date).to_h
      )

      unless form.valid?
        return render json: {
          errors: form.errors.full_messages,
          next_token: next_token
        }, status: :unprocessable_content
      end

      # 5. Service 実行
      journal_id = Journals::CreateOpeningLiabilityService.new.call(
        journal_date: form.journal_date,
        liability_account_id: form.liability_account_id,
        amount: form.amount,
        payment_date: form.payment_date,
        user_id: user.id
      )

      render json: {
        journal_id: journal_id,
        next_token: next_token
      }, status: :created

    rescue Journals::OpeningLiabilityAlreadyExistsError
      render json: {
        error: "opening_liability_already_exists",
        next_token: next_token
      }, status: :conflict

    rescue Journals::LiabilityAccountNotFoundError
      # 存在しない科目、他ユーザーの科目、カードではない科目は区別しない
      render json: {
        error: "liability_account_not_found",
        next_token: next_token
      }, status: :not_found

    rescue Journals::PaymentDateBeforeJournalDateError
      render json: {
        error: "payment_date_before_journal_date",
        next_token: next_token
      }, status: :unprocessable_content

    rescue Journals::CreditCardSettingNotFoundError
      render json: {
        error: "credit_card_setting_not_found",
        next_token: next_token
      }, status: :unprocessable_content
    end
  end
end
