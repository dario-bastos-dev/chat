json.id message_sequence.id
json.name message_sequence.name
json.activation_type message_sequence.activation_type
json.activation_tag message_sequence.activation_tag
json.inbox_scope message_sequence.inbox_scope
json.active message_sequence.active

json.steps message_sequence.steps.order(:position) do |step|
  json.id step.id
  json.position step.position
  json.step_type step.step_type
  json.content step.content
  json.wait_time step.wait_time
  json.macro_id step.macro_id
  json.template_params step.template_params
  
  if step.file.attached?
    json.file do
      json.name step.file.filename.to_s
      json.url Rails.application.routes.url_helpers.url_for(step.file) rescue nil
    end
  end
end

json.inbox_ids message_sequence.inboxes.pluck(:id)
json.macro_id message_sequence.macro_id
json.macro_execution_time message_sequence.macro_execution_time
json.restrict_execution_time message_sequence.restrict_execution_time
json.execution_start_hour message_sequence.execution_start_hour
json.execution_end_hour message_sequence.execution_end_hour
json.created_by_id message_sequence.created_by_id
json.created_at message_sequence.created_at.to_i
json.updated_at message_sequence.updated_at.to_i
