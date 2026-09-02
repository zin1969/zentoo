class TokenManager
  def issue_next_token(user)
    payload = {
      sub: user.id,
      exp: JwtSettings::EXPIRATION.from_now.to_i
    }

    JWT.encode(payload, JwtSettings.secret_key, JwtSettings::ALGORITHM)
  end
end
