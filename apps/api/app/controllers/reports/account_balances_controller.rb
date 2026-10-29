# app/controllers/reports/account_balances_controller.rb

module Reports
  class AccountBalancesController < ApplicationController
    include Authenticatable

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def index
      form = AccountBalancesForm.new(params.permit(:date).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Reports::AccountBalancesService.new.call(
        user_id: current_user.id,
        as_of: form.as_of_date
      )
    end
  end
end
