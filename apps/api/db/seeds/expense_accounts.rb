# 費用科目・資本科目は全ユーザー共通（user_id IS NULL）

# 親のない科目がトップレベル（ダミーの root 科目は置かない）
food = ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: nil,
  name: "食費"
)

entertainment = ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: nil,
  name: "娯楽費"
)

ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: nil,
  name: "交通費"
)

ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: nil,
  name: "教育費"
)

# 食費 配下
ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: food,
  name: "外食費"
)

# 娯楽費 配下
ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: entertainment,
  name: "映画"
)

ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: entertainment,
  name: "配信サービス"
)

ExpenseAccount.find_or_create_by!(
  user: nil,
  parent: entertainment,
  name: "漫画"
)
