# app/controllers/reports/bank_account_ledgers_controller.rb

module Reports
  class BankAccountLedgersController < ApplicationController
    include Authenticatable

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def show
      form = BankAccountLedgerForm.new(params.permit(:from, :to).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Reports::BankAccountLedgerService.new.call(
        user: current_user,
        asset_account_id: params[:id],
        from: form.from_date,
        to: form.to_date
      )

    rescue Reports::BankAccountLedgerService::AssetAccountNotFound
      # 存在しない口座、他ユーザーの口座、預金ではない口座は区別しない
      render json: { error: "asset_account_not_found" }, status: :not_found
    end
  end
end
