# app/controllers/sessions_controller.rb

class SessionsController < ApplicationController
  # ブルートフォース対策。Next.js 経由のため remote_ip は BFF のものになるが、個人利用の規模では問題ない
  rate_limit to: 10, within: 3.minutes, only: :create

  def create
    user = CredentialAuthenticator.new.authenticate!(params[:name], params[:password])

    render json: { token: TokenManager.new.issue_next_token(user) }, status: :created
  end
end
