# app/controllers/journals/asset_opening_journals_controller.rb

module Journals
  class AssetOpeningJournalsController < ApplicationController
    def create
      # 1. Authorization ヘッダ取得
      token = request.headers['Authorization']&.split(' ')&.last

      # 2. 認証
      user = TokenAuthenticator.new.authenticate!(token)

      # 5. 次トークン発行
      next_token = TokenManager.new.issue_next_token

      # 3. Form 生成
      form = CreateOpeningAssetBalanceJournalForm.new(
        journal_date: params[:journal_date],
        asset_type: ElementType.new(params[:asset_type]),
        asset_account_id: params[:asset_account_id],
        amount: Amount.new(params[:amount])
      )

      unless form.valid?
        return render json: {
          errors: form.errors.full_messages,
          next_token: next_token
        }, status: :unprocessable_content
      end

      # 4. Service 実行
      journal_id = Journals::CreateOpeningAssetService.new.call(
        journal_date: form.journal_date,
        asset_type: form.asset_type,
        asset_account_id: form.asset_account_id,
        amount: form.amount,
        user_id: user.id
      )

      render json: {
        journal_id: journal_id,
        next_token: next_token
      }, status: :created
    end
  end
end
