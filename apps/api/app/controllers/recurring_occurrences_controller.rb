# app/controllers/recurring_occurrences_controller.rb

# 決まった支払いの回: 今月の末日までの未登録の回の一覧と、確かめてからの登録・飛ばす
class RecurringOccurrencesController < ApplicationController
  include Authenticatable

  # 登録・飛ばすのエラーも、本文に新しいトークンを載せる（BFF が Cookie を更新する）
  rescue_from RecurringEntries::OccurrencesService::NotFound do
    # 存在しない決まった支払いと他ユーザーのものは区別しない
    render_error("recurring_entry_not_found", :not_found)
  end

  rescue_from RecurringEntries::OccurrencesService::NotScheduled do
    render_error("not_scheduled_date", :unprocessable_content)
  end

  rescue_from RecurringEntries::OccurrencesService::AlreadyRecorded, ActiveRecord::RecordNotUnique do
    render_error("occurrence_already_recorded", :unprocessable_content)
  end

  # 決まった支払いを作ったあとで、科目が使えなくなった場合
  rescue_from RecurringEntries::OccurrencesService::AccountNotFound,
              Journals::InsertJournalEntry::AccountNotFound,
              Journals::IncomeJournals::AssetAccountNotFound,
              Journals::IncomeJournals::RevenueAccountNotFound do
    render_error("account_not_found", :not_found)
  end

  rescue_from Journals::InsertJournalEntry::CreditCardSettingNotFound do
    render_error("credit_card_setting_not_found", :unprocessable_content)
  end

  def index
    items = RecurringEntries::OccurrencesService.new.pending(user: current_user)

    render json: items.map { |item| present(item) }
  end

  def create
    form = RecurringOccurrenceForm.new(params.permit(:scheduled_date, :date, :amount).to_h)
    return render_invalid(form) unless form.valid?(:register)

    journal_id = RecurringEntries::OccurrencesService.new.register!(
      user: current_user, id: params[:id], scheduled_date: form.scheduled_date, amount: form.amount, date: form.date
    )

    render json: { journal_id: journal_id, next_token: next_token }, status: :created
  end

  def skip
    form = RecurringOccurrenceForm.new(params.permit(:scheduled_date).to_h)
    return render_invalid(form) unless form.valid?

    RecurringEntries::OccurrencesService.new.skip!(user: current_user, id: params[:id], scheduled_date: form.scheduled_date)

    render json: { next_token: next_token }, status: :created
  end

  private

  def present(item)
    entry = item.entry

    {
      recurring_entry_id: entry.id, scheduled_date: item.scheduled_date,
      name: entry.name, kind: entry.kind, amount: entry.amount, store_name: entry.store_name, item_name: entry.item_name,
      debit_account_name: item.debit_account_name, credit_account_name: item.credit_account_name,
      interval_unit: entry.interval_unit, interval_count: entry.interval_count
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
