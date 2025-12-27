require "test_helper"

class CreateOpeningAssetTest < ActiveSupport::TestCase
  test "create opening asset balance journal via postgres function" do
    # --- arrange ---
    user = create(:user, :masa)
    asset_account = create(:asset_account, :cash, user: user)
    equity_account = create(:equity_account, :original_deposit, user: user)

    journal_date = Date.new(2025, 1, 1)
    amount = 100_000

    # --- act ---
    journal_id = Journal.create_opening_asset_balance!(
      journal_date: journal_date,
      asset_type: 1,
      asset_account_id: asset_account.id,
      amount: amount,
      user_id: user.id
    )

    # --- assert ---
    assert journal_id.present?, "journal_id が返却されること"

    journal = Journal.find(journal_id)

    assert_equal journal_date, journal.journal_dt
    assert_equal asset_account.name, journal.store_name
    assert_equal user.id, journal.user_id

    debit = journal.debits.first
    assert_equal 1, debit.element_type
    assert_equal asset_account.id, debit.account_id
    assert_equal "開始残高", debit.item_name
    assert_equal amount, debit.amount
    assert_equal user.id, debit.user_id

    credit = journal.credits.first
    assert_equal 3, credit.element_type
    assert_equal equity_account.id, credit.account_id
    assert_equal amount, credit.amount
    assert_equal user.id, credit.user_id
  end
end
