module Limits
  BULK_ACTIONS_LIMIT = 100
  BULK_EXTERNAL_HTTP_CALLS_LIMIT = 25
  URL_LENGTH_LIMIT = 2048 # https://stackoverflow.com/questions/417142
  OUT_OF_OFFICE_MESSAGE_MAX_LENGTH = 10_000
  GREETING_MESSAGE_MAX_LENGTH = 10_000
  # Instagram/Messenger quick reply limits
  # https://developers.facebook.com/documentation/business-messaging/instagram-messaging/features/quick-replies
  GREETING_ITEMS_MAX_COUNT = 13
  GREETING_ITEM_TITLE_MAX_LENGTH = 20
  # Items carrying a link are delivered as a button template, which allows fewer buttons
  # https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/messaging-api/button-template/
  GREETING_LINK_BUTTONS_MAX_COUNT = 3
  GREETING_LINK_BUTTONS_TEXT_MAX_LENGTH = 640
  CATEGORIES_PER_PAGE = 1000
  AUTO_ASSIGNMENT_BULK_LIMIT = 100
  COMPANY_NAME_LENGTH_LIMIT = 100
  COMPANY_DESCRIPTION_LENGTH_LIMIT = 1000
  MAX_CUSTOM_FILTERS_PER_USER = 1000
  MESSAGE_SEARCH_TIME_RANGE_LIMIT_DAYS = 90

  def self.conversation_message_per_minute_limit
    ENV.fetch('CONVERSATION_MESSAGE_PER_MINUTE_LIMIT', '200').to_i
  end
end
