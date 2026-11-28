# frozen_string_literal: true

module Tags
  # タグの一覧・追加・名前の変更・削除。タグはユーザーごと
  class TagsService
    class NotFound < StandardError; end
    class DuplicateName < StandardError; end
    class UsedByBudget < StandardError; end

    Item = Struct.new(:tag, :usage_count, keyword_init: true)

    # 作った順に返す（日本語の名前の並びは読みの順にならないため）
    #
    # @return [Array<Item>] タグと、付いている明細の数
    def list(user:)
      tags = user.tags.order(:id).to_a
      counts = DebitTag.where(tag_id: tags.map(&:id)).group(:tag_id).count

      tags.map { |tag| Item.new(tag: tag, usage_count: counts.fetch(tag.id, 0)) }
    end

    def create!(user:, name:)
      Tag.transaction do
        check_name!(user, name)
        user.tags.create!(name: name)
      end
    end

    def update!(user:, id:, name:)
      Tag.transaction do
        tag = find!(user, id)
        check_name!(user, name, except: tag)
        tag.update!(name: name)
        tag
      end
    end

    # 明細で使っているタグも削除できる。明細からタグが外れるだけで、明細は消えない（DB の ON DELETE CASCADE）。
    # 予算の除くタグからも外れる。予算の対象にしているタグは、先に予算を消すか対象を変えてもらう（予算が黙って消えないように）
    def destroy!(user:, id:)
      Tag.transaction do
        tag = find!(user, id)
        raise UsedByBudget if Budget.where(tag_id: tag.id).exists?

        tag.destroy!
      end
    end

    private

    # 他ユーザーのタグと存在しないタグは区別しない。同時に変更・削除されないよう、行をロックする
    def find!(user, id)
      user.tags.lock.find_by(id: id) || raise(NotFound)
    end

    def check_name!(user, name, except: nil)
      raise DuplicateName if user.tags.where(name: name).where.not(id: except&.id).exists?
    end
  end
end
