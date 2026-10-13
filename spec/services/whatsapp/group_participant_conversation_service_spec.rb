require 'rails_helper'

describe Whatsapp::GroupParticipantConversationService do
  subject(:service) { described_class.new(group_conversation: group_conversation, participant_jid: participant_jid, user: agent) }

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Ana') }
  let(:team) { create(:team, account: account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'evolution_go', phone_number: '+5511900000000',
                              provider_config: { 'instance_token' => 'token', 'instance_id' => 'id' },
                              sync_templates: false, validate_provider_config: false,
                              provider_instance_callbacks: false)
  end
  let(:inbox) { channel.inbox }
  let(:group_contact) do
    create(:contact, account: account, name: 'Equipe Vendas', identifier: '120363111122223333@g.us', phone_number: nil)
  end
  let(:group_contact_inbox) { create(:contact_inbox, contact: group_contact, inbox: inbox, source_id: '120363111122223333@g.us') }
  let(:roster) do
    [
      { 'jid' => '5527998999017@s.whatsapp.net', 'lid' => '111222333444555@lid',
        'phone' => '5527998999017@s.whatsapp.net', 'name' => 'Alex', 'admin' => false },
      { 'jid' => '999888777666555@lid', 'lid' => '999888777666555@lid', 'phone' => nil, 'name' => nil, 'admin' => false },
      { 'jid' => '5511900000000@s.whatsapp.net', 'lid' => nil, 'phone' => '5511900000000@s.whatsapp.net',
        'name' => 'Empresa', 'admin' => true }
    ]
  end
  let(:group_conversation) do
    create(:conversation, account: account, inbox: inbox, contact: group_contact, contact_inbox: group_contact_inbox,
                          team: team, additional_attributes: { 'group_participants' => roster })
  end
  let(:participant_jid) { '5527998999017@s.whatsapp.net' }

  it 'opens a conversation with the member as a contact of the same inbox, addressed by phone' do
    conversation = service.perform

    expect(conversation.inbox).to eq(inbox)
    expect(conversation.contact).to have_attributes(name: 'Alex', phone_number: '+5527998999017',
                                                    identifier: '5527998999017@s.whatsapp.net')
    expect(conversation.contact_inbox.source_id).to eq('5527998999017')
  end

  it 'hands the conversation to the agent, in the group team, flagged with where it came from' do
    create(:team_member, team: team, user: agent)

    conversation = service.perform

    expect(conversation).to have_attributes(status: 'open', assignee: agent, team: team)
    expect(conversation.additional_attributes['origin_group']).to eq(
      'conversation_id' => group_conversation.display_id, 'name' => 'Equipe Vendas'
    )
  end

  it 'leaves the team out when the agent is not part of it, so its round robin does not take the conversation' do
    team.update!(allow_auto_assign: true)

    expect(service.perform).to have_attributes(assignee: agent, team: nil)
  end

  it 'keeps the inbox bot from taking the conversation over' do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: account))

    conversation = service.perform

    expect(conversation).to have_attributes(status: 'open', assignee_agent_bot: nil)
  end

  it 'records the opening on the group and on the new conversation' do
    conversation = perform_enqueued_jobs(only: Conversations::ActivityMessageJob) { service.perform }

    expect(group_conversation.messages.activity.last.content).to eq('Ana opened a private conversation with Alex')
    expect(conversation.messages.activity.last.content).to eq(
      'Ana opened this private conversation from the group Equipe Vendas'
    )
  end

  it 'reuses the contact already saved without the Brazilian ninth digit' do
    contact = create(:contact, account: account, phone_number: '+552798999017')

    expect(service.perform.contact).to eq(contact)
  end

  it 'lands on the open conversation the member already has, without recording anything again' do
    first = service.perform

    expect { expect(service.perform).to eq(first) }.not_to have_enqueued_job(Conversations::ActivityMessageJob)
  end

  it 'starts a new conversation when the previous one was resolved' do
    first = service.perform
    first.resolved!

    expect(service.perform).not_to eq(first)
  end

  context 'when the member is known only by their lid' do
    let(:participant_jid) { '999888777666555@lid' }

    it 'addresses them by the lid' do
      conversation = service.perform

      expect(conversation.contact_inbox.source_id).to eq('999888777666555')
      expect(conversation.contact).to have_attributes(name: '999888777666555', phone_number: nil,
                                                      identifier: '999888777666555@lid')
    end

    it 'uses the phone the lid was already mapped to' do
      contact = create(:contact, account: account, phone_number: '+5521977776666')
      Channel::WhatsappLidMapping.create!(account: account, inbox: inbox, contact: contact,
                                          lid: '999888777666555', phone_number: '5521977776666')

      conversation = service.perform

      expect(conversation.contact).to eq(contact)
      expect(conversation.contact_inbox.source_id).to eq('5521977776666')
    end
  end

  context 'when the group has not reported its roster' do
    let(:roster) { [] }
    let(:participant_jid) { '5531955554444@s.whatsapp.net' }

    it 'finds the member among those who spoke in the group' do
      create(:message, conversation: group_conversation, account: account, inbox: inbox, message_type: :incoming,
                       content_attributes: { group_participant: { name: 'Bia', phone: '+5531955554444',
                                                                  jid: '5531955554444@s.whatsapp.net' } })

      expect(service.perform.contact).to have_attributes(name: 'Bia', phone_number: '+5531955554444')
    end
  end

  it 'refuses someone who is not in the group' do
    service = described_class.new(group_conversation: group_conversation, participant_jid: '5599911112222@s.whatsapp.net',
                                  user: agent)

    expect { service.perform }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'refuses the business number itself' do
    service = described_class.new(group_conversation: group_conversation, participant_jid: '5511900000000@s.whatsapp.net',
                                  user: agent)

    expect { service.perform }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'refuses a conversation that is not a group' do
    direct = create(:conversation, account: account, inbox: inbox)
    service = described_class.new(group_conversation: direct, participant_jid: participant_jid, user: agent)

    expect { service.perform }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
