# app/controllers/reports/monthly_expenses_controller.rb

module Reports
  class MonthlyExpensesController < ApplicationController
    include Authenticatable

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def index
      form = MonthlyExpensesForm.new(params.permit(:month).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Reports::MonthlyExpensesService.new.call(
        user_id: current_user.id,
        month: form.month_start
      )
    end
  end
end
