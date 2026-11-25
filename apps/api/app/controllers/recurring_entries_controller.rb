# app/controllers/recurring_entries_controller.rb

# 決まった支払い（家賃・サブスク・給料など）の設定。登録は回ごとに確かめてから行う
class RecurringEntriesController < ApplicationController
  include Authenticatable

  PERMITTED = %i[
    name kind store_name item_name amount debit_account_id credit_element_type credit_account_id
    interval_unit interval_count day_of_month weekday start_date end_date
  ].freeze

  # 追加・変更・削除のエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
  rescue_from RecurringEntries::RecurringEntriesService::NotFound do
    # 存在しない決まった支払いと他ユーザーのものは区別しない
    render_error("recurring_entry_not_found", :not_found)
  end

  rescue_from RecurringEntries::RecurringEntriesService::AccountNotFound do
    render_error("account_not_found", :not_found)
  end

  def index
    items = RecurringEntries::RecurringEntriesService.new.list(user: current_user)

    render json: items.map { |item| present(item) }
  end

  def create
    form = RecurringEntryForm.new(params.permit(*PERMITTED).to_h)
    return render_invalid(form) unless form.valid?

    entry = RecurringEntries::RecurringEntriesService.new.create!(user: current_user, attributes: form.to_attributes)

    render json: { id: entry.id, next_token: next_token }, status: :created
  end

  def update
    form = RecurringEntryForm.new(params.permit(*PERMITTED).to_h)
    return render_invalid(form) unless form.valid?

    entry = RecurringEntries::RecurringEntriesService.new.update!(
      user: current_user, id: params[:id], attributes: form.to_attributes
    )

    render json: { id: entry.id, next_token: next_token }, status: :ok
  end

  # 削除は本文を返さない（新しいトークンは X-Next-Token ヘッダで返る）
  def destroy
    RecurringEntries::RecurringEntriesService.new.destroy!(user: current_user, id: params[:id])

    head :no_content
  end

  private

  def present(item)
    item.entry.slice(
      :id, :name, :kind, :store_name, :item_name, :amount, :debit_account_id, :credit_element_type, :credit_account_id,
      :interval_unit, :interval_count, :day_of_month, :weekday, :start_date, :end_date
    ).merge(
      debit_account_name: item.debit_account_name,
      credit_account_name: item.credit_account_name,
      next_date: item.next_date
    )
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
