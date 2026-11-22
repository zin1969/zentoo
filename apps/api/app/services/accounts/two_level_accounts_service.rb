# frozen_string_literal: true

module Accounts
  # 親子 2 階層の共通科目（費用科目・収益科目）の追加・変更・削除。
  # 追加する科目は全ユーザー共通（user_id IS NULL）。親にできるのは親の無い科目だけ
  class TwoLevelAccountsService
    class NotFound < StandardError; end
    class InUse < StandardError; end
    class HasChildren < StandardError; end
    class InvalidParent < StandardError; end
    class DuplicateName < StandardError; end

    Item = Struct.new(:account, :in_use, :has_children, keyword_init: true)

    # @param model [Class] ExpenseAccount か RevenueAccount
    # @param element_type [Integer] 仕訳で使われているかを調べるときの要素種別
    def initialize(model:, element_type:)
      @model = model
      @element_type = element_type
    end

    # @return [Array<Item>]
    def list(user:)
      accounts = available(user).order(:id).to_a
      used = in_use_ids(accounts.map(&:id))
      parent_ids = accounts.map(&:parent_id).compact.to_set

      accounts.map do |account|
        Item.new(account: account, in_use: used.include?(account.id), has_children: parent_ids.include?(account.id))
      end
    end

    def create!(user:, name:, parent_id:)
      @model.transaction do
        parent = find_parent!(user, parent_id)
        check_name!(user, name, parent_id: parent&.id)

        @model.create!(user: nil, name: name, parent: parent)
      end
    end

    # 名前はいつでも変えられる。親は、使われていない、子科目の無い科目だけ付け替えられる
    def update!(user:, id:, name:, parent_id:)
      @model.transaction do
        account = find!(user, id)
        parent = find_parent!(user, parent_id, except: account)
        check_name!(user, name, parent_id: parent&.id, except: account)

        if account.parent_id != parent&.id
          raise InUse if in_use_ids([ account.id ]).include?(account.id)
          # 親を持つと 3 階層になってしまう
          raise HasChildren if parent && children?(account)
        end

        account.update!(name: name, parent: parent)
        account
      end
    end

    def destroy!(user:, id:)
      @model.transaction do
        account = find!(user, id)
        raise InUse if in_use_ids([ account.id ]).include?(account.id)
        raise HasChildren if children?(account)

        account.destroy!
      end
    end

    private

    def available(user)
      @model.available_to(user)
    end

    # 他ユーザーの科目と存在しない科目は区別しない。同時に変更・削除されないよう、行をロックする
    def find!(user, id)
      available(user).lock.find_by(id: id) || raise(NotFound)
    end

    # 親にできるのは、使える科目のうち親の無い科目（自分自身は除く）
    def find_parent!(user, parent_id, except: nil)
      return nil if parent_id.nil?

      parent = available(user).find_by(id: parent_id, parent_id: nil)
      raise InvalidParent if parent.nil? || parent.id == except&.id

      parent
    end

    # 同じ親の中で、同じ名前の科目は作らない
    def check_name!(user, name, parent_id:, except: nil)
      duplicate = available(user).where(name: name, parent_id: parent_id).where.not(id: except&.id).exists?
      raise DuplicateName if duplicate
    end

    def children?(account)
      @model.exists?(parent_id: account.id)
    end

    # 共通科目なので、全ユーザーの仕訳を見る
    def in_use_ids(ids)
      AccountUsage.used(element_type: @element_type, ids: ids)
    end
  end
end
