json.payload do
  json.array! @scheduled_messages do |message|
    json.id message.id
    json.title message.title
    json.content message.content
    json.scheduled_at message.scheduled_at.to_i
    json.status message.status
    json.created_by_id message.created_by_id
    json.template_params message.template_params
    json.created_at message.created_at.to_i
  end
end
