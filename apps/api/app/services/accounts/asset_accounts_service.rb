# frozen_string_literal: true

module Accounts
  # 口座（現金・預金・電子マネー）の追加・変更・削除
  class AssetAccountsService
    class NotFound < StandardError; end
    class InUse < StandardError; end
    class DuplicateName < StandardError; end
    class CashAccountAlreadyExists < StandardError; end

    # @return [Array<[AssetAccount, Boolean]>] 口座と、使われているか（削除・種別の変更ができないか）
    def list(user:)
      accounts = user.asset_accounts.order(:id).to_a
      used = in_use_ids(user, accounts.map(&:id))

      accounts.map { |account| [ account, used.include?(account.id) ] }
    end

    # @param asset_type [String] AssetAccount.asset_types のキー
    def create!(user:, name:, asset_type:)
      AssetAccount.transaction do
        check_name!(user, name)
        check_single_cash!(user, asset_type)

        user.asset_accounts.create!(name: name, asset_type: asset_type)
      end
    end

    # 名前はいつでも変えられる。種別は、使われていない口座だけ変えられる
    def update!(user:, id:, name:, asset_type:)
      AssetAccount.transaction do
        account = find!(user, id)
        check_name!(user, name, except: account)

        if account.asset_type != asset_type
          raise InUse if in_use?(user, account)

          check_single_cash!(user, asset_type, except: account)
        end

        account.update!(name: name, asset_type: asset_type)
        account
      end
    end

    def destroy!(user:, id:)
      AssetAccount.transaction do
        account = find!(user, id)
        raise InUse if in_use?(user, account)

        account.destroy!
      end
    end

    private

    # 他ユーザーの口座と存在しない口座は区別しない。同時に変更・削除されないよう、行をロックする
    def find!(user, id)
      user.asset_accounts.lock.find_by(id: id) || raise(NotFound)
    end

    def check_name!(user, name, except: nil)
      raise DuplicateName if user.asset_accounts.where(name: name).where.not(id: except&.id).exists?
    end

    # 現金の預け入れは、現金の口座が 1 つに決まることを前提にしている
    def check_single_cash!(user, asset_type, except: nil)
      return unless asset_type == "cash"

      raise CashAccountAlreadyExists if user.asset_accounts.cash.where.not(id: except&.id).exists?
    end

    def in_use?(user, account)
      in_use_ids(user, [ account.id ]).include?(account.id)
    end

    # 仕訳か決まった支払いで使われている口座と、カードの引き落とし口座になっている口座
    def in_use_ids(user, ids)
      AccountUsage.used(element_type: ElementType::ASSETS, ids: ids, user_id: user.id) |
        user.credit_cards.where(bank_account_id: ids).distinct.pluck(:bank_account_id)
    end
  end
end
