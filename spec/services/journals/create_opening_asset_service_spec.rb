# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Journals::CreateOpeningAssetService do
  describe '#call' do
    let(:repository) { instance_double(Journals::CreateOpeningAsset) }
    let(:service) { described_class.new(repository: repository) }

    let(:journal_date) { Date.new(2026, 2, 1) }
    let(:asset_type) { instance_double(ElementType) }
    let(:asset_account_id) { 123 }
    let(:amount) { instance_double(Amount) }
    let(:user_id) { 1 }

    context 'when repository succeeds' do
      it 'calls repository within a transaction and returns journal_id' do
        allow(repository).to receive(:create_opening_asset_balance!)
          .and_return(456)

        result = service.call(
          journal_date: journal_date,
          asset_type: asset_type,
          asset_account_id: asset_account_id,
          amount: amount,
          user_id: user_id
        )

        expect(repository).to have_received(:create_opening_asset_balance!).with(
          journal_date: journal_date,
          asset_type: asset_type,
          asset_account_id: asset_account_id,
          amount: amount,
          user_id: user_id
        )

        expect(result).to eq(456)
      end
    end

    context 'when repository raises OpeningAssetAlreadyExists' do
      it 'propagates the exception' do
        allow(repository).to receive(:create_opening_asset_balance!)
          .and_raise(Journals::CreateOpeningAsset::OpeningAssetAlreadyExists)

        expect {
          service.call(
            journal_date: journal_date,
            asset_type: asset_type,
            asset_account_id: asset_account_id,
            amount: amount,
            user_id: user_id
          )
        }.to raise_error(Journals::CreateOpeningAsset::OpeningAssetAlreadyExists)
      end
    end
  end
end
