require 'rails_helper'
describe AgentBotListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:agent_bot) { create(:agent_bot) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: user) }

  describe '#message_created' do
    let(:event_name) { 'message.created' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }
    let!(:message) do
      create(:message, message_type: 'outgoing',
                       account: account, inbox: inbox, conversation: conversation)
    end

    context 'when agent bot is not configured' do
      it 'does not send message to agent bot' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).exactly(0).times
        listener.message_created(event)
      end
    end

    context 'when agent bot is configured' do
      it 'sends message to agent bot' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url, message.webhook_data.merge(event: 'message_created'),
          :agent_bot_webhook, secret: agent_bot.secret, delivery_id: instance_of(String)
        ).once
        listener.message_created(event)
      end

      it 'does not send message to agent bot if url is empty' do
        agent_bot = create(:agent_bot, outgoing_url: '')
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.message_created(event)
      end

      it 'does not send message to agent bot when the message_created event is disabled for the inbox' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['conversation_opened'])
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.message_created(event)
      end

      context 'when conversation has a different assignee agent bot' do
        let!(:conversation_bot) { create(:agent_bot) }

        before do
          create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
          conversation.update!(assignee_agent_bot: conversation_bot, assignee: nil)
        end

        it 'sends message to both bots exactly once' do
          payload = message.webhook_data.merge(event: 'message_created')

          expect(AgentBots::WebhookJob).to receive(:perform_later).with(
            agent_bot.outgoing_url, payload, :agent_bot_webhook,
            secret: agent_bot.secret, delivery_id: instance_of(String)
          ).once
          expect(AgentBots::WebhookJob).to receive(:perform_later).with(
            conversation_bot.outgoing_url, payload, :agent_bot_webhook,
            secret: conversation_bot.secret, delivery_id: instance_of(String)
          ).once

          listener.message_created(event)
        end
      end
    end
  end

  describe '#conversation_status_changed' do
    let(:event_name) { 'conversation.status_changed' }
    let(:changed_attributes) { { status: %w[open pending] } }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, changed_attributes: changed_attributes) }

    context 'when agent bot is not configured' do
      it 'does not send webhook' do
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.conversation_status_changed(event)
      end
    end

    context 'when agent bot is configured on inbox' do
      it 'sends webhook with changed_attributes' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          hash_including(event: 'conversation_status_changed', account: account.webhook_data, changed_attributes: anything),
          :agent_bot_webhook,
          hash_including(secret: agent_bot.secret)
        ).once
        listener.conversation_status_changed(event)
      end
    end

    context 'when conversation is assigned to an agent bot' do
      before do
        conversation.update!(assignee_agent_bot: agent_bot, assignee: nil)
      end

      it 'sends webhook to the assigned agent bot' do
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          hash_including(event: 'conversation_status_changed', changed_attributes: anything),
          :agent_bot_webhook,
          hash_including(secret: agent_bot.secret)
        ).once
        listener.conversation_status_changed(event)
      end
    end
  end

  describe '#conversation_updated' do
    let(:event_name) { 'conversation.updated' }

    context 'when agent bot is not configured' do
      let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

      it 'does not send webhook' do
        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.conversation_updated(event)
      end
    end

    context 'when agent bot is configured on inbox' do
      let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

      it 'sends webhook to the inbox agent bot with changed_attributes' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          conversation.webhook_data.merge(event: 'conversation_updated', changed_attributes: nil),
          :agent_bot_webhook, secret: agent_bot.secret, delivery_id: instance_of(String)
        ).once
        listener.conversation_updated(event)
      end
    end

    context 'when conversation is assigned to an agent bot' do
      let!(:event) do
        Events::Base.new(event_name, Time.zone.now, conversation: conversation,
                                                    changed_attributes: { 'assignee_agent_bot_id' => [nil, agent_bot.id] })
      end

      before do
        conversation.update!(assignee_agent_bot: agent_bot, assignee: nil)
      end

      it 'sends webhook with changed_attributes to the assigned agent bot' do
        expected_changed_attributes = [{ 'assignee_agent_bot_id' => { previous_value: nil, current_value: agent_bot.id } }]
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          conversation.webhook_data.merge(
            event: 'conversation_updated',
            changed_attributes: expected_changed_attributes
          ),
          :agent_bot_webhook, secret: agent_bot.secret, delivery_id: instance_of(String)
        ).once
        listener.conversation_updated(event)
      end
    end
  end

  describe '#conversation_updated with custom_attribute_updated category' do
    let(:event_name) { 'conversation.updated' }
    let(:changed_attributes) { { 'custom_attributes' => [{}, { 'priority_level' => 'vip' }] } }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, changed_attributes: changed_attributes) }

    it 'sends the webhook when the general category is off but the custom attribute key matches the allow-list' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['custom_attribute_updated'],
                               conversation_custom_attribute_keys: ['priority_level'])

      expect(AgentBots::WebhookJob).to receive(:perform_later).with(
        agent_bot.outgoing_url, hash_including(event: 'conversation_updated'), :agent_bot_webhook,
        hash_including(secret: agent_bot.secret)
      ).once
      listener.conversation_updated(event)
    end

    it 'does not send the webhook when the changed key is outside the configured allow-list' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['custom_attribute_updated'],
                               conversation_custom_attribute_keys: ['other_field'])

      expect(AgentBots::WebhookJob).not_to receive(:perform_later)
      listener.conversation_updated(event)
    end

    it 'does not send the webhook when custom_attribute_updated is not enabled and the general category is off' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['message_created'])

      expect(AgentBots::WebhookJob).not_to receive(:perform_later)
      listener.conversation_updated(event)
    end
  end

  describe '#contact_updated' do
    let(:event_name) { 'contact.updated' }
    let(:contact) { conversation.contact }

    context 'when custom_attributes changed' do
      let(:changed_attributes) { { 'custom_attributes' => [{}, { 'plan' => 'pro' }] } }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, contact: contact, changed_attributes: changed_attributes) }

      it 'sends the webhook when custom_attribute_updated is enabled and the key is allowed' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['custom_attribute_updated'],
                                 contact_custom_attribute_keys: ['all'])

        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url, hash_including(event: 'contact_updated'), :agent_bot_webhook,
          hash_including(secret: agent_bot.secret)
        ).once
        listener.contact_updated(event)
      end

      it 'does not send the webhook when the changed key is outside the configured allow-list' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['custom_attribute_updated'],
                                 contact_custom_attribute_keys: ['other_field'])

        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.contact_updated(event)
      end

      it 'does not send the webhook when custom_attribute_updated category is disabled' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['message_created'])

        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.contact_updated(event)
      end
    end

    context 'when an unrelated attribute changed' do
      let(:changed_attributes) { { 'name' => %w[Old New] } }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, contact: contact, changed_attributes: changed_attributes) }

      it 'does not send the webhook even when custom_attribute_updated is enabled' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot, event_names: ['custom_attribute_updated'],
                                 contact_custom_attribute_keys: ['all'])

        expect(AgentBots::WebhookJob).not_to receive(:perform_later)
        listener.contact_updated(event)
      end
    end
  end

  describe '#conversation_resolved' do
    let(:event_name) { 'conversation.resolved' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    context 'when agent bot is configured' do
      it 'sends account details in the conversation payload' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        expect(AgentBots::WebhookJob).to receive(:perform_later).with(
          agent_bot.outgoing_url,
          hash_including(event: 'conversation_resolved', account: account.webhook_data),
          :agent_bot_webhook,
          hash_including(secret: agent_bot.secret)
        ).once
        listener.conversation_resolved(event)
      end
    end
  end

  describe '#webwidget_triggered' do
    let(:event_name) { 'webwidget.triggered' }

    context 'when agent bot is configured' do
      it 'send message to agent bot URL' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

        event = double
        allow(event).to receive(:data)
          .and_return(
            {
              contact_inbox: conversation.contact_inbox,
              event_info: { country: 'US' }
            }
          )
        expect(AgentBots::WebhookJob).to receive(:perform_later)
          .with(
            agent_bot.outgoing_url,
            conversation.contact_inbox.webhook_data.merge(event: 'webwidget_triggered', event_info: { country: 'US' }),
            :agent_bot_webhook, secret: agent_bot.secret, delivery_id: instance_of(String)
          ).once

        listener.webwidget_triggered(event)
      end
    end
  end

  describe 'group conversations' do
    let!(:channel) do
      create(:channel_whatsapp, account: account, provider: 'evolution_go',
                                provider_config: { 'instance_token' => 'token', 'instance_id' => 'id',
                                                   'groups_enabled' => true },
                                sync_templates: false, validate_provider_config: false,
                                provider_instance_callbacks: false)
    end
    let(:group_contact) do
      create(:contact, account: account, identifier: '120363111122223333@g.us', phone_number: nil)
    end
    let(:group_contact_inbox) do
      create(:contact_inbox, contact: group_contact, inbox: channel.inbox, source_id: '120363111122223333@g.us')
    end
    let(:group_conversation) do
      create(:conversation, account: account, inbox: channel.inbox, contact: group_contact,
                            contact_inbox: group_contact_inbox)
    end
    let(:group_message) do
      create(:message, message_type: 'incoming', account: account, inbox: channel.inbox,
                       conversation: group_conversation)
    end
    let(:event) { Events::Base.new('message.created', Time.zone.now, message: group_message) }

    before do
      create(:agent_bot_inbox, inbox: channel.inbox, agent_bot: agent_bot)
      # Creating the message already dispatches the listener, so it has to happen before the
      # expectations or every count would be off by one.
      group_message
    end

    it 'keeps the bot out of a group, so it does not answer every participant' do
      expect(AgentBots::WebhookJob).not_to receive(:perform_later)

      listener.message_created(event)
    end

    it 'lets the bot in once the inbox opts in' do
      channel.merge_provider_config!('bot_in_groups' => true)

      expect(AgentBots::WebhookJob).to receive(:perform_later).once

      listener.message_created(event)
    end

    it 'still reaches the bot on a one to one conversation of the same inbox' do
      direct_contact = create(:contact, account: account, phone_number: '+5511988887777')
      direct_contact_inbox = create(:contact_inbox, contact: direct_contact, inbox: channel.inbox,
                                                    source_id: '5511988887777')
      direct_conversation = create(:conversation, account: account, inbox: channel.inbox,
                                                  contact: direct_contact, contact_inbox: direct_contact_inbox)
      direct_message = create(:message, message_type: 'incoming', account: account,
                                        inbox: channel.inbox, conversation: direct_conversation)

      expect(AgentBots::WebhookJob).to receive(:perform_later).once

      listener.message_created(Events::Base.new('message.created', Time.zone.now, message: direct_message))
    end
  end
end
