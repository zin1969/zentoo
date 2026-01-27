# frozen_string_literal: true

class Amount
  attr_reader :value

  def initialize(value)
    raise ArgumentError, 'amount must not be nil' if value.nil?

    @value = BigDecimal(value.to_s)

    validate!
  end

  # =========================
  # 判定系
  # =========================
  def zero?
    value.zero?
  end

  def positive?
    value.positive?
  end

  # =========================
  # 変換系
  # =========================
  def to_d
    value
  end

  def to_i
    value.to_i
  end

  # =========================
  # 計算系
  # =========================
  def add(other)
    ensure_amount!(other)
    self.class.new(value + other.value)
  end

  def subtract(other)
    ensure_amount!(other)
    self.class.new(value - other.value)
  end

  # =========================
  # 同値性
  # =========================
  def ==(other)
    other.is_a?(self.class) && value == other.value
  end

  alias eql? ==

  def hash
    value.hash
  end

  private

  def validate!
    raise ArgumentError, 'amount must be >= 0' if value.negative?
    raise ArgumentError, 'amount must be an integer' unless integer_value?
  end

  def integer_value?
    value.frac.zero?
  end

  def ensure_amount!(other)
    raise ArgumentError, 'other must be Amount' unless other.is_a?(Amount)
  end
end
