# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListJournalsForm do
  def form(**params)
    described_class.new(params.transform_keys(&:to_s))
  end

  it "is valid without any parameter and defaults to page 1" do
    f = form

    expect(f).to be_valid
    expect(f.page_number).to eq(1)
    expect(f.from_date).to be_nil
    expect(f.to_date).to be_nil
  end

  it "parses from, to and page" do
    f = form(from: "2026-10-01", to: "2026-10-31", page: "3")

    expect(f).to be_valid
    expect([ f.from_date, f.to_date, f.page_number ]).to eq([ Date.new(2026, 10, 1), Date.new(2026, 10, 31), 3 ])
  end

  it "rejects a malformed or impossible date" do
    expect(form(from: "2026/10/01")).not_to be_valid
    expect(form(to: "2026-02-30")).not_to be_valid
  end

  it "rejects a period whose end is before its start" do
    expect(form(from: "2026-10-31", to: "2026-10-01")).not_to be_valid
  end

  it "accepts a one-day period" do
    expect(form(from: "2026-10-01", to: "2026-10-01")).to be_valid
  end

  it "rejects a page that is not a positive integer" do
    %w[0 -1 abc 1.5].each do |page|
      expect(form(page: page)).not_to be_valid
    end
  end

  it "has no search condition by default" do
    f = form

    expect([ f.keyword, f.account, f.tag ]).to eq([ nil, nil, nil ])
  end

  it "strips the keyword and ignores a blank one" do
    expect(form(q: "  本屋 ").keyword).to eq("本屋")
    expect(form(q: "   ").keyword).to be_nil
  end

  it "parses the account and the tag" do
    f = form(element_type: "5", account_id: "12", tag_id: "3")

    expect(f).to be_valid
    expect(f.account).to eq({ element_type: 5, account_id: 12 })
    expect(f.tag).to eq(3)
  end

  it "requires element_type and account_id together" do
    expect(form(account_id: "12")).not_to be_valid
    expect(form(element_type: "5")).not_to be_valid
  end

  it "rejects an unknown element_type or a malformed id" do
    expect(form(element_type: "0", account_id: "1")).not_to be_valid
    expect(form(element_type: "6", account_id: "1")).not_to be_valid
    expect(form(element_type: "5", account_id: "0")).not_to be_valid
    expect(form(tag_id: "abc")).not_to be_valid
  end
end
