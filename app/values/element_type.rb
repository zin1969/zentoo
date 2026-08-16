# frozen_string_literal: true

# ElementType represents accounting element classification.
# It is a core accounting concept and must not be extended lightly.
class ElementType
  ASSETS      = 1      # 資産
  LIABILITIES = 2      # 負債
  EQUITY      = 3      # 元入金
  REVENUE     = 4      # 収益
  EXPENSES    = 5      # 費用

  ALL_VALUES = [
    ASSETS,
    LIABILITIES,
    EQUITY,
    REVENUE,
    EXPENSES
  ].freeze

  NAMES = {
    ASSETS      => 'assets',
    LIABILITIES => 'liabilities',
    EQUITY      => 'equity',
    REVENUE     => 'revenue',
    EXPENSES    => 'expenses'
  }.freeze

  JAPANESE_NAMES = {
    ASSETS      => '資産',
    LIABILITIES => '負債',
    EQUITY      => '元入金',
    REVENUE     => '収益',
    EXPENSES    => '費用'
  }.freeze

  def initialize(value)
    raise ArgumentError, 'element_type must not be nil' if value.nil?

    @value = Integer(value)
    raise ArgumentError, "invalid element_type: #{@value}" unless ALL_VALUES.include?(@value)
  end

  attr_reader :value

  # -----------------------------
  # 同値性
  # -----------------------------
  def ==(other)
    other.is_a?(self.class) && value == other.value
  end

  alias eql? ==

  def hash
    value.hash
  end

  # -----------------------------
  # 振る舞い（業務ロジック）
  # -----------------------------
  def assets?
    value == ASSETS
  end

  def liabilities?
    value == LIABILITIES
  end

  def equity?
    value == EQUITY
  end

  def revenue?
    value == REVENUE
  end

  def expenses?
    value == EXPENSES
  end

  def name
    NAMES.fetch(value)
  end

  def japanese_name
    JAPANESE_NAMES.fetch(value)
  end

  def to_i
    value
  end

  def to_s
    name
  end

  def as_json(*)
    value
  end
end
