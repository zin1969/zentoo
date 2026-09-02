# frozen_string_literal: true
#
# spec/requests/accounts/asset_accounts_spec.rb

require 'rails_helper'

RSpec.describe 'GET /asset-accounts', type: :request do
  let(:user) { create(:user, :masa) }

  before do
    create(:asset_account, :cash, user: user)
    create(:asset_account, :mufg_yoga, user: user)
  end

  it 'returns 200 with id, name, element_type and payment_method_type' do
    get '/asset-accounts'

    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)

    cash = body.find { |a| a['name'] == '現金' }
    expect(cash['element_type']).to eq(1)
    expect(cash['payment_method_type']).to eq(1)

    deposit = body.find { |a| a['name'] == '三菱UFJ銀行 用賀出張所' }
    expect(deposit['element_type']).to eq(1)
    expect(deposit['payment_method_type']).to eq(2)
  end
end
