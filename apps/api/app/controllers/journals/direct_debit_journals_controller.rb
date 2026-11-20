# app/controllers/journals/direct_debit_journals_controller.rb

module Journals
  class DirectDebitJournalsController < ApplicationController
    include JournalIdParam

    # カード払いの引き落とし仕訳の日付だけを変える
    def update
      token = request.headers["Authorization"]&.split(" ")&.last
      user = TokenAuthenticator.new.authenticate!(token)
      next_token = TokenManager.new.issue_next_token(user)

      journal_id = journal_id_param
      form = UpdateDirectDebitDateForm.new(params.permit(:payment_date).to_h)

      unless form.valid?
        return render json: {
          errors: form.errors.full_messages,
          next_token: next_token
        }, status: :unprocessable_content
      end

      Journals::UpdateDirectDebitDateService.new.call(
        journal_id: journal_id,
        payment_date: form.payment_date,
        user_id: user.id
      )

      render json: {
        journal_id: journal_id,
        next_token: next_token
      }, status: :ok

    rescue Journals::JournalNotFoundError
      # 存在しない仕訳と他ユーザーの仕訳は区別しない
      render json: { error: "journal_not_found", next_token: next_token }, status: :not_found

    rescue Journals::NotDirectDebitJournalError
      render json: { error: "not_direct_debit_journal", next_token: next_token }, status: :unprocessable_content

    rescue Journals::PaymentDateBeforeJournalDateError
      render json: { error: "payment_date_before_journal_date", next_token: next_token }, status: :unprocessable_content
    end
  end
end
