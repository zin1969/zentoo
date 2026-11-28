# app/controllers/reports/budget_reports_controller.rb

module Reports
  class BudgetReportsController < ApplicationController
    include Authenticatable

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def index
      # 基準日の検証は残高 API と同じ
      form = AccountBalancesForm.new(params.permit(:date).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Reports::BudgetReportService.new.call(user: current_user, as_of: form.as_of_date)
    end
  end
end
