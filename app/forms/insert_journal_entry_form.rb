# app/forms/insert_journal_entry_form.rb

=begin
【JSONサンプル】
{
  "date": "2026-07-19",
  "user_id": 2,
  "store_name": "ピザーラ",
  "debits": [
    {
      "element_type": 5,
      "account_id": 10051,
      "amount": 1000,
      "item_name": "ピザ"
    }
  ],
  "credits": [
    {
      "element_type": 1,
      "payment_method_type": 1,
      "account_id": 5,
      "amount": 1000
    }
  ]
}
=end

require 'json'

# --- メインの親クラス ---
class InsertJournalEntryForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :date, :date
  attribute :user_id, :integer
  attribute :store_name, :string

  validates :date, :user_id, presence: true
  validate :validate_nested_entries

  attr_reader :validated_data, :debits, :credits

  def initialize(json_string = nil)
    parsed_hash = parse_json(json_string)
    
    # 1. 先に入れ子（配列）のデータを各Formオブジェクトの配列に変換して格納
    @debits = Array(parsed_hash[:debits]).map do |d| 
      d[:element_type] = ElementType.new(d[:element_type]) if d[:element_type].is_a?(Integer)
      d[:amount] = Amount.new(d[:amount]) if d[:amount].is_a?(Integer)
      DebitEntryForm.new(d)
    end
    
    @credits = Array(parsed_hash[:credits]).map do |c| 
      c[:element_type] = ElementType.new(c[:element_type]) if c[:element_type].is_a?(Integer)
      c[:amount] = Amount.new(c[:amount]) if c[:amount].is_a?(Integer)
      CreditEntryForm.new(c)
    end


    # 2. 親クラス（トップレベルの属性）の初期化
    super(parsed_hash.except(:debits, :credits))

    # 3. 自動チェックと、成功時のインスタンス変数保存
    if valid?
      @validated_data = to_hash
    else
      raise ArgumentError, "Validation failed: #{errors.full_messages.join(', ')}"
    end
  end

  private

  def parse_json(json_string)
    return {} if json_string.blank?
    JSON.parse(json_string, symbolize_names: true)
  rescue JSON::ParserError
    raise ArgumentError, 'Invalid JSON format'
  end

  # 子クラスたちのバリデーション結果を集約する
  def validate_nested_entries
    errors.add(:debits, "can't be blank") if debits.empty?
    debits.each_with_index do |debit, i|
      next if debit.valid?
      debit.errors.full_messages.each { |msg| errors.add(:base, "Debits[#{i}]: #{msg}") }
    end

    errors.add(:credits, "can't be blank") if credits.empty?
    credits.each_with_index do |credit, i|
      next if credit.valid?
      credit.errors.full_messages.each { |msg| errors.add(:base, "Credits[#{i}]: #{msg}") }
    end
  end

  # すべてのデータを1つのRubyハッシュにまとめて返す
  def to_hash
    {
      date: date,
      user_id: user_id,
      store_name: store_name,
      # 子オブジェクトから、型変換済みの値をハッシュとして取り出す
      debits: debits.map { |d| d.attributes.symbolize_keys },
      credits: credits.map { |c| c.attributes.symbolize_keys }
    }.freeze
  end
end
