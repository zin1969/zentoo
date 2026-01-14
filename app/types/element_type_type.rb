# frozen_string_literal: true

class ElementTypeType < ActiveRecord::Type::Integer
  def cast(value)
    return if value.nil?
    return value if value.is_a?(ElementType)

    ElementType.new(value)
  end

  def serialize(value)
    return if value.nil?
    return value.value if value.is_a?(ElementType)

    value
  end
end
