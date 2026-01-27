# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ElementTypeType do
  subject(:type) { described_class.new }

  describe '#cast' do
    context 'nil の場合' do
      it 'nil を返す' do
        expect(type.cast(nil)).to be_nil
      end
    end

    context 'ElementType の場合' do
      it 'そのまま返す（二重ラップ防止）' do
        element_type = ElementType.new(1)

        expect(type.cast(element_type)).to equal(element_type)
      end
    end

    context 'プリミティブ型の場合' do
      it 'Integer から ElementType を生成する' do
        result = type.cast(3)

        expect(result).to be_a(ElementType)
        expect(result.value).to eq 3
      end
    end

    context '不正な値の場合' do
      it '範囲外の値を指定すると例外が発生する' do
        expect {
          type.cast(6)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#serialize' do
    context 'nil の場合' do
      it 'nil を返す' do
        expect(type.serialize(nil)).to be_nil
      end
    end

    context 'ElementType の場合' do
      it '内部の値（Integer）を返す' do
        element_type = ElementType.new(5)

        expect(type.serialize(element_type)).to eq 5
      end
    end

    context 'プリミティブ型の場合' do
      it 'そのまま返す' do
        expect(type.serialize(2)).to eq 2
      end
    end
  end
end
