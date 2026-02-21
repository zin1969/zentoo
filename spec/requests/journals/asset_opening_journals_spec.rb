# frozen_string_literal: true
#
# spec/requests/journals/asset_opening_journals_spec.rb

require 'rails_helper'
require 'ostruct'

RSpec.describe 'POST /asset-opening-journals', type: :request do
  let(:path) { '/asset-opening-journals' }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:token) { 'dummy-token' }

  let(:params) do
    {
      journal_date: '2026-02-01',
      asset_type: 1,
      asset_account_id: 123,
      amount: 100000
    }
  end

  let(:user) { OpenStruct.new(id: 1) }
  let(:authenticator) { instance_double(TokenAuthenticator) }
  let(:form) { instance_double(CreateOpeningAssetBalanceJournalForm) }
  let(:service) { instance_double(Journals::CreateOpeningAssetService) }
  let(:token_manager) { instance_double(TokenManager) }

  let(:errors) { instance_double(ActiveModel::Errors) }

  describe 'success' do
    before do
      # Auth
      allow(TokenAuthenticator).to receive(:new).and_return(authenticator)
      allow(authenticator).to receive(:authenticate!).and_return(user)

      # Form
      allow(CreateOpeningAssetBalanceJournalForm)
        .to receive(:new)
        .and_return(form)

      allow(form).to receive(:valid?).and_return(true)

      allow(form).to receive(:journal_date).and_return(Date.today)
      allow(form).to receive(:asset_type).and_return('cash')
      allow(form).to receive(:asset_account_id).and_return(1)
      allow(form).to receive(:amount).and_return(1000)

      # Service
      allow(Journals::CreateOpeningAssetService)
        .to receive(:new)
        .and_return(service)

      allow(service).to receive(:call).and_return(456)

      # Token
      allow(TokenManager).to receive(:new).and_return(token_manager)
      allow(token_manager)
        .to receive(:issue_next_token)
        .and_return('abc.def.ghi')
    end

    it 'returns 201 and next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:created)

      body = JSON.parse(response.body)

      expect(body['journal_id']).to eq(456)
      expect(body['next_token']).to eq('abc.def.ghi')
    end
  end

  describe 'validation error' do
    before do
      allow_any_instance_of(TokenAuthenticator)
        .to receive(:authenticate!)
        .and_return(OpenStruct.new(id: 1))

      form = instance_double(CreateOpeningAssetBalanceJournalForm)
      allow(CreateOpeningAssetBalanceJournalForm)
        .to receive(:new)
        .and_return(form)

      allow(form).to receive(:valid?).and_return(false)
      allow(form).to receive(:errors).and_return(errors)
      allow(errors).to receive(:full_messages)
        .and_return(
          double(to_hash: {
            asset_type: ['must be an ElementType']
          })
        )

      allow_any_instance_of(TokenManager)
        .to receive(:issue_next_token)
        .and_return('abc.def.ghi')
    end

    it 'returns 422 and errors with next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)

      body = JSON.parse(response.body)

      expect(body['errors']['asset_type'])
        .to include('must be an ElementType')

      expect(body['next_token']).to eq('abc.def.ghi')
    end
  end

  describe 'authorization error' do
    before do
      allow_any_instance_of(TokenAuthenticator)
        .to receive(:authenticate!)
        .and_raise(TokenAuthenticator::InvalidToken)
    end

    it 'returns 401 without next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:unauthorized)

      body = JSON.parse(response.body)

      expect(body['error']).to eq('invalid_token')
      expect(body).not_to have_key('next_token')
    end
  end

  describe 'business error (duplicate)' do
    before do
      allow_any_instance_of(TokenAuthenticator)
        .to receive(:authenticate!)
        .and_return(OpenStruct.new(id: 1))

      form = instance_double(CreateOpeningAssetBalanceJournalForm)
      allow(CreateOpeningAssetBalanceJournalForm)
        .to receive(:new)
        .and_return(form)

      allow(form).to receive(:valid?).and_return(true)

      service = instance_double(Journals::CreateOpeningAssetService)
      allow(Journals::CreateOpeningAssetService)
        .to receive(:new)
        .and_return(service)

      allow(service)
        .to receive(:call)
        .and_raise(StandardError.new('opening_asset_already_exists'))

      allow_any_instance_of(TokenManager)
        .to receive(:issue_next_token)
        .and_return('abc.def.ghi')
    end

    it 'returns 409 with next_token' do
      post path, params: params.to_json, headers: headers

      expect(response).to have_http_status(:conflict)

      body = JSON.parse(response.body)

      expect(body['error']).to eq('opening_asset_already_exists')
      expect(body['next_token']).to eq('abc.def.ghi')
    end
  end
end
