json.payload do
  json.id @scheduled_message.id
  json.title @scheduled_message.title
  json.content @scheduled_message.content
  json.scheduled_at @scheduled_message.scheduled_at.to_i
  json.status @scheduled_message.status
  json.created_by_id @scheduled_message.created_by_id
  json.deal_id @scheduled_message.deal_id
  json.template_params @scheduled_message.template_params
  json.created_at @scheduled_message.created_at.to_i
end
