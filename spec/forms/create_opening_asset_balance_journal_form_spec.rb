# spec/forms/create_opening_asset_balance_journal_form_spec.rb

require 'rails_helper'

RSpec.describe CreateOpeningAssetBalanceJournalForm do
  subject(:form) { described_class.new(params) }

  let(:journal_date) { Date.new(2025, 1, 1) }
  let(:asset_type)   { ElementType.new(1) }
  let(:amount)       { Amount.new(10_000) }

  let(:params) do
    {
      journal_date: journal_date,
      asset_type: asset_type,
      asset_account_id: 100,
      amount: amount
    }
  end

  describe 'validations' do
    context 'when all parameters are valid' do
      it 'is valid' do
        expect(form).to be_valid
      end
    end

    context 'when journal_date is missing' do
      let(:journal_date) { nil }

      it 'is invalid' do
        expect(form).to be_invalid
        expect(form.errors[:journal_date]).to include("can't be blank")
      end
    end

    context 'when asset_account_id is missing' do
      before { params.delete(:asset_account_id) }

      it 'is invalid' do
        expect(form).to be_invalid
        expect(form.errors[:asset_account_id]).to include("can't be blank")
      end
    end

    context 'when asset_type is not an ElementType' do
      let(:asset_type) { 1 }

      it 'is invalid' do
        expect(form).to be_invalid
        expect(form.errors[:asset_type]).to include('must be an ElementType')
      end
    end

    context 'when amount is not an Amount' do
      let(:amount) { 10_000 }

      it 'is invalid' do
        expect(form).to be_invalid
        expect(form.errors[:amount]).to include('must be an Amount')
      end
    end
  end
end
