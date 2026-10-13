# Handles Brazil phone number normalization
# ref: https://github.com/chatwoot/chatwoot/issues/5840
#
# Brazil changed its mobile number system by adding a "9" prefix to existing numbers.
# This normalizer adds the "9" digit if the number is 12 digits (making it 13 digits total)
# to match the new format: 55 + DDD + 9 + number
class Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer < Whatsapp::PhoneNormalizers::BasePhoneNormalizer
  COUNTRY_CODE_LENGTH = 2
  DDD_LENGTH = 2

  def normalize(waid)
    return waid unless handles_country?(waid)

    ddd = waid[COUNTRY_CODE_LENGTH, DDD_LENGTH]
    number = waid[COUNTRY_CODE_LENGTH + DDD_LENGTH, waid.length - (COUNTRY_CODE_LENGTH + DDD_LENGTH)]
    normalized_number = "55#{ddd}#{number}"
    normalized_number = "55#{ddd}9#{number}" if normalized_number.length != 13
    normalized_number
  end

  # The same line written the other way. Contacts saved before the change, or typed by hand, may
  # still hold the mobile without its ninth digit, and a landline never had one.
  def ninth_digit_variant(waid)
    case waid
    when /\A(55\d{2})9(\d{8})\z/ then "#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
    when /\A(55\d{2})(\d{8})\z/ then "#{Regexp.last_match(1)}9#{Regexp.last_match(2)}"
    end
  end

  private

  def country_code_pattern
    /^55/
  end
end
