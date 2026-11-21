# app/controllers/accounts/credit_cards_controller.rb

module Accounts
  class CreditCardsController < ApplicationController
    include Authenticatable

    # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
    rescue_from Accounts::CreditCardsService::NotFound do
      # 存在しないカードと他ユーザーのカードは区別しない
      render_error("credit_card_not_found", :not_found)
    end

    rescue_from Accounts::CreditCardsService::BankAccountNotFound do
      # 存在しない口座、他ユーザーの口座、預金口座ではない口座は区別しない
      render_error("bank_account_not_found", :not_found)
    end

    rescue_from Accounts::CreditCardsService::InUse do
      render_error("credit_card_in_use", :unprocessable_content)
    end

    rescue_from Accounts::CreditCardsService::DuplicateName do
      render_error("duplicate_account_name", :unprocessable_content)
    end

    def index
      cards = Accounts::CreditCardsService.new.list(user: current_user).map do |card|
        {
          id: card.account.id,
          name: card.account.name,
          # 引き落とし設定の無いカードは null（設定を登録し直すまで、カード払いの登録ができない）
          cutoff_day: card.setting&.cutoff_day,
          payment_day: card.setting&.payment_day,
          bank_account_id: card.setting&.bank_account_id,
          bank_account_name: card.setting&.bank_account&.name,
          # 仕訳で使われている。削除できない
          in_use: card.in_use
        }
      end

      render json: cards
    end

    def create
      form = CreditCardForm.new(permitted_params)
      return render_invalid(form) unless form.valid?

      account = Accounts::CreditCardsService.new.create!(user: current_user, **card_attributes(form))

      render json: { id: account.id, next_token: next_token }, status: :created
    end

    def update
      form = CreditCardForm.new(permitted_params)
      return render_invalid(form) unless form.valid?

      account = Accounts::CreditCardsService.new.update!(user: current_user, id: params[:id], **card_attributes(form))

      render json: { id: account.id, next_token: next_token }, status: :ok
    end

    # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
    def destroy
      Accounts::CreditCardsService.new.destroy!(user: current_user, id: params[:id])

      head :no_content
    end

    private

    def permitted_params
      params.permit(:name, :cutoff_day, :payment_day, :bank_account_id).to_h
    end

    def card_attributes(form)
      {
        name: form.name,
        cutoff_day: form.cutoff_day,
        payment_day: form.payment_day,
        bank_account_id: form.bank_account_id
      }
    end

    def next_token
      response.headers[Authenticatable::NEXT_TOKEN_HEADER]
    end

    def render_invalid(form)
      render json: { errors: form.errors.full_messages, next_token: next_token }, status: :unprocessable_content
    end

    def render_error(code, status)
      render json: { error: code, next_token: next_token }, status: status
    end
  end
end
