# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TokenAuthenticator do
  describe '#authenticate!' do
    let(:user) { create(:user) }

    def token_for(payload)
      JWT.encode(payload, JwtSettings.secret_key, JwtSettings::ALGORITHM)
    end

    it 'returns the user encoded in a valid token' do
      token = token_for(sub: user.id, exp: 1.minute.from_now.to_i)

      expect(described_class.new.authenticate!(token)).to eq(user)
    end

    it 'raises UnauthorizedError when the token is blank' do
      expect { described_class.new.authenticate!(nil) }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the token is malformed' do
      expect { described_class.new.authenticate!('not-a-jwt') }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the token is expired' do
      token = token_for(sub: user.id, exp: 1.minute.ago.to_i)

      expect { described_class.new.authenticate!(token) }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the token is signed with a different secret' do
      token = JWT.encode({ sub: user.id, exp: 1.minute.from_now.to_i }, 'wrong-secret', JwtSettings::ALGORITHM)

      expect { described_class.new.authenticate!(token) }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the user does not exist' do
      token = token_for(sub: -1, exp: 1.minute.from_now.to_i)

      expect { described_class.new.authenticate!(token) }.to raise_error(UnauthorizedError)
    end
  end
end
