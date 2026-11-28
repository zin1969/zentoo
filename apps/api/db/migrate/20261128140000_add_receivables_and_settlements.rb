class AddReceivablesAndSettlements < ActiveRecord::Migration[8.1]
  # 立て替えた分の精算（M19）。資産の種別に 6 = 立替金を足し、相手ごとに口座を作る（例: 「立替金 田中」「立替金 会社」）。
  # 精算は貸方が立替金になるので、貸方の支払い方法（資産は口座の種別）の制約も広げる。
  # お買い物の修正は、借方に立替金の明細があっても（費用の明細が無くても）直せるようにする。
  # 振替は立替金から出せないようにする（返してもらうのは精算で、差額を費用・収益にできるようにするため）。
  # お買い物・振替の修正は、精算の仕訳を断る（精算の画面で直す）。
  # replace_journal_entry・create_transfer_journal・replace_transfer_journal は CREATE OR REPLACE なので、down では以前の定義へ戻さない。
  # down は、立替金の口座や精算の仕訳が残っていると制約の追加に失敗する（消してから戻す）
  def up
    execute <<~SQL
      ALTER TABLE asset_accounts DROP CONSTRAINT asset_account_asset_type;
      ALTER TABLE asset_accounts
        ADD CONSTRAINT asset_account_asset_type CHECK (asset_type IN (1, 2, 3, 4, 5, 6));

      ALTER TABLE credits DROP CONSTRAINT credit_payment_method_type;
      ALTER TABLE credits
        ADD CONSTRAINT credit_payment_method_type CHECK (
          (element_type = 1 AND payment_method_type IN (1, 2, 3, 4, 5, 6))
          OR (element_type = 2 AND payment_method_type IN (1, 2, 3))
          OR (element_type IN (3, 4, 5) AND payment_method_type = 0)
        );
    SQL

    create_function 'journals/replace_journal_entry.sql'
    create_function 'journals/create_transfer_journal.sql'
    create_function 'journals/replace_transfer_journal.sql'
    create_function 'settlements/create_settlement_journal.sql'
    create_function 'settlements/replace_settlement_journal.sql'
  end

  def down
    drop_function 'replace_settlement_journal', 'INT, DATE, INT, INT, INT, INT, INT, TEXT, INT'
    drop_function 'create_settlement_journal', 'DATE, INT, INT, INT, INT, INT, TEXT, INT'

    execute <<~SQL
      ALTER TABLE credits DROP CONSTRAINT credit_payment_method_type;
      ALTER TABLE credits
        ADD CONSTRAINT credit_payment_method_type CHECK (
          (element_type = 1 AND payment_method_type IN (1, 2, 3, 4, 5))
          OR (element_type = 2 AND payment_method_type IN (1, 2, 3))
          OR (element_type IN (3, 4, 5) AND payment_method_type = 0)
        );

      ALTER TABLE asset_accounts DROP CONSTRAINT asset_account_asset_type;
      ALTER TABLE asset_accounts
        ADD CONSTRAINT asset_account_asset_type CHECK (asset_type IN (1, 2, 3, 4, 5));
    SQL
  end
end
