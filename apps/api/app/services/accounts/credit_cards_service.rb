# frozen_string_literal: true

module Accounts
  # クレジットカードの追加・変更・削除。
  # カードは負債科目（liability_accounts）と引き落とし設定（credit_cards）の組で、いつも一緒に扱う
  class CreditCardsService
    class NotFound < StandardError; end
    class InUse < StandardError; end
    class DuplicateName < StandardError; end
    class BankAccountNotFound < StandardError; end

    Card = Struct.new(:account, :setting, :in_use, keyword_init: true)

    # 引き落とし設定の無いカードも返す（設定を登録し直せるように）
    #
    # @return [Array<Card>]
    def list(user:)
      accounts = cards_of(user).order(:id).to_a
      settings = user.credit_cards.includes(:bank_account).where(liability_account_id: accounts.map(&:id))
                     .index_by(&:liability_account_id)
      used = in_use_ids(user, accounts.map(&:id))

      accounts.map do |account|
        Card.new(account: account, setting: settings[account.id], in_use: used.include?(account.id))
      end
    end

    def create!(user:, name:, cutoff_day:, payment_day:, bank_account_id:)
      LiabilityAccount.transaction do
        check_name!(user, name)
        bank_account = find_bank_account!(user, bank_account_id)

        account = user.liability_accounts.create!(name: name, liability_type: :credit_card)
        user.credit_cards.create!(
          liability_account: account, bank_account: bank_account, cutoff_day: cutoff_day, payment_day: payment_day
        )
        account
      end
    end

    # 使っているカードも、名前と設定は変えられる。登録済みの引き落とし仕訳は変えない（これから登録する分から使う）
    def update!(user:, id:, name:, cutoff_day:, payment_day:, bank_account_id:)
      LiabilityAccount.transaction do
        account = find!(user, id)
        check_name!(user, name, except: account)
        bank_account = find_bank_account!(user, bank_account_id)

        account.update!(name: name)
        setting = user.credit_cards.find_or_initialize_by(liability_account: account)
        setting.update!(bank_account: bank_account, cutoff_day: cutoff_day, payment_day: payment_day)
        account
      end
    end

    def destroy!(user:, id:)
      LiabilityAccount.transaction do
        account = find!(user, id)
        raise InUse if in_use_ids(user, [ account.id ]).include?(account.id)

        user.credit_cards.where(liability_account: account).delete_all
        account.destroy!
      end
    end

    private

    def cards_of(user)
      user.liability_accounts.credit_card
    end

    # 他ユーザーのカードと存在しないカードは区別しない。同時に変更・削除されないよう、行をロックする
    def find!(user, id)
      cards_of(user).lock.find_by(id: id) || raise(NotFound)
    end

    # 名前は、本人の負債科目の中で重ならないようにする
    def check_name!(user, name, except: nil)
      raise DuplicateName if user.liability_accounts.where(name: name).where.not(id: except&.id).exists?
    end

    # 引き落とし口座は、本人の預金口座だけ
    def find_bank_account!(user, bank_account_id)
      user.asset_accounts.deposit.find_by(id: bank_account_id) || raise(BankAccountNotFound)
    end

    def in_use_ids(user, ids)
      AccountUsage.used(element_type: ElementType::LIABILITIES, ids: ids, user_id: user.id)
    end
  end
end
