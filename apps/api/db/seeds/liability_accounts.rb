# db/seeds/liability_accounts.rb

masa = User.find_by!(name: "masa")

[
  "JAL",
  "enoteca",
  "tcard",
  "PayPay"
].each do |name|
  LiabilityAccount.find_or_create_by!(
    user: masa,
    name: name
  ) do |account|
    account.liability_type = :credit_card
  end
end
