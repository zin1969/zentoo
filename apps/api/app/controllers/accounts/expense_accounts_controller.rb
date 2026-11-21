# app/controllers/accounts/expense_accounts_controller.rb

module Accounts
  class ExpenseAccountsController < ApplicationController
    include Authenticatable

    # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
    rescue_from Accounts::ExpenseAccountsService::NotFound do
      # 存在しない科目と他ユーザーの科目は区別しない
      render_error("expense_account_not_found", :not_found)
    end

    rescue_from Accounts::ExpenseAccountsService::InUse do
      render_error("expense_account_in_use", :unprocessable_content)
    end

    rescue_from Accounts::ExpenseAccountsService::HasChildren do
      render_error("expense_account_has_children", :unprocessable_content)
    end

    rescue_from Accounts::ExpenseAccountsService::InvalidParent do
      render_error("invalid_parent", :unprocessable_content)
    end

    rescue_from Accounts::ExpenseAccountsService::DuplicateName do
      render_error("duplicate_account_name", :unprocessable_content)
    end

    def index
      accounts = Accounts::ExpenseAccountsService.new.list(user: current_user).map do |item|
        {
          id: item.account.id,
          name: item.account.name,
          # 親の科目の ID（トップレベルの科目は null）
          parent_id: item.account.parent_id,
          # 仕訳で使われている。削除と親の付け替えができない
          in_use: item.in_use,
          # 子科目がある。削除できない
          has_children: item.has_children
        }
      end

      render json: accounts
    end

    def create
      form = ExpenseAccountForm.new(params.permit(:name, :parent_id).to_h)
      return render_invalid(form) unless form.valid?

      account = Accounts::ExpenseAccountsService.new.create!(
        user: current_user, name: form.name, parent_id: form.parent_id
      )

      render json: { id: account.id, next_token: next_token }, status: :created
    end

    def update
      form = ExpenseAccountForm.new(params.permit(:name, :parent_id).to_h)
      return render_invalid(form) unless form.valid?

      account = Accounts::ExpenseAccountsService.new.update!(
        user: current_user, id: params[:id], name: form.name, parent_id: form.parent_id
      )

      render json: { id: account.id, next_token: next_token }, status: :ok
    end

    # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
    def destroy
      Accounts::ExpenseAccountsService.new.destroy!(user: current_user, id: params[:id])

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
