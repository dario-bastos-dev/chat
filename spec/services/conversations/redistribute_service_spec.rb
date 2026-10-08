require 'rails_helper'

RSpec.describe Conversations::RedistributeService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:leaving) { create(:user, account: account, role: :agent, name: 'Leaving') }
  let(:agent_b) { create(:user, account: account, role: :agent, name: 'B') }
  let(:agent_c) { create(:user, account: account, role: :agent, name: 'C') }
  let(:outsider) { create(:user, account: account, role: :agent, name: 'Outsider') }
  let(:team) { create(:team, account: account) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:stage) { create(:stage, pipeline: pipeline) }
  let(:contact) { create(:contact, account: account) }
  let(:other_contact) { create(:contact, account: account) }

  before do
    [leaving, agent_b, agent_c, outsider].each { |user| create(:inbox_member, inbox: inbox, user: user) }
    [leaving, agent_b, agent_c].each { |user| create(:team_member, team: team, user: user) }
  end

  def perform(conversations, team: nil, include_deals: false)
    described_class.new(
      account: account,
      conversations: account.conversations.where(id: conversations.map(&:id)),
      team: team,
      include_deals: include_deals
    ).perform
  end

  it 'takes every conversation away from its current assignee and spreads them by open load' do
    conversations = create_list(:conversation, 4, account: account, inbox: inbox, assignee: leaving, team: team)

    perform(conversations, team: team)

    assignees = conversations.map { |conversation| conversation.reload.assignee_id }
    expect(assignees).not_to include(leaving.id)
    expect(assignees.tally).to eq(agent_b.id => 2, agent_c.id => 2)
  end

  it 'never gives a conversation back to its current assignee, even when they have the lowest load' do
    create_list(:conversation, 2, account: account, inbox: inbox, assignee: agent_b, status: :open)
    create_list(:conversation, 2, account: account, inbox: inbox, assignee: agent_c, status: :open)
    conversation = create(:conversation, account: account, inbox: inbox, assignee: leaving, team: team)

    perform([conversation], team: team)

    expect(conversation.reload.assignee_id).to be_in([agent_b.id, agent_c.id])
  end

  it 'never hands a conversation to anyone whose conversations are being redistributed' do
    [agent_c, outsider].each { |busy| create_list(:conversation, 2, account: account, inbox: inbox, assignee: busy, status: :open) }
    from_leaving = create(:conversation, account: account, inbox: inbox, assignee: leaving)
    from_b = create(:conversation, account: account, inbox: inbox, assignee: agent_b)

    perform([from_leaving, from_b])

    expect([from_leaving.reload.assignee_id, from_b.reload.assignee_id]).to all(be_in([agent_c.id, outsider.id]))
  end

  it 'only hands conversations to members of the chosen team and moves them into it' do
    other_team = create(:team, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, team: other_team)
    conversation.update_columns(assignee_id: leaving.id)

    perform([conversation], team: team)

    expect(conversation.reload.assignee_id).to be_in([agent_b.id, agent_c.id])
    expect(conversation.team_id).to eq(team.id)
  end

  it 'falls back to every inbox member when no team is given' do
    create(:conversation, account: account, inbox: inbox, assignee: agent_b, status: :open)
    create(:conversation, account: account, inbox: inbox, assignee: agent_c, status: :open)
    conversation = create(:conversation, account: account, inbox: inbox, assignee: leaving)

    perform([conversation])

    expect(conversation.reload.assignee_id).to eq(outsider.id)
  end

  it 'leaves a conversation alone when nobody else can take it' do
    lonely_inbox = create(:inbox, account: account)
    create(:inbox_member, inbox: lonely_inbox, user: leaving)
    conversation = create(:conversation, account: account, inbox: lonely_inbox, assignee: leaving)

    perform([conversation], team: team)

    expect(conversation.reload.assignee_id).to eq(leaving.id)
  end

  it 'keeps conversations of the same contact with the same agent' do
    first = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: leaving)
    second = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: leaving)

    perform([first, second], team: team)

    expect(second.reload.assignee_id).to eq(first.reload.assignee_id)
  end

  context 'when deals are included' do
    let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, assignee: leaving) }

    def link(deal, *conversations)
      conversations.each { |linked| ConversationDeal.find_or_create_by!(conversation: linked, deal: deal) }
      deal
    end

    it 'moves the open deal to the same agent who received the conversation and logs it' do
      deal = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: leaving), conversation)

      perform([conversation], team: team, include_deals: true)

      expect(deal.reload.assignee_id).to eq(conversation.reload.assignee_id)
      expect(deal.deal_activities.last.description).to include(conversation.assignee.name, "##{conversation.display_id}")
    end

    it 'moves an unassigned open deal along with the conversation' do
      deal = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact), conversation)
      deal.update_column(:assignee_id, nil)

      perform([conversation], team: team, include_deals: true)

      expect(deal.reload.assignee_id).to eq(conversation.reload.assignee_id)
    end

    it 'does not touch a deal owned by another salesperson or a closed deal' do
      foreign = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: outsider), conversation)
      won = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: leaving), conversation)
      won.update_columns(status: 'won')

      perform([conversation], team: team, include_deals: true)

      expect(foreign.reload.assignee_id).to eq(outsider.id)
      expect(won.reload.assignee_id).to eq(leaving.id)
    end

    it 'gives conversations of different contacts sharing a deal to the same agent' do
      other_conversation = create(:conversation, account: account, inbox: inbox, contact: other_contact, assignee: leaving)
      deal = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: leaving),
                  conversation, other_conversation)

      perform([conversation, other_conversation], team: team, include_deals: true)

      expect(other_conversation.reload.assignee_id).to eq(conversation.reload.assignee_id)
      expect(deal.reload.assignee_id).to eq(conversation.assignee_id)
    end

    it 'keeps the deal with its conversations when the selection mixes assignees' do
      [agent_c, outsider].each { |busy| create_list(:conversation, 2, account: account, inbox: inbox, assignee: busy, status: :open) }
      teammate_conversation = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: agent_b)
      deal = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: leaving),
                  conversation, teammate_conversation)

      perform([conversation, teammate_conversation], include_deals: true)

      assignees = [conversation.reload.assignee_id, teammate_conversation.reload.assignee_id, deal.reload.assignee_id]
      expect(assignees.uniq.size).to eq(1)
      expect(assignees.first).not_to be_in([leaving.id, agent_b.id])
    end

    it 'keeps deals where they are when the option is off' do
      deal = link(create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: leaving), conversation)

      perform([conversation], team: team)

      expect(conversation.reload.assignee_id).not_to eq(leaving.id)
      expect(deal.reload.assignee_id).to eq(leaving.id)
    end
  end
end
