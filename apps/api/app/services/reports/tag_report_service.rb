# frozen_string_literal: true

module Reports
  # タグの集計。1 つの明細に複数のタグを付けると、タグごとの合計を足しても支出の合計と合わない
  class TagReportService
    class TagNotFound < StandardError; end

    def initialize(repository: TagReports.new)
      @repository = repository
    end

    # 年の月ごとの合計と、年の合計
    def monthly(user:, tag_id:, year:)
      tag = find_tag!(user, tag_id)
      months = @repository.monthly_totals(user_id: user.id, tag_id: tag.id, year: year)

      {
        tag: { id: tag.id, name: tag.name },
        year: year,
        total: months.sum(&:amount),
        months: months.map { |row| { month: row.month, amount: row.amount } }
      }
    rescue TagReports::TagNotFound
      raise TagNotFound
    end

    # 月の明細と、その合計
    def items(user:, tag_id:, month_start:)
      tag = find_tag!(user, tag_id)
      items = @repository.items(user_id: user.id, tag_id: tag.id, from: month_start, to: month_start.end_of_month)

      {
        tag: { id: tag.id, name: tag.name },
        month: month_start.strftime("%Y-%m"),
        total: items.sum(&:amount),
        items: items.map(&:to_h)
      }
    rescue TagReports::TagNotFound
      raise TagNotFound
    end

    private

    # 他ユーザーのタグと存在しないタグは区別しない
    def find_tag!(user, tag_id)
      user.tags.find_by(id: tag_id) || raise(TagNotFound)
    end
  end
end
