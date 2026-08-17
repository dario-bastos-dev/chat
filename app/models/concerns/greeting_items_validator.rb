# Greeting buttons are delivered as `input_select` items on channels that support them.
# Items carrying a `uri` are sent as link buttons, which allow fewer items and less text than quick replies.
class GreetingItemsValidator < ActiveModel::Validator
  URI_FORMAT = /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/

  def validate(record)
    items = record.greeting_items
    return if items.blank?
    return unless valid_shape?(record, items)

    validate_count!(record, items)
    validate_titles!(record, items)
    validate_links!(record, items)
  end

  private

  def valid_shape?(record, items)
    return true if items.is_a?(Array) && items.all? { |item| item.is_a?(Hash) && item['title'].present? }

    record.errors.add(:greeting_items, 'each item should be a hash with a title')
    false
  end

  def validate_count!(record, items)
    max_count = links?(items) ? Limits::GREETING_LINK_BUTTONS_MAX_COUNT : Limits::GREETING_ITEMS_MAX_COUNT
    record.errors.add(:greeting_items, "cannot exceed #{max_count} items") if items.size > max_count
  end

  def validate_titles!(record, items)
    return if items.all? { |item| item['title'].length <= Limits::GREETING_ITEM_TITLE_MAX_LENGTH }

    record.errors.add(:greeting_items, "titles cannot exceed #{Limits::GREETING_ITEM_TITLE_MAX_LENGTH} characters")
  end

  def validate_links!(record, items)
    record.errors.add(:greeting_items, 'links should be valid http(s) urls') unless uris_valid?(items)
    return unless links?(items)

    # A message is either a set of quick replies or a set of link buttons, channels cannot mix both.
    record.errors.add(:greeting_items, 'should either all have a link or none') unless items.all? { |item| item['uri'].present? }
    return if record.greeting_message.to_s.length <= Limits::GREETING_LINK_BUTTONS_TEXT_MAX_LENGTH

    record.errors.add(:greeting_message, "cannot exceed #{Limits::GREETING_LINK_BUTTONS_TEXT_MAX_LENGTH} characters with link buttons")
  end

  def links?(items)
    items.any? { |item| item['uri'].present? }
  end

  def uris_valid?(items)
    items.all? { |item| item['uri'].blank? || item['uri'].match?(URI_FORMAT) }
  end
end
