module SessionHandlers
  class TokenAuthenticator
    InvalidToken = Class.new(StandardError)

    def authenticate!(token)
      raise InvalidToken unless token == 'dummy-token'

      # 仮のユーザー情報
      OpenStruct.new(
        id: 1,
        name: 'masa'
      )
    end
  end
end
