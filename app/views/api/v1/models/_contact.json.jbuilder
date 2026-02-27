json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.blocked resource.blocked
json.identifier resource.identifier
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?

# CRM Lead fields
json.is_lead resource.is_lead
json.lead_source resource.lead_source
json.lead_score resource.lead_score

# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! resource.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end

# CRM: include open deals summary for individual contact views
if defined?(with_deals) && with_deals.present?
  json.deals do
    json.array! resource.deals.open_deals.includes(:stage).limit(10) do |deal|
      json.id deal.id
      json.title deal.title
      json.value deal.value.to_f
      json.stage_name deal.stage.name
      json.status deal.status
    end
  end
end

