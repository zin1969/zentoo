masa = User.find_by!(name: "masa")

EquityAccount.find_or_create_by!(user: masa, name: "元入金")
