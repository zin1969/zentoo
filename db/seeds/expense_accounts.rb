require "factory_bot_rails"

# ユーザー取得（INSERT の subquery 相当）
masa = User.find_by!(name: "masa")

# root
root = FactoryBot.create(
  :expense_account,
  :root,
  user: masa
)

# root 配下
food = FactoryBot.create(
  :expense_account,
  :food,
  parent: root,
  user: masa
)

entertainment = FactoryBot.create(
  :expense_account,
  :entertainment,
  parent: root,
  user: masa
)

FactoryBot.create(
  :expense_account,
  :transportation,
  parent: root,
  user: masa
)

FactoryBot.create(
  :expense_account,
  :education,
  parent: root,
  user: masa
)

# 食費 配下
FactoryBot.create(
  :expense_account,
  :eating_out,
  parent: food,
  user: masa
)

# 娯楽費 配下
FactoryBot.create(
  :expense_account,
  :movie,
  parent: entertainment,
  user: masa
)

FactoryBot.create(
  :expense_account,
  :streaming,
  parent: entertainment,
  user: masa
)

FactoryBot.create(
  :expense_account,
  :manga,
  parent: entertainment,
  user: masa
)
