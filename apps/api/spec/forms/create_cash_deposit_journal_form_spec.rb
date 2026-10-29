# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreateCashDepositJournalForm do
  def form(**params)
    described_class.new({ journal_date: "2026-10-30", bank_account_id: 1, amount: 45_000 }.merge(params))
  end

  it "is valid with a date, an account id and an amount" do
    f = form

    expect(f).to be_valid
    expect(f.journal_date).to eq(Date.new(2026, 10, 30))
  end

  it "requires a date" do
    expect(form(journal_date: nil)).not_to be_valid
    expect(form(journal_date: "2026-02-30")).not_to be_valid
  end

  it "requires a positive integer account id" do
    [ nil, 0, -1, "1", 1.5 ].each do |value|
      expect(form(bank_account_id: value)).not_to be_valid, "expected #{value.inspect} to be invalid"
    end
  end

  it "requires an integer amount between 1 and the INT maximum" do
    [ nil, 0, -1, "1000", 1.5 ].each do |value|
      expect(form(amount: value)).not_to be_valid, "expected #{value.inspect} to be invalid"
    end

    expect(form(amount: 1)).to be_valid
    expect(form(amount: 2_147_483_647)).to be_valid
    expect(form(amount: 2_147_483_648)).not_to be_valid
  end
end
