# frozen_string_literal: true

require "rails_helper"

RSpec.describe Journals::CreateCashDeposit do
  subject(:repository) { described_class.new }

  let(:user) { create(:user, :masa) }
  let!(:cash) { create(:asset_account, :cash, user: user) }
  let!(:bank) { create(:asset_account, :mufg_yoga, user: user) }

  # DB 関数の RAISE でテスト全体のトランザクションが中断されないよう、savepoint の中で呼ぶ
  def create_deposit(bank_account_id:, amount: 45_000, owner: user)
    ActiveRecord::Base.transaction(requires_new: true) do
      repository.create_cash_deposit!(
        journal_date: Date.new(2025, 12, 9),
        bank_account_id: bank_account_id,
        amount: amount,
        user_id: owner.id
      )
    end
  end

  def deposit(account: bank, amount: 45_000, owner: user)
    create_deposit(bank_account_id: account.id, amount: amount, owner: owner)
  end

  it "debits the bank account and credits the user's cash account" do
    journal = Journal.find(deposit)

    expect(journal.journal_dt).to eq(Date.new(2025, 12, 9))
    expect(journal.store_name).to eq(bank.name)
    expect(journal.user_id).to eq(user.id)

    debit = journal.debits.sole
    expect([ debit.element_type.to_i, debit.account_id, debit.item_name, debit.amount.to_i, debit.user_id ])
      .to eq([ 1, bank.id, "預入", 45_000, user.id ])

    credit = journal.credits.sole
    expect([ credit.element_type.to_i, credit.payment_method_type, credit.account_id, credit.amount.to_i, credit.user_id ])
      .to eq([ 1, 1, cash.id, 45_000, user.id ])
  end

  it "rejects an amount of 0 or less" do
    expect { deposit(amount: 0) }.to raise_error(ActiveRecord::StatementInvalid, /amount must be greater than 0/)
    expect { deposit(amount: -1) }.to raise_error(ActiveRecord::StatementInvalid, /amount must be greater than 0/)
  end

  describe "bank account check" do
    it "rejects another user's account the same way as a missing one" do
      other_bank = create(:asset_account, :mufg_yoga, user: create(:user))

      expect { deposit(account: other_bank) }.to raise_error(described_class::AssetAccountNotFound)
      expect { create_deposit(bank_account_id: 0) }.to raise_error(described_class::AssetAccountNotFound)
    end

    it "rejects an account that is not a deposit account" do
      suica = create(:asset_account, :suica, user: user)

      expect { deposit(account: cash) }.to raise_error(described_class::AssetAccountNotFound)
      expect { deposit(account: suica) }.to raise_error(described_class::AssetAccountNotFound)
    end

    it "creates nothing when it fails" do
      other_bank = create(:asset_account, :mufg_yoga, user: create(:user))

      expect do
        expect { deposit(account: other_bank) }.to raise_error(described_class::AssetAccountNotFound)
      end.not_to change(Journal, :count)
    end
  end

  describe "cash account check" do
    it "raises when the user has no cash account" do
      cash.destroy!

      expect { deposit }.to raise_error(described_class::CashAccountNotDetermined)
    end

    it "raises when the user has more than one cash account" do
      create(:asset_account, :cash, user: user, name: "へそくり")

      expect { deposit }.to raise_error(described_class::CashAccountNotDetermined)
    end

    it "does not use another user's cash account" do
      cash.destroy!
      create(:asset_account, :cash, user: create(:user))

      expect { deposit }.to raise_error(described_class::CashAccountNotDetermined)
    end

    it "creates nothing when it fails" do
      cash.destroy!

      expect do
        expect { deposit }.to raise_error(described_class::CashAccountNotDetermined)
      end.not_to change(Journal, :count)
    end
  end
end
