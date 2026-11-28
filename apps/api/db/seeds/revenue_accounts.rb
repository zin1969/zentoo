# 収益科目は全ユーザー共通（user_id IS NULL）。親のない科目がトップレベル
# 本番は、マイグレーション（20261121120000・20261128130000）で同じ科目を入れている
# 株式売却益は株の売りで使う（DB 関数 create_stock_sell_journal が名前で探す）
%w[給与 賞与 雑収入 配当金 株式売却益].each do |name|
  RevenueAccount.find_or_create_by!(user: nil, parent: nil, name: name)
end
