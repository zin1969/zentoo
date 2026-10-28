# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CredentialAuthenticator do
  describe '#authenticate!' do
    let!(:user) { create(:user, :masa, password: 'secret-pass') }

    it 'returns the user when the name and password match' do
      expect(described_class.new.authenticate!('masa', 'secret-pass')).to eq(user)
    end

    it 'raises UnauthorizedError when the password is wrong' do
      expect { described_class.new.authenticate!('masa', 'wrong') }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the user does not exist' do
      expect { described_class.new.authenticate!('nobody', 'secret-pass') }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the user has no password set' do
      create(:user, :system)

      expect { described_class.new.authenticate!('system', '') }.to raise_error(UnauthorizedError)
    end

    it 'raises UnauthorizedError when the name or password is nil' do
      expect { described_class.new.authenticate!(nil, nil) }.to raise_error(UnauthorizedError)
    end
  end
end
