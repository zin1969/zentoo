# 収益科目は全ユーザー共通（user_id IS NULL）。親のない科目がトップレベル
# 本番は、テーブルを作ったマイグレーション（20261121120000）で同じ科目を入れている
%w[給与 賞与 雑収入].each do |name|
  RevenueAccount.find_or_create_by!(user: nil, parent: nil, name: name)
end
