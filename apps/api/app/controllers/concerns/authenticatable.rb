# app/controllers/concerns/authenticatable.rb

# Authorization ヘッダの Bearer トークンでユーザーを認証する。
# 失敗時は UnauthorizedError を送出し、ApplicationController が 401 を返す。
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  attr_reader :current_user

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last

    @current_user = TokenAuthenticator.new.authenticate!(token)
  end
end
