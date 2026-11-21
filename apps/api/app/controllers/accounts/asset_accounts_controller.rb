# app/controller/accounts/asset_accounts_controller.rb

module Accounts
  class AssetAccountsController < ApplicationController
    include Authenticatable

    # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
    rescue_from Accounts::AssetAccountsService::NotFound do
      # 存在しない口座と他ユーザーの口座は区別しない
      render_error("asset_account_not_found", :not_found)
    end

    rescue_from Accounts::AssetAccountsService::InUse do
      render_error("asset_account_in_use", :unprocessable_content)
    end

    rescue_from Accounts::AssetAccountsService::DuplicateName do
      render_error("duplicate_account_name", :unprocessable_content)
    end

    rescue_from Accounts::AssetAccountsService::CashAccountAlreadyExists do
      render_error("cash_account_already_exists", :unprocessable_content)
    end

    def index
      accounts = Accounts::AssetAccountsService.new.list(user: current_user).map do |account, in_use|
        {
          id: account.id,
          name: account.name,
          element_type: ElementType::ASSETS,
          payment_method_type: AssetAccount.asset_types.fetch(account.asset_type),
          # 仕訳で使われているか、カードの引き落とし口座になっている。削除と種別の変更ができない
          in_use: in_use
        }
      end

      render json: accounts
    end

    def create
      form = AssetAccountForm.new(params.permit(:name, :asset_type).to_h)
      return render_invalid(form) unless form.valid?

      account = Accounts::AssetAccountsService.new.create!(
        user: current_user, name: form.name, asset_type: form.asset_type_key
      )

      render json: { id: account.id, next_token: next_token }, status: :created
    end

    def update
      form = AssetAccountForm.new(params.permit(:name, :asset_type).to_h)
      return render_invalid(form) unless form.valid?

      account = Accounts::AssetAccountsService.new.update!(
        user: current_user, id: params[:id], name: form.name, asset_type: form.asset_type_key
      )

      render json: { id: account.id, next_token: next_token }, status: :ok
    end

    # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
    def destroy
      Accounts::AssetAccountsService.new.destroy!(user: current_user, id: params[:id])

      head :no_content
    end

    private

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
