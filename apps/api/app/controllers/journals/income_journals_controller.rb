# app/controllers/journals/income_journals_controller.rb

module Journals
  class IncomeJournalsController < ApplicationController
    include JournalIdParam

    # 存在しない口座・科目・仕訳と、他ユーザーのものは区別しない
    rescue_from Journals::AssetAccountNotFoundError do
      render_error("asset_account_not_found", :not_found)
    end

    rescue_from Journals::RevenueAccountNotFoundError do
      render_error("revenue_account_not_found", :not_found)
    end

    rescue_from Journals::JournalNotFoundError do
      render_error("journal_not_found", :not_found)
    end

    # 収入の仕訳ではない（修正のとき）
    rescue_from Journals::JournalNotEditableError do
      render_error("journal_not_editable", :unprocessable_content)
    end

    # 収入の仕訳（借方: 入金先の口座、貸方: 収益科目）を登録する
    def create
      authenticate

      form = build_form
      return render_invalid(form) unless form.valid?

      journal_id = Journals::IncomeJournalService.new.create(**income_attributes(form))

      render json: { journal_id: journal_id, next_token: @next_token }, status: :created
    end

    # 収入の仕訳を修正する。仕訳は作り直されるので、新しい journal_id を返す
    def update
      authenticate

      journal_id = journal_id_param
      form = build_form
      return render_invalid(form) unless form.valid?

      new_journal_id = Journals::IncomeJournalService.new.replace(journal_id: journal_id, **income_attributes(form))

      render json: { journal_id: new_journal_id, next_token: @next_token }, status: :ok
    end

    private

    # 書き込み API なので、新しいトークンは本文の next_token で返す（401 を除く）
    def authenticate
      token = request.headers["Authorization"]&.split(" ")&.last
      @user = TokenAuthenticator.new.authenticate!(token)
      @next_token = TokenManager.new.issue_next_token(@user)
    end

    def build_form
      IncomeJournalForm.new(
        params.permit(:journal_date, :asset_account_id, :revenue_account_id, :amount, :description).to_h
      )
    end

    # 持ち主は認証済みユーザーなので、user_id は受け取らない
    def income_attributes(form)
      {
        journal_date: form.journal_date,
        asset_account_id: form.asset_account_id,
        revenue_account_id: form.revenue_account_id,
        amount: form.amount,
        description: form.description,
        user_id: @user.id
      }
    end

    def render_invalid(form)
      render json: { errors: form.errors.full_messages, next_token: @next_token }, status: :unprocessable_content
    end

    def render_error(code, status)
      render json: { error: code, next_token: @next_token }, status: status
    end
  end
end
