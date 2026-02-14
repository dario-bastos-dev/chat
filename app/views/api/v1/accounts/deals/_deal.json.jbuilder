json.id deal.id
json.title deal.title
json.value deal.value.to_f
json.currency deal.currency
json.status deal.status
json.lost_reason deal.lost_reason
json.position deal.position
json.expected_close_date deal.expected_close_date
json.last_activity_at deal.last_activity_at
json.won_at deal.won_at
json.lost_at deal.lost_at
json.is_rotting deal.rotting?
json.weighted_value deal.weighted_value
json.custom_attributes deal.custom_attributes
json.created_at deal.created_at
json.updated_at deal.updated_at

json.pipeline do
  json.id deal.pipeline_id
  json.name deal.pipeline.name
end

json.stage do
  json.id deal.stage_id
  json.name deal.stage.name
  json.position deal.stage.position
  json.win_probability deal.stage.win_probability
end

json.contact do
  json.id deal.contact_id
  json.name deal.contact.name
  json.email deal.contact.email
  json.phone_number deal.contact.phone_number
  json.avatar_url deal.contact.avatar_url if deal.contact.respond_to?(:avatar_url)
end

if deal.assignee.present?
  json.assignee do
    json.id deal.assignee.id
    json.name deal.assignee.name
    json.email deal.assignee.email
    json.avatar_url deal.assignee.avatar_url if deal.assignee.respond_to?(:avatar_url)
  end
else
  json.assignee nil
end

if deal.inbox.present?
  json.inbox do
    json.id deal.inbox.id
    json.name deal.inbox.name
    json.channel_type deal.inbox.channel_type
  end
else
  json.inbox nil
end
