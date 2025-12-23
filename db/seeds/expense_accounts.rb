masa = User.find_by!(name: "masa")

# root
root = ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: nil,
  name: "root"
)

# root 配下
food = ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: root,
  name: "食費"
)

entertainment = ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: root,
  name: "娯楽費"
)

ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: root,
  name: "交通費"
)

ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: root,
  name: "教育費"
)

# 食費 配下
ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: food,
  name: "外食費"
)

# 娯楽費 配下
ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: entertainment,
  name: "映画"
)

ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: entertainment,
  name: "配信サービス"
)

ExpenseAccount.find_or_create_by!(
  user: masa,
  parent: entertainment,
  name: "漫画"
)
