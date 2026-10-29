# app/controllers/journals/journals_controller.rb

module Journals
  class JournalsController < ApplicationController
    include Authenticatable

    # 配列系の参照 API（マスタ）と同じく、トークンのローテーションは行わない
    def index
      form = ListJournalsForm.new(params.permit(:from, :to, :page).to_h)

      unless form.valid?
        return render json: { errors: form.errors.full_messages }, status: :unprocessable_content
      end

      render json: Journals::ListJournalsService.new.call(
        user_id: current_user.id,
        from: form.from_date,
        to: form.to_date,
        page: form.page_number
      )
    end
  end
end
