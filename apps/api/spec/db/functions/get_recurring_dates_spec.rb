# frozen_string_literal: true

require "rails_helper"

# 決まった支払いの予定日（月単位: 開始日の月から N ヶ月ごとの D 日。31 日は月末）
RSpec.describe "get_recurring_dates" do
  # interval_unit: 1 = 月単位、2 = 週単位
  def dates(count:, day:, start:, from:, to:, end_date: nil, unit: 1, weekday: nil)
    ActiveRecord::Base.connection.select_values(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT get_recurring_dates(?, ?, ?, ?, ?::DATE, ?::DATE, ?::DATE, ?::DATE)",
        unit, count, day, weekday, start, end_date, from, to
      ])
    ).map(&:to_date)
  end

  it "returns the day of every month in the period" do
    expect(dates(count: 1, day: 27, start: "2026-11-01", from: "2026-11-01", to: "2027-02-28")).to eq(
      [ Date.new(2026, 11, 27), Date.new(2026, 12, 27), Date.new(2027, 1, 27), Date.new(2027, 2, 27) ]
    )
  end

  it "uses the last day for a day the month does not have, so 31 is the month end" do
    expect(dates(count: 1, day: 31, start: "2027-01-01", from: "2027-01-01", to: "2027-04-30")).to eq(
      [ Date.new(2027, 1, 31), Date.new(2027, 2, 28), Date.new(2027, 3, 31), Date.new(2027, 4, 30) ]
    )
    expect(dates(count: 12, day: 30, start: "2027-02-01", from: "2027-01-01", to: "2028-12-31")).to eq(
      [ Date.new(2027, 2, 28), Date.new(2028, 2, 29) ]
    )
  end

  it "counts every N months from the month of the start date, so 12 months is every year" do
    expect(dates(count: 3, day: 10, start: "2026-11-10", from: "2026-11-01", to: "2027-11-30")).to eq(
      [ Date.new(2026, 11, 10), Date.new(2027, 2, 10), Date.new(2027, 5, 10), Date.new(2027, 8, 10), Date.new(2027, 11, 10) ]
    )
    expect(dates(count: 12, day: 15, start: "2026-11-15", from: "2026-01-01", to: "2029-01-31")).to eq(
      [ Date.new(2026, 11, 15), Date.new(2027, 11, 15), Date.new(2028, 11, 15) ]
    )
  end

  it "leaves out the dates before the start date and after the end date" do
    expect(dates(count: 1, day: 10, start: "2026-11-27", from: "2026-11-01", to: "2027-01-31")).to eq(
      [ Date.new(2026, 12, 10), Date.new(2027, 1, 10) ]
    )
    expect(dates(count: 1, day: 10, start: "2026-11-01", end_date: "2026-12-09", from: "2026-11-01", to: "2027-01-31"))
      .to eq([ Date.new(2026, 11, 10) ])
  end

  it "starts from the right step when the period begins long after the start date" do
    expect(dates(count: 3, day: 5, start: "2026-01-05", from: "2026-08-01", to: "2027-03-31")).to eq(
      [ Date.new(2026, 10, 5), Date.new(2027, 1, 5) ]
    )
    expect(dates(count: 3, day: 5, start: "2026-01-05", end_date: "2026-12-31", from: "2026-08-01", to: "2027-03-31"))
      .to eq([ Date.new(2026, 10, 5) ])
  end

  it "returns nothing when the period is outside the start and end dates" do
    expect(dates(count: 1, day: 10, start: "2027-01-01", from: "2026-11-01", to: "2026-12-31")).to eq([])
    expect(dates(count: 1, day: 10, start: "2026-01-01", end_date: "2026-06-30", from: "2026-11-01", to: "2026-12-31"))
      .to eq([])
  end

  it "does not support weeks yet" do
    expect {
      ActiveRecord::Base.transaction(requires_new: true) do
        dates(unit: 2, count: 1, day: nil, weekday: 5, start: "2026-11-01", from: "2026-11-01", to: "2026-11-30")
      end
    }.to raise_error(ActiveRecord::StatementInvalid, /interval_unit not supported yet/)
  end
end
