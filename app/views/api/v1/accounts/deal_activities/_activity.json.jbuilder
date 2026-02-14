json.id activity.id
json.deal_id activity.deal_id
json.activity_type activity.activity_type
json.description activity.description
json.due_date activity.due_date
json.completed_at activity.completed_at
json.is_completed activity.completed?
json.is_overdue activity.overdue?
json.created_at activity.created_at
json.updated_at activity.updated_at

if activity.user.present?
  json.user do
    json.id activity.user.id
    json.name activity.user.name
    json.email activity.user.email
    json.avatar_url activity.user.avatar_url if activity.user.respond_to?(:avatar_url)
  end
else
  json.user nil
end
