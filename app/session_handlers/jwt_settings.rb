module JwtSettings
  ALGORITHM = 'HS256'
  EXPIRATION = 15.minutes

  def self.secret_key
    ENV.fetch('JWT_SECRET_KEY') { Rails.application.secret_key_base }
  end
end
