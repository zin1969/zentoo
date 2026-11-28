# app/controllers/budgets_controller.rb

# 予算の設定（費用科目かタグごとの、週・月・年の額）
class BudgetsController < ApplicationController
  include Authenticatable

  PERMITTED = [
    :name, :target_type, :expense_account_id, :tag_id, :period_type, :amount,
    { monthly_amounts: [], excluded_tag_ids: [] }
  ].freeze

  # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
  rescue_from Budgets::BudgetsService::NotFound do
    # 存在しない予算と他ユーザーの予算は区別しない
    render_error("budget_not_found", :not_found)
  end

  rescue_from Budgets::BudgetsService::ExpenseAccountNotFound do
    render_error("expense_account_not_found", :not_found)
  end

  rescue_from Budgets::BudgetsService::TagNotFound do
    render_error("tag_not_found", :not_found)
  end

  def index
    budgets = Budgets::BudgetsService.new.list(user: current_user)

    render json: budgets.map { |budget| Budgets::BudgetPresenter.present(budget) }
  end

  def create
    form = build_form
    return render_invalid(form) unless form.valid?

    budget = Budgets::BudgetsService.new.create!(
      user: current_user, attributes: form.to_attributes, excluded_tag_ids: form.excluded_tag_id_list
    )

    render json: { id: budget.id, next_token: next_token }, status: :created
  end

  def update
    form = build_form
    return render_invalid(form) unless form.valid?

    budget = Budgets::BudgetsService.new.update!(
      user: current_user, id: params[:id], attributes: form.to_attributes, excluded_tag_ids: form.excluded_tag_id_list
    )

    render json: { id: budget.id, next_token: next_token }, status: :ok
  end

  # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
  def destroy
    Budgets::BudgetsService.new.destroy!(user: current_user, id: params[:id])

    head :no_content
  end

  private

  # monthly_amounts を省くか null にすると、毎月同じ額（amount）になる
  def build_form
    BudgetForm.new(params.permit(*PERMITTED).to_h)
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
