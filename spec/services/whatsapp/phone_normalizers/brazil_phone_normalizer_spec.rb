require 'rails_helper'

describe Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer do
  subject(:normalizer) { described_class.new }

  describe '#ninth_digit_variant' do
    it 'drops the ninth digit from a 13-digit mobile' do
      expect(normalizer.ninth_digit_variant('5527998999017')).to eq('552798999017')
    end

    it 'adds the ninth digit to a 12-digit number' do
      expect(normalizer.ninth_digit_variant('552798999017')).to eq('5527998999017')
    end

    it 'has no variant for a 13-digit number without the ninth digit after the area code' do
      expect(normalizer.ninth_digit_variant('5527898999017')).to be_nil
    end

    it 'has no variant for numbers outside Brazil' do
      expect(normalizer.ninth_digit_variant('525512345678')).to be_nil
    end
  end
end
