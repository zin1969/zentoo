# app/controllers/journals/journals_controller.rb

module Journals
  class JournalsController < ApplicationController
    include Authenticatable

    # 参照 API なので本文に next_token は載せない（新しいトークンは X-Next-Token ヘッダで返る）
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
