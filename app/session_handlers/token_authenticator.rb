class TokenAuthenticator
  def authenticate!(token)
    raise UnauthorizedError if token.blank?

    payload = decode(token)
    user = User.find_by(id: payload['sub'])

    raise UnauthorizedError if user.nil?

    user
  end

  private

  def decode(token)
    JWT.decode(
      token,
      JwtSettings.secret_key,
      true,
      algorithm: JwtSettings::ALGORITHM
    ).first
  rescue JWT::DecodeError
    raise UnauthorizedError
  end
end
