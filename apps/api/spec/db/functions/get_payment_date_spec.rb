# frozen_string_literal: true

require "rails_helper"

RSpec.describe "get_payment_date / get_next_business_day / get_last_date_of_month" do
  def select_date(sql, *binds)
    value = ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array([ "SELECT #{sql}", *binds ])
    )
    value&.to_date
  end

  def payment_date(cutoff_day, payment_day, journal_date)
    select_date("get_payment_date(?, ?, ?::DATE)", cutoff_day, payment_day, journal_date)
  end

  describe "get_last_date_of_month" do
    it "returns the last day of the month" do
      expect(select_date("get_last_date_of_month(?, ?)", 2026, 2)).to eq(Date.new(2026, 2, 28))
      expect(select_date("get_last_date_of_month(?, ?)", 2028, 2)).to eq(Date.new(2028, 2, 29))
      expect(select_date("get_last_date_of_month(?, ?)", 2026, 12)).to eq(Date.new(2026, 12, 31))
    end
  end

  describe "get_next_business_day" do
    before do
      holiday_type = HolidayType.create!(name: "成人の日")
      Holiday.create!(holiday: Date.new(2026, 1, 12), holiday_type: holiday_type)
    end

    it "returns a weekday as is" do
      expect(select_date("get_next_business_day(?::DATE)", "2026-01-09")).to eq(Date.new(2026, 1, 9))
    end

    it "skips weekends" do
      expect(select_date("get_next_business_day(?::DATE)", "2026-01-10")).to eq(Date.new(2026, 1, 13)) # 土 → 月は祝日 → 火
      expect(select_date("get_next_business_day(?::DATE)", "2026-01-17")).to eq(Date.new(2026, 1, 19)) # 土 → 月
    end

    it "skips registered holidays" do
      expect(select_date("get_next_business_day(?::DATE)", "2026-01-12")).to eq(Date.new(2026, 1, 13))
    end
  end

  describe "get_payment_date" do
    context "when the cutoff day is before the payment day (cutoff 10, payment 27)" do
      it "pays in the same month for a purchase on or before the cutoff day" do
        expect(payment_date(10, 27, "2025-11-09")).to eq(Date.new(2025, 11, 27))
        expect(payment_date(10, 27, "2025-11-10")).to eq(Date.new(2025, 11, 27))
      end

      it "pays in the next month for a purchase after the cutoff day" do
        # 2025-12-27 は土曜のため、翌営業日の月曜
        expect(payment_date(10, 27, "2025-11-11")).to eq(Date.new(2025, 12, 29))
      end
    end

    context "when the cutoff day is after the payment day (cutoff 15, payment 10)" do
      before do
        holiday_type = HolidayType.create!(name: "成人の日")
        Holiday.create!(holiday: Date.new(2026, 1, 12), holiday_type: holiday_type)
      end

      it "pays in the next month for a purchase on or before the cutoff day" do
        expect(payment_date(15, 10, "2025-11-15")).to eq(Date.new(2025, 12, 10))
      end

      it "pays in the month after next for a purchase after the cutoff day, moving past weekend and holiday" do
        # 2026-01-10 は土曜、12 日は祝日のため 13 日
        expect(payment_date(15, 10, "2025-11-25")).to eq(Date.new(2026, 1, 13))
      end
    end

    context "when the cutoff day is the end of the month (cutoff 31, payment 27)" do
      it "pays on the 27th of the next month" do
        expect(payment_date(31, 27, "2026-01-31")).to eq(Date.new(2026, 2, 27))
        expect(payment_date(31, 27, "2026-02-28")).to eq(Date.new(2026, 3, 27))
      end
    end

    context "when the cutoff or payment day does not exist in the month" do
      it "treats the 30th cutoff as the last day of February" do
        # 2/28 は締日（2 月は末日扱い）以内。支払日 31 日は 2/28 に丸められ、土曜のため 3/2（月）
        expect(payment_date(30, 31, "2026-02-28")).to eq(Date.new(2026, 3, 2))
      end

      it "treats the 31st payment day as the last day of a 30-day month" do
        expect(payment_date(15, 31, "2026-04-10")).to eq(Date.new(2026, 4, 30))
      end
    end
  end
end
