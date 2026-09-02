# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Amount do
  describe '初期化' do
    context '正常系' do
      it '0 を指定して生成できる' do
        amount = Amount.new(0)
        expect(amount.to_i).to eq 0
      end

      it '正の整数を指定して生成できる' do
        amount = Amount.new(100)
        expect(amount.to_i).to eq 100
      end

      it '文字列の数値を指定して生成できる' do
        amount = Amount.new('200')
        expect(amount.to_i).to eq 200
      end
    end

    context '異常系' do
      it 'nil を指定すると例外が発生する' do
        expect { Amount.new(nil) }
          .to raise_error(ArgumentError)
      end

      it '負の値を指定すると例外が発生する' do
        expect { Amount.new(-1) }
          .to raise_error(ArgumentError, /must be >= 0/)
      end

      it '小数を指定すると例外が発生する' do
        expect { Amount.new(10.5) }
          .to raise_error(ArgumentError, /integer/)
      end
    end
  end

  describe '判定系メソッド' do
    describe '#zero?' do
      it '金額が 0 の場合 true を返す' do
        expect(Amount.new(0)).to be_zero
      end

      it '金額が 0 以外の場合 false を返す' do
        expect(Amount.new(1)).not_to be_zero
      end
    end

    describe '#positive?' do
      it '正の値の場合 true を返す' do
        expect(Amount.new(1)).to be_positive
      end

      it '0 の場合 false を返す' do
        expect(Amount.new(0)).not_to be_positive
      end
    end
  end

  describe '変換系メソッド' do
    let(:amount) { Amount.new(100) }

    it '#to_d で BigDecimal を返す' do
      expect(amount.to_d).to be_a(BigDecimal)
      expect(amount.to_d).to eq BigDecimal('100')
    end

    it '#to_i で Integer を返す' do
      expect(amount.to_i).to eq 100
    end
  end

  describe '計算系メソッド' do
    let(:amount) { Amount.new(100) }

    describe '#add' do
      it '加算結果を Amount として返す' do
        result = amount.add(Amount.new(50))

        expect(result).to be_a(Amount)
        expect(result.to_i).to eq 150
      end

      it 'Amount 以外を渡すと例外が発生する' do
        expect { amount.add(10) }
          .to raise_error(ArgumentError)
      end
    end

    describe '#subtract' do
      it '減算結果を Amount として返す' do
        result = amount.subtract(Amount.new(30))

        expect(result.to_i).to eq 70
      end

      it '結果が 0 になる場合も生成できる' do
        result = amount.subtract(Amount.new(100))

        expect(result.to_i).to eq 0
      end

      it '結果が負になる場合は例外が発生する' do
        expect {
          amount.subtract(Amount.new(200))
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe '同値性' do
    it '内部の値が同じなら等しいと判定される' do
      a = Amount.new(100)
      b = Amount.new(100)

      expect(a).to eq b
      expect(a.eql?(b)).to be true
    end

    it '内部の値が異なれば等しくない' do
      a = Amount.new(100)
      b = Amount.new(200)

      expect(a).not_to eq b
    end

    it 'hash が同値性と整合している' do
      a = Amount.new(100)
      b = Amount.new(100)

      expect(a.hash).to eq b.hash
    end
  end
end
