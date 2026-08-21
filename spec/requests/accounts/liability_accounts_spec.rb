# frozen_string_literal: true
#
# spec/requests/accounts/liability_accounts_spec.rb

require 'rails_helper'

RSpec.describe 'GET /liability-accounts', type: :request do
  let(:user) { create(:user, :masa) }

  before do
    create(:liability_account, :jal, user: user)
  end

  it 'returns 200 with id, name, element_type and payment_method_type' do
    get '/liability-accounts'

    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)

    jal = body.find { |a| a['name'] == 'JAL' }
    expect(jal['element_type']).to eq(2)
    expect(jal['payment_method_type']).to eq(3)
  end
end
