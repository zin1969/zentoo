# 費用科目・資本科目は全ユーザー共通（user_id IS NULL）
EquityAccount.find_or_create_by!(user: nil, name: "元入金")
