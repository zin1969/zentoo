# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TokenManager do
  describe '#issue_next_token' do
    let(:user) { create(:user) }

    it 'issues a JWT that decodes back to the user id' do
      token = described_class.new.issue_next_token(user)

      payload = JWT.decode(
        token, JwtSettings.secret_key, true, algorithm: JwtSettings::ALGORITHM
      ).first

      expect(payload['sub']).to eq(user.id)
    end

    it 'sets an expiration in the future' do
      token = described_class.new.issue_next_token(user)

      payload = JWT.decode(
        token, JwtSettings.secret_key, true, algorithm: JwtSettings::ALGORITHM
      ).first

      expect(payload['exp']).to be_within(5).of(JwtSettings::EXPIRATION.from_now.to_i)
    end
  end
end
