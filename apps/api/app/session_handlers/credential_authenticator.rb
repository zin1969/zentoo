class CredentialAuthenticator
  # ユーザー不在・パスワード未設定・パスワード不一致を区別せず、同じ例外にする
  def authenticate!(name, password)
    user = User.find_by(name: name.to_s)

    raise UnauthorizedError if user.nil? || user.password_digest.blank?
    raise UnauthorizedError unless user.authenticate(password.to_s)

    user
  end
end
