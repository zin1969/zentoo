# app/controllers/journals/transfer_journals_controller.rb

module Journals
  class TransferJournalsController < ApplicationController
    include JournalIdParam

    # 存在しない口座・カード・仕訳と、他ユーザーのものは区別しない
    rescue_from Journals::TransferJournals::FromAccountNotFound do
      render_error("from_account_not_found", :not_found)
    end

    rescue_from Journals::TransferJournals::ToAccountNotFound do
      render_error("to_account_not_found", :not_found)
    end

    rescue_from Journals::TransferJournals::SameAccount do
      render_error("same_account", :unprocessable_content)
    end

    rescue_from Journals::TransferJournals::CreditCardChargeRequiresEMoney do
      render_error("credit_card_charge_requires_e_money", :unprocessable_content)
    end

    # 立替金から返してもらうのは精算（POST /settlement-journals）で登録する
    rescue_from Journals::TransferJournals::ReceivableRequiresSettlement do
      render_error("receivable_requires_settlement", :unprocessable_content)
    end

    rescue_from Journals::TransferJournals::CreditCardSettingNotFound do
      render_error("credit_card_setting_not_found", :unprocessable_content)
    end

    rescue_from Journals::JournalNotFoundError, Journals::TransferJournals::JournalNotFound do
      render_error("journal_not_found", :not_found)
    end

    # 振替の仕訳ではない（修正のとき）
    rescue_from Journals::TransferJournals::NotTransferJournal do
      render_error("journal_not_editable", :unprocessable_content)
    end

    # 振替の仕訳（借方: 入れる先の口座、貸方: 出す元の口座かカード）を登録する
    def create
      authenticate

      form = build_form
      return render_invalid(form) unless form.valid?

      journal_id = Journals::TransferJournalService.new.create(**transfer_attributes(form))

      render json: { journal_id: journal_id, next_token: @next_token }, status: :created
    end

    # 振替の仕訳を修正する。仕訳は作り直されるので、新しい journal_id を返す
    def update
      authenticate

      journal_id = journal_id_param
      form = build_form
      return render_invalid(form) unless form.valid?

      new_journal_id = Journals::TransferJournalService.new.replace(journal_id: journal_id, **transfer_attributes(form))

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
      TransferJournalForm.new(
        params.permit(:journal_date, :from_type, :from_account_id, :to_account_id, :amount, :description).to_h
      )
    end

    # 持ち主は認証済みユーザーなので、user_id は受け取らない
    def transfer_attributes(form)
      {
        journal_date: form.journal_date,
        from_element_type: form.from_element_type,
        from_account_id: form.from_account_id,
        to_account_id: form.to_account_id,
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
