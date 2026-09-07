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
    it 'defaults to pending status and the pre-existing event categories enabled' do
      agent_bot_inbox = create(:agent_bot_inbox)

      expect(agent_bot_inbox.initial_conversation_status).to eq 'pending'
      # custom_attribute_updated is opt-in on purpose: it's a brand new capability (it wires up
      # contact_updated, which never fired for bots before), so it must not silently turn on
      # for existing/new bot connections.
      expect(agent_bot_inbox.event_names).to match_array(
        %w[conversation_opened message_created conversation_status_changed webwidget_triggered]
      )
      expect(AgentBotInbox::ALL_EVENT_CATEGORIES).to include('custom_attribute_updated')
      expect(agent_bot_inbox.custom_attribute_event_enabled?).to be false
    end

    it 'defaults custom attribute keys to "all" for both models' do
      agent_bot_inbox = create(:agent_bot_inbox)

      expect(agent_bot_inbox.conversation_custom_attribute_keys).to eq ['all']
      expect(agent_bot_inbox.contact_custom_attribute_keys).to eq ['all']
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

  describe '#notify_for_custom_attribute?' do
    it 'returns true for any changed key when configured keys include "all"' do
      agent_bot_inbox = create(:agent_bot_inbox, conversation_custom_attribute_keys: ['all'])

      expect(agent_bot_inbox.notify_for_custom_attribute?(:conversation, ['priority_level'])).to be true
    end

    it 'returns true only when a changed key is in the configured allow-list' do
      agent_bot_inbox = create(:agent_bot_inbox, conversation_custom_attribute_keys: %w[priority_level])

      expect(agent_bot_inbox.notify_for_custom_attribute?(:conversation, %w[priority_level])).to be true
      expect(agent_bot_inbox.notify_for_custom_attribute?(:conversation, %w[other_field])).to be false
    end

    it 'checks contact_custom_attribute_keys for the :contact model' do
      agent_bot_inbox = create(:agent_bot_inbox, conversation_custom_attribute_keys: ['all'], contact_custom_attribute_keys: %w[plan])

      expect(agent_bot_inbox.notify_for_custom_attribute?(:contact, %w[plan])).to be true
      expect(agent_bot_inbox.notify_for_custom_attribute?(:contact, %w[unrelated])).to be false
    end

    it 'returns false when no keys changed' do
      agent_bot_inbox = create(:agent_bot_inbox)

      expect(agent_bot_inbox.notify_for_custom_attribute?(:conversation, [])).to be false
    end
  end
end
