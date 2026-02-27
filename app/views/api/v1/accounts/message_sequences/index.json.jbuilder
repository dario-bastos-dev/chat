json.payload do
  json.array! @message_sequences do |message_sequence|
    json.partial! 'api/v1/accounts/message_sequences/message_sequence', message_sequence: message_sequence
  end
end
