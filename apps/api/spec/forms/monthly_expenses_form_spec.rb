# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthlyExpensesForm do
  def form(**params)
    described_class.new(params.transform_keys(&:to_s))
  end

  it "is valid without a month and defaults to the current month" do
    travel_to(Time.utc(2026, 10, 31, 16, 0)) do
      f = form

      expect(f).to be_valid
      # UTC では 10/31 だが、日本時間ではすでに 11/1
      expect(f.month_start).to eq(Date.new(2026, 11, 1))
    end
  end

  it "parses the month as its first day" do
    f = form(month: "2026-02")

    expect(f).to be_valid
    expect(f.month_start).to eq(Date.new(2026, 2, 1))
  end

  it "rejects anything that is not YYYY-MM" do
    %w[2026-13 2026-00 2026-1 2026/10 2026-10-01 abc].each do |month|
      expect(form(month: month)).not_to be_valid, "expected #{month} to be invalid"
    end
  end
end
