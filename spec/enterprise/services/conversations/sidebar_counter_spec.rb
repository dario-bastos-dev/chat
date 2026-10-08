require 'rails_helper'

RSpec.describe Conversations::SidebarCounter do
  subject(:counts) { described_class.new(account: account, user: agent).perform }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    custom_role = create(:custom_role, account: account, permissions: permissions)
    agent.account_users.find_by(account: account).update!(custom_role: custom_role)
  end

  context 'with conversation_participating_manage permission' do
    let(:permissions) { %w[conversation_participating_manage] }

    it 'counts only assigned and participating conversations' do
      create(:conversation, account: account, inbox: inbox, assignee: agent)
      participating = create(:conversation, account: account, inbox: inbox)
      create(:conversation_participant, account: account, conversation: participating, user: agent)
      hidden = create(:conversation, account: account, inbox: inbox)
      create(:mention, account: account, conversation: hidden, user: agent)

      expect(counts).to eq(all_count: 2, mentions_count: 0, participating_count: 1, unattended_count: 2)
    end
  end

  context 'with conversation_team_manage permission' do
    let(:permissions) { %w[conversation_team_manage] }
    let(:team) { create(:team, account: account) }
    let(:teammate) { create(:user, account: account, role: :agent) }

    before do
      create(:team_member, team: team, user: agent)
      create(:team_member, team: team, user: teammate)
      create(:inbox_member, user: teammate, inbox: inbox)
    end

    it 'counts team, unassigned and own conversations' do
      create(:conversation, account: account, inbox: inbox, team: team, assignee: teammate)
      create(:conversation, account: account, inbox: inbox)
      create(:conversation, account: account, inbox: inbox, assignee: teammate)

      expect(counts).to include(all_count: 2, unattended_count: 2)
    end
  end

  context 'without conversation permissions' do
    let(:permissions) { %w[contact_manage] }

    it 'returns zero counts' do
      create(:conversation, account: account, inbox: inbox)

      expect(counts).to eq(all_count: 0, mentions_count: 0, participating_count: 0, unattended_count: 0)
    end
  end
end
