require 'rails_helper'

RSpec.describe AgentBotInbox do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:inbox_id) }
    it { is_expected.to validate_presence_of(:agent_bot_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:agent_bot) }
    it { is_expected.to belong_to(:inbox) }
  end

  describe 'defaults' do
    it 'defaults to pending status and all event categories enabled' do
      agent_bot_inbox = create(:agent_bot_inbox)

      expect(agent_bot_inbox.initial_conversation_status).to eq 'pending'
      expect(agent_bot_inbox.event_names).to match_array(AgentBotInbox::ALL_EVENT_CATEGORIES)
    end
  end

  describe '#event_enabled?' do
    it 'returns true when the category covering the event is enabled' do
      agent_bot_inbox = create(:agent_bot_inbox, event_names: ['message_created'])

      expect(agent_bot_inbox.event_enabled?('message_created')).to be true
      expect(agent_bot_inbox.event_enabled?('message_updated')).to be true
      expect(agent_bot_inbox.event_enabled?('conversation_opened')).to be false
    end
  end

  describe 'event_names validation' do
    it 'rejects unsupported event categories' do
      agent_bot_inbox = build(:agent_bot_inbox, event_names: ['not_a_real_event'])

      expect(agent_bot_inbox).not_to be_valid
      expect(agent_bot_inbox.errors[:event_names]).to be_present
    end
  end
end
