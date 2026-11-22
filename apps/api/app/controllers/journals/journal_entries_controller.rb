# app/controllers/journals/journal_entries_controller.rb

module Journals
  class JournalEntriesController < ApplicationController
    include JournalIdParam

    def create
      # 1. Authorization ヘッダ取得
      token = request.headers["Authorization"]&.split(" ")&.last

      # 2. 認証
      user = TokenAuthenticator.new.authenticate!(token)

      # 3. 次トークン発行
      next_token = TokenManager.new.issue_next_token(user)

      # 4. Form 生成（バリデーション込み。失敗時は ArgumentError を送出）
      form = InsertJournalEntryForm.new(request.raw_post)

      # 5. Service 実行（user_id は認証済みユーザーのもので上書きする）
      journal_id = Journals::InsertJournalEntryService.new.call(
        journal_data: form.validated_data.merge(user_id: user.id)
      )

      render json: {
        journal_id: journal_id,
        next_token: next_token
      }, status: :created

    rescue ArgumentError => e
      render json: {
        errors: [ e.message ],
        next_token: next_token
      }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::AccountNotFound
      render json: {
        error: "account_not_found",
        next_token: next_token
      }, status: :not_found

    rescue Journals::InsertJournalEntry::CreditCardSettingNotFound
      render json: {
        error: "credit_card_setting_not_found",
        next_token: next_token
      }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::UnbalancedJournal
      render json: {
        error: "unbalanced_journal",
        next_token: next_token
      }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::TagNotFound
      # 存在しないタグと他ユーザーのタグは区別しない
      render json: {
        error: "tag_not_found",
        next_token: next_token
      }, status: :not_found

    rescue Journals::InsertJournalEntry::TagsOnlyForExpenseDebits
      render json: {
        error: "tags_only_for_expense_debits",
        next_token: next_token
      }, status: :unprocessable_content
    end

    # お買い物の仕訳を修正する。本文は登録と同じ。仕訳は作り直されるので、新しい journal_id を返す
    def update
      token = request.headers["Authorization"]&.split(" ")&.last
      user = TokenAuthenticator.new.authenticate!(token)
      next_token = TokenManager.new.issue_next_token(user)

      journal_id = journal_id_param
      form = InsertJournalEntryForm.new(request.raw_post)

      new_journal_id = Journals::ReplaceJournalEntryService.new.call(
        journal_id: journal_id,
        journal_data: form.validated_data.merge(user_id: user.id)
      )

      render json: {
        journal_id: new_journal_id,
        next_token: next_token
      }, status: :ok

    rescue ArgumentError => e
      render json: { errors: [ e.message ], next_token: next_token }, status: :unprocessable_content

    rescue Journals::JournalNotFoundError
      # 存在しない仕訳と他ユーザーの仕訳は区別しない
      render json: { error: "journal_not_found", next_token: next_token }, status: :not_found

    rescue Journals::DirectDebitJournalNotEditableError
      render json: { error: "direct_debit_journal_not_editable", next_token: next_token }, status: :unprocessable_content

    rescue Journals::JournalNotEditableError
      render json: { error: "journal_not_editable", next_token: next_token }, status: :unprocessable_content

    rescue Journals::ExpenseDebitsRequiredError
      render json: { error: "expense_debits_required", next_token: next_token }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::AccountNotFound
      render json: { error: "account_not_found", next_token: next_token }, status: :not_found

    rescue Journals::InsertJournalEntry::CreditCardSettingNotFound
      render json: { error: "credit_card_setting_not_found", next_token: next_token }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::UnbalancedJournal
      render json: { error: "unbalanced_journal", next_token: next_token }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::TagNotFound
      render json: { error: "tag_not_found", next_token: next_token }, status: :not_found

    rescue Journals::InsertJournalEntry::TagsOnlyForExpenseDebits
      render json: { error: "tags_only_for_expense_debits", next_token: next_token }, status: :unprocessable_content
    end
  end
end
