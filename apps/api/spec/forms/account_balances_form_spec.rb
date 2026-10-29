# frozen_string_literal: true

require "rails_helper"

RSpec.describe AccountBalancesForm do
  def form(**params)
    described_class.new(params.transform_keys(&:to_s))
  end

  it "is valid without a date and defaults to today" do
    travel_to(Time.utc(2026, 10, 29, 16, 0)) do
      f = form

      expect(f).to be_valid
      # UTC では 10/29 だが、日本時間ではすでに 10/30
      expect(f.as_of_date).to eq(Date.new(2026, 10, 30))
    end
  end

  it "parses the date" do
    f = form(date: "2026-10-31")

    expect(f).to be_valid
    expect(f.as_of_date).to eq(Date.new(2026, 10, 31))
  end

  it "rejects a malformed or impossible date" do
    expect(form(date: "2026/10/31")).not_to be_valid
    expect(form(date: "2026-02-30")).not_to be_valid
    expect(form(date: "abc")).not_to be_valid
  end
end
