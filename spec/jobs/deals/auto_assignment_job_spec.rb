# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Deals::AutoAssignmentJob do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stage) { pipeline.stages.ordered.first }
  let(:contact) { create(:contact, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  let(:idle_agent) { create(:user, account: account) }
  let(:busy_agent) { create(:user, account: account) }
  # Sem nenhum negocio: seria o escolhido se a conta inteira entrasse no sorteio.
  let(:outsider) { create(:user, account: account) }

  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, team: team) }
  let(:deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: nil) }

  before do
    outsider
    create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: busy_agent)
  end

  context 'when the deal has a conversation with a team' do
    before do
      [idle_agent, busy_agent].each { |user| create(:team_member, team: team, user: user) }
      create(:conversation_deal, conversation: conversation, deal: deal, is_primary: true)
    end

    it 'assigns the team member with the lightest open pipeline' do
      described_class.perform_now(deal.id)

      expect(deal.reload.assignee).to eq(idle_agent)
    end

    it 'ignores deals from other accounts when measuring workload' do
      other_account = create(:account)
      other_pipeline = create(:pipeline, :with_stages, account: other_account)
      create(:account_user, user: idle_agent, account: other_account, role: :agent)
      3.times do
        create(:deal, account: other_account, pipeline: other_pipeline,
                      stage: other_pipeline.stages.ordered.first,
                      contact: create(:contact, account: other_account), assignee: idle_agent)
      end

      described_class.perform_now(deal.id)

      expect(deal.reload.assignee).to eq(idle_agent)
    end

    it 'records an activity for the assignment' do
      expect { described_class.perform_now(deal.id) }
        .to change { deal.deal_activities.count }.by(1)
    end
  end

  it 'falls back to the conversation inbox members when the conversation has no team' do
    conversation.update!(team: nil)
    [idle_agent, busy_agent].each { |user| create(:inbox_member, inbox: inbox, user: user) }
    create(:conversation_deal, conversation: conversation, deal: deal, is_primary: true)

    described_class.perform_now(deal.id)

    expect(deal.reload.assignee).to eq(idle_agent)
  end

  it 'uses the deal inbox members when the deal has no conversation' do
    [idle_agent, busy_agent].each { |user| create(:inbox_member, inbox: inbox, user: user) }
    deal.update!(inbox: inbox)

    described_class.perform_now(deal.id)

    expect(deal.reload.assignee).to eq(idle_agent)
  end

  it 'leaves the deal unassigned when it has neither a conversation nor an inbox' do
    described_class.perform_now(deal.id)

    expect(deal.reload.assignee).to be_nil
  end

  it 'leaves an already assigned deal untouched' do
    deal.update!(assignee: busy_agent)

    expect { described_class.perform_now(deal.id) }.not_to(change { deal.reload.assignee_id })
  end
end
