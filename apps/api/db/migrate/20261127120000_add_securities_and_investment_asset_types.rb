class AddSecuritiesAndInvestmentAssetTypes < ActiveRecord::Migration[8.1]
  # 資産の種別に 4 = 証券口座（預り金）、5 = 投資（iDeCo・積立 NISA・株式など）を足す。
  # 振替は、出す元の口座の種別を貸方の支払い方法（payment_method_type）にそのまま入れるので、貸方の制約も広げる。
  # down は、新しい種別の口座や仕訳が残っていると制約の追加に失敗する（消してから戻す）
  def up
    execute <<~SQL
      ALTER TABLE asset_accounts DROP CONSTRAINT asset_account_asset_type;
      ALTER TABLE asset_accounts
        ADD CONSTRAINT asset_account_asset_type CHECK (asset_type IN (1, 2, 3, 4, 5));

      ALTER TABLE credits DROP CONSTRAINT credit_payment_method_type;
      ALTER TABLE credits
        ADD CONSTRAINT credit_payment_method_type CHECK (
          (element_type = 1 AND payment_method_type IN (1, 2, 3, 4, 5))
          OR (element_type = 2 AND payment_method_type IN (1, 2, 3))
          OR (element_type IN (3, 4, 5) AND payment_method_type = 0)
        );
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE credits DROP CONSTRAINT credit_payment_method_type;
      ALTER TABLE credits
        ADD CONSTRAINT credit_payment_method_type CHECK (
          (element_type = 1 AND payment_method_type IN (1, 2, 3))
          OR (element_type = 2 AND payment_method_type IN (1, 2, 3))
          OR (element_type IN (3, 4, 5) AND payment_method_type = 0)
        );

      ALTER TABLE asset_accounts DROP CONSTRAINT asset_account_asset_type;
      ALTER TABLE asset_accounts
        ADD CONSTRAINT asset_account_asset_type CHECK (asset_type IN (1, 2, 3));
    SQL
  end
end
