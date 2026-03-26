require 'ostruct'

class TokenAuthenticator
  def authenticate!(token)
    raise UnauthorizedError unless token == 'dummy-token'

    # 仮のユーザー情報
    OpenStruct.new(
      id: 1,
      name: 'masa'
    )
  end
end
