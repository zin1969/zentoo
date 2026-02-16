module SessionHandlers
  class TokenManager
    InvalidToken = Class.new(StandardError)

    def validate!(token)
      raise InvalidToken unless token == 'dummy-token'
    end

    def issue_next_token
      'dummy-next-token'
    end
  end
end
