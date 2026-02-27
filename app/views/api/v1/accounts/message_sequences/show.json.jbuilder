json.payload do
  json.partial! 'api/v1/accounts/message_sequences/message_sequence', message_sequence: @message_sequence
end
