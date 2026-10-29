# app/controllers/concerns/authenticatable.rb

# Authorization ヘッダの Bearer トークンでユーザーを認証する。
# 失敗時は UnauthorizedError を送出し、ApplicationController が 401 を返す。
# 認証に成功した参照 API は、画面を開いたままでも期限切れにならないよう、
# 新しいトークンをレスポンスヘッダ X-Next-Token で返す（本文は配列などで next_token を持てないため）。
module Authenticatable
  extend ActiveSupport::Concern

  NEXT_TOKEN_HEADER = "X-Next-Token"

  included do
    before_action :authenticate_user!
  end

  private

  attr_reader :current_user

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last

    @current_user = TokenAuthenticator.new.authenticate!(token)

    response.set_header(NEXT_TOKEN_HEADER, TokenManager.new.issue_next_token(@current_user))
  end
end
