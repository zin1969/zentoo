# frozen_string_literal: true

require 'rails_helper'

# 参照 API（マスタ・仕訳一覧）は、本文に next_token を持てないため
# 新しいトークンを X-Next-Token ヘッダで返す。
RSpec.describe 'X-Next-Token header on read APIs', type: :request do
  let(:user) { create(:user, :masa) }
  let(:headers) { { 'Authorization' => "Bearer #{TokenManager.new.issue_next_token(user)}" } }

  paths = %w[/asset-accounts /liability-accounts /expense-accounts /journals]

  paths.each do |path|
    describe "GET #{path}" do
      it 'returns a fresh token for the authenticated user' do
        get path, headers: headers

        expect(response).to have_http_status(:ok)

        next_token = response.headers['X-Next-Token']
        expect(next_token).to be_present
        expect(TokenAuthenticator.new.authenticate!(next_token)).to eq(user)
      end

      it 'does not return a token when unauthenticated' do
        get path

        expect(response).to have_http_status(:unauthorized)
        expect(response.headers['X-Next-Token']).to be_nil
      end
    end
  end
end
