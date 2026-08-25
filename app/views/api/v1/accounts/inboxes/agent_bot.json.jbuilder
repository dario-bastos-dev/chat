json.agent_bot do
  json.partial! 'api/v1/models/agent_bot', formats: [:json], resource: @agent_bot if @agent_bot.present?
end

json.agent_bot_inbox do
  if @inbox.agent_bot_inbox.present?
    json.initial_conversation_status @inbox.agent_bot_inbox.initial_conversation_status
    json.event_names @inbox.agent_bot_inbox.event_names
  end
end
