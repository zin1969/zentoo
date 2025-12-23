masa = User.find_by!(name: "masa")

mufg_yoga   = AssetAccount.find_by!(name: "三菱UFJ銀行 用賀出張所", user: masa)
mizuho_tama = AssetAccount.find_by!(name: "みずほ銀行 玉川支店", user: masa)

definitions = [
  {
    liability_name: "JAL",
    bank_account: mufg_yoga,
    cutoff_day: 15,
    payment_day: 10
  },
  {
    liability_name: "enoteca",
    bank_account: mufg_yoga,
    cutoff_day: 15,
    payment_day: 10
  },
  {
    liability_name: "tcard",
    bank_account: mufg_yoga,
    cutoff_day: 10,
    payment_day: 27
  },
  {
    liability_name: "PayPay",
    bank_account: mizuho_tama,
    cutoff_day: 31,
    payment_day: 27
  }
]

definitions.each do |defn|
  liability = LiabilityAccount.find_by!(
    name: defn[:liability_name],
    user: masa
  )

  CreditCard.find_or_create_by!(
    user: masa,
    liability_account: liability
  ) do |card|
    card.bank_account = defn[:bank_account]
    card.cutoff_day   = defn[:cutoff_day]
    card.payment_day  = defn[:payment_day]
  end
end
