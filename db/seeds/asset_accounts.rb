masa = User.find_by!(name: "masa")

[
  { name: "現金", asset_type: :cash },
  { name: "三菱UFJ銀行 用賀出張所", asset_type: :deposit },
  { name: "みずほ銀行 玉川支店", asset_type: :deposit },
  { name: "Suica", asset_type: :e_money }
].each do |attrs|
  AssetAccount.find_or_create_by!(
    user: masa,
    name: attrs[:name]
  ) do |account|
    account.asset_type = attrs[:asset_type]
  end
end
