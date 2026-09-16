# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CannedResponsePolicy, type: :policy do
  subject(:canned_response_policy) { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, :administrator, account: account) }
  let(:author) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:team) { create(:team, account: account) }

  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:author_context) { { user: author, account: account, account_user: author.account_users.find_by(account: account) } }
  let(:other_agent_context) { { user: other_agent, account: account, account_user: other_agent.account_users.find_by(account: account) } }

  permissions :index?, :create? do
    it 'allows any authenticated account user' do
      record = build(:canned_response, account: account)

      expect(canned_response_policy).to permit(administrator_context, record)
      expect(canned_response_policy).to permit(author_context, record)
    end
  end

  permissions :update?, :destroy? do
    let(:record) { create(:canned_response, account: account, created_by_id: author.id, visibility: :global) }

    it 'permits the author' do
      expect(canned_response_policy).to permit(author_context, record)
    end

    it 'permits an administrator' do
      expect(canned_response_policy).to permit(administrator_context, record)
    end

    it 'does not permit another agent, even for a globally visible record' do
      expect(canned_response_policy).not_to permit(other_agent_context, record)
    end
  end

  describe 'show?' do
    it 'permits everyone for a global record' do
      record = create(:canned_response, account: account, visibility: :global)

      expect(canned_response_policy).to permit(other_agent_context, record)
    end

    it 'permits only the author for a personal record' do
      record = create(:canned_response, account: account, visibility: :personal, created_by_id: author.id)

      expect(canned_response_policy).to permit(author_context, record)
      expect(canned_response_policy).not_to permit(other_agent_context, record)
      expect(canned_response_policy).to permit(administrator_context, record)
    end

    it 'permits only team members for a team-restricted record' do
      create(:team_member, team: team, user: other_agent)
      record = create(:canned_response, account: account, visibility: :team_visibility, team: team)

      expect(canned_response_policy).to permit(other_agent_context, record)
      expect(canned_response_policy).not_to permit(author_context, record)
      expect(canned_response_policy).to permit(administrator_context, record)
    end
  end
end
