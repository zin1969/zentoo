# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AmountType do
  subject(:type) { described_class.new }

  describe '#cast' do
    context 'nil の場合' do
      it 'nil を返す' do
        expect(type.cast(nil)).to be_nil
      end
    end

    context 'Amount の場合' do
      it 'そのまま返す（二重ラップしない）' do
        amount = Amount.new(100)

        result = type.cast(amount)

        expect(result).to equal(amount)
      end
    end

    context 'プリミティブ型の場合' do
      it 'Integer から Amount を生成する' do
        result = type.cast(100)

        expect(result).to be_a(Amount)
        expect(result.to_i).to eq 100
      end

      it 'String から Amount を生成する' do
        result = type.cast('200')

        expect(result).to be_a(Amount)
        expect(result.to_i).to eq 200
      end
    end

    context '不正な値の場合' do
      it '負の値を指定すると例外が発生する' do
        expect {
          type.cast(-1)
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

    context 'Amount の場合' do
      it 'Integer に変換して返す' do
        amount = Amount.new(150)

        result = type.serialize(amount)

        expect(result).to eq 150
      end
    end

    context 'プリミティブ型の場合' do
      it 'そのまま返す' do
        expect(type.serialize(300)).to eq 300
      end
    end
  end
end
