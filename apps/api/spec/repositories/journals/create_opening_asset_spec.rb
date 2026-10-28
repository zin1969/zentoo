# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::CreateOpeningAsset do
  subject(:repository) { described_class.new }

  describe ".create_opening_asset_balance!" do
    let(:user) { create(:user, :masa) }
    let(:asset_account) { create(:asset_account, :cash, user: user) }
    let!(:equity_account) { create(:equity_account, :original_deposit, user: user) }

    let(:journal_date) { Date.new(2025, 1, 1) }
    let(:asset_type) { ElementType.new(1) }
    let(:amount) { Amount.new(100_000) }

    it "creates opening asset balance journal via postgres function" do
      # --- act ---
      journal_id = repository.create_opening_asset_balance!(
        journal_date: journal_date,
        asset_type: asset_type,
        asset_account_id: asset_account.id,
        amount: amount,
        user_id: user.id
      )

      # --- assert ---
      expect(journal_id).to be_present

      journal = Journal.find(journal_id)

      expect(journal.journal_dt).to eq(journal_date)
      expect(journal.store_name).to eq(asset_account.name)
      expect(journal.user_id).to eq(user.id)

      debit = journal.debits.first
      expect(debit.element_type).to eq(1)
      expect(debit.account_id).to eq(asset_account.id)
      expect(debit.item_name).to eq("開始残高")
      expect(debit.amount).to eq(amount)
      expect(debit.user_id).to eq(user.id)

      credit = journal.credits.first
      expect(credit.element_type).to eq(3)
      expect(credit.account_id).to eq(equity_account.id)
      expect(credit.amount).to eq(amount)
      expect(credit.user_id).to eq(user.id)
    end

    context "when the opening balance of the account is already registered" do
      def register(account)
        repository.create_opening_asset_balance!(
          journal_date: journal_date,
          asset_type: asset_type,
          asset_account_id: account.id,
          amount: amount,
          user_id: user.id
        )
      end

      before { register(asset_account) }

      it "raises OpeningAssetAlreadyExists and does not create another journal" do
        count_before = Journal.count

        # DB 関数の例外でトランザクションが中断状態にならないよう、セーブポイントで包む
        expect { ActiveRecord::Base.transaction(requires_new: true) { register(asset_account) } }
          .to raise_error(described_class::OpeningAssetAlreadyExists)
        expect(Journal.count).to eq(count_before)
      end

      it "allows an opening balance for a different account" do
        other_account = create(:asset_account, :suica, user: user)

        expect { register(other_account) }.to change { Journal.count }.by(1)
      end
    end
  end
end
