# frozen_string_literal: true

require "rails_helper"

RSpec.describe "db/seeds/expense_accounts.rb" do
  def seed
    load Rails.root.join("db/seeds/expense_accounts.rb")
  end

  it "has no dummy root account; top-level accounts have no parent" do
    seed

    expect(ExpenseAccount.where(name: "root")).to be_empty
    expect(ExpenseAccount.where(parent_id: nil).order(:id).pluck(:name)).to eq(%w[食費 娯楽費 交通費 教育費])
  end

  it "puts the sub accounts under their top-level account" do
    seed

    expect(ExpenseAccount.find_by!(name: "外食費").parent.name).to eq("食費")
    expect(ExpenseAccount.find_by!(name: "映画").parent.name).to eq("娯楽費")
  end

  it "makes every account a common account (user_id IS NULL)" do
    seed

    expect(ExpenseAccount.where.not(user_id: nil)).to be_empty
  end

  it "can run repeatedly without creating duplicates" do
    seed

    expect { seed }.not_to change(ExpenseAccount, :count)
  end
end
