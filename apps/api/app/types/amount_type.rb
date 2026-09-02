# frozen_string_literal: true

class AmountType < ActiveRecord::Type::Decimal
  def cast(value)
    return if value.nil?
    return value if value.is_a?(Amount)

    Amount.new(value)
  end

  def serialize(value)
    return if value.nil?
    return value.to_i if value.is_a?(Amount)

    value
  end
end
