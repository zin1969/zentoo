# app/controllers/reports/tag_reports_controller.rb

module Reports
  class TagReportsController < ApplicationController
    include Authenticatable

    # 存在しないタグと他ユーザーのタグは区別しない
    rescue_from Reports::TagReportService::TagNotFound do
      render json: { error: "tag_not_found" }, status: :not_found
    end

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
    def show
      form = TagReportForm.new(params.permit(:year).to_h)
      return render_invalid(form) unless form.valid?

      render json: Reports::TagReportService.new.monthly(user: current_user, tag_id: params[:id], year: form.target_year)
    end

    # 月をタップしたときの、その月の明細
    def items
      form = TagReportForm.new(params.permit(:month).to_h)
      return render_invalid(form) unless form.valid?

      render json: Reports::TagReportService.new.items(
        user: current_user, tag_id: params[:id], month_start: form.month_start
      )
    end

    private

    def render_invalid(form)
      render json: { errors: form.errors.full_messages }, status: :unprocessable_content
    end
  end
end
