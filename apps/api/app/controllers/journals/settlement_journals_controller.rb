# app/controllers/journals/settlement_journals_controller.rb

module Journals
  class SettlementJournalsController < ApplicationController
    include JournalIdParam

    # 存在しない口座・科目・仕訳と、他ユーザーのもの、種別の違うものは区別しない
    rescue_from Journals::SettlementJournals::ReceivableAccountNotFound do
      render_error("receivable_account_not_found", :not_found)
    end

    rescue_from Journals::SettlementJournals::ToAccountNotFound do
      render_error("to_account_not_found", :not_found)
    end

    # 少なく受け取ったのに費用科目でない、多く受け取ったのに収益科目でない場合も含む
    rescue_from Journals::SettlementJournals::DifferenceAccountNotFound do
      render_error("difference_account_not_found", :not_found)
    end

    rescue_from Journals::JournalNotFoundError, Journals::SettlementJournals::JournalNotFound do
      render_error("journal_not_found", :not_found)
    end

    # 精算の仕訳ではない（修正のとき）
    rescue_from Journals::SettlementJournals::NotSettlementJournal do
      render_error("journal_not_editable", :unprocessable_content)
    end

    # 立替金の精算（借方: 入金先・差額の費用、貸方: 立替金・差額の収益）を登録する
    def create
      authenticate

      form = build_form
      return render_invalid(form) unless form.valid?

      journal_id = Journals::SettlementJournalService.new.create(**settlement_attributes(form))

      render json: { journal_id: journal_id, next_token: @next_token }, status: :created
    end

    # 精算の仕訳を修正する。仕訳は作り直されるので、新しい journal_id を返す
    def update
      authenticate

      journal_id = journal_id_param
      form = build_form
      return render_invalid(form) unless form.valid?

      new_journal_id = Journals::SettlementJournalService.new.replace(journal_id: journal_id, **settlement_attributes(form))

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
      SettlementJournalForm.new(
        params.permit(
          :journal_date, :receivable_account_id, :settled_amount, :received_amount,
          :to_account_id, :difference_account_id, :description
        ).to_h
      )
    end

    # 持ち主は認証済みユーザーなので、user_id は受け取らない
    def settlement_attributes(form)
      {
        journal_date: form.journal_date,
        receivable_account_id: form.receivable_account_id,
        settled_amount: form.settled_amount,
        received_amount: form.received_amount,
        to_account_id: form.to_account_id_or_nil,
        difference_account_id: form.difference_account_id_or_nil,
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
