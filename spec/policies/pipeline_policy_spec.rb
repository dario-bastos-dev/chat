# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PipelinePolicy, type: :policy do
  subject(:pipeline_policy) { described_class }

  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }

  let(:administrator) { create(:user) }
  let(:agent) { create(:user) }

  let(:administrator_account_user) { create(:account_user, user: administrator, account: account, role: :administrator) }
  let(:agent_account_user) { create(:account_user, user: agent, account: account, role: :agent) }

  let(:administrator_context) { { user: administrator, account: account, account_user: administrator_account_user } }
  let(:agent_context) { { user: agent, account: account, account_user: agent_account_user } }

  let!(:public_pipeline) { create(:pipeline, account: account) }
  let!(:allowed_pipeline) { create(:pipeline, :restricted, account: account, allowed_team_ids: [team.id]) }
  let!(:forbidden_pipeline) { create(:pipeline, :restricted, account: account, allowed_team_ids: [other_team.id]) }

  before { create(:team_member, team: team, user: agent) }

  permissions :create?, :update?, :destroy? do
    it { expect(pipeline_policy).to permit(administrator_context, public_pipeline) }
    it { expect(pipeline_policy).not_to permit(agent_context, public_pipeline) }
  end

  describe 'Scope' do
    it 'returns every pipeline for administrators' do
      resolved = described_class::Scope.new(administrator_context, Pipeline).resolve
      expect(resolved).to contain_exactly(public_pipeline, allowed_pipeline, forbidden_pipeline)
    end

    it 'hides restricted pipelines the agent teams are not allowed into' do
      resolved = described_class::Scope.new(agent_context, Pipeline).resolve
      expect(resolved).to contain_exactly(public_pipeline, allowed_pipeline)
    end

    it 'returns only public pipelines when the agent has no team' do
      teamless = create(:user)
      teamless_account_user = create(:account_user, user: teamless, account: account, role: :agent)
      context = { user: teamless, account: account, account_user: teamless_account_user }

      resolved = described_class::Scope.new(context, Pipeline).resolve
      expect(resolved).to contain_exactly(public_pipeline)
    end
  end
end
