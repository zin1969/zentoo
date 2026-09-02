# app/controllers/journals/journal_entries_controller.rb

module Journals
  class JournalEntriesController < ApplicationController
    def create
      # 1. Authorization ヘッダ取得
      token = request.headers['Authorization']&.split(' ')&.last

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
        errors: [e.message],
        next_token: next_token
      }, status: :unprocessable_content

    rescue Journals::InsertJournalEntry::UnbalancedJournal
      render json: {
        error: 'unbalanced_journal',
        next_token: next_token
      }, status: :unprocessable_content
    end
  end
end
