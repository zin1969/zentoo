# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ElementType do
  describe 'initialize' do
    context 'with valid value' do
      it 'creates assets element type' do
        element_type = described_class.new(1)

        expect(element_type.value).to eq 1
        expect(element_type).to be_assets
        expect(element_type.name).to eq 'assets'
      end

      it 'accepts integer-like value' do
        element_type = described_class.new('2')

        expect(element_type).to be_liabilities
      end
    end

    context 'with invalid value' do
      it 'raises error when nil is given' do
        expect {
          described_class.new(nil)
        }.to raise_error(ArgumentError, /must not be nil/)
      end

      it 'raises error when value is out of range' do
        expect {
          described_class.new(0)
        }.to raise_error(ArgumentError, /invalid element_type/)
      end

      it 'raises error when value is not numeric' do
        expect {
          described_class.new('assets')
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'equality' do
    it 'is equal when value is same' do
      a = described_class.new(3)
      b = described_class.new(3)

      expect(a).to eq b
      expect(a).to eql b
      expect(a.hash).to eq b.hash
    end

    it 'is not equal when value is different' do
      a = described_class.new(1)
      b = described_class.new(2)

      expect(a).not_to eq b
    end
  end

  describe 'predicate methods' do
    subject { described_class.new(value) }

    context 'assets' do
      let(:value) { 1 }
      it { is_expected.to be_assets }
      it { is_expected.not_to be_liabilities }
    end

    context 'liabilities' do
      let(:value) { 2 }
      it { is_expected.to be_liabilities }
    end

    context 'equity' do
      let(:value) { 3 }
      it { is_expected.to be_equity }
    end

    context 'revenue' do
      let(:value) { 4 }
      it { is_expected.to be_revenue }
    end

    context 'expenses' do
      let(:value) { 5 }
      it { is_expected.to be_expenses }
    end
  end

  describe 'conversion' do
    let(:element_type) { described_class.new(4) }

    it 'returns integer value with to_i' do
      expect(element_type.to_i).to eq 4
    end

    it 'returns name with to_s' do
      expect(element_type.to_s).to eq 'revenue'
    end
  end

  describe '#japanese_name' do
    it 'returns japanese name' do
      element_type = described_class.new(1)

      expect(element_type.japanese_name).to eq '資産'
    end
  end
end
