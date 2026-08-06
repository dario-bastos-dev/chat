# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enterprise::DealPolicy', type: :policy do
  subject(:deal_policy) { DealPolicy }

  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:stage) { create(:stage, pipeline: pipeline) }

  let(:agent) { create(:user) }
  let(:teammate) { create(:user) }
  let(:stranger) { create(:user) }

  let(:team) { create(:team, account: account) }

  let(:own_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: agent) }
  let(:unassigned_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: nil) }
  let(:teammate_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: teammate) }
  let(:stranger_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: stranger) }

  def context_for(permissions)
    custom_role = create(:custom_role, account: account, permissions: permissions)
    account_user = create(:account_user, user: agent, account: account, role: :agent, custom_role: custom_role)
    { user: agent, account: account, account_user: account_user }
  end

  before do
    create(:account_user, user: teammate, account: account, role: :agent)
    create(:account_user, user: stranger, account: account, role: :agent)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: teammate)
  end

  describe 'deal_manage' do
    let(:agent_context) { context_for(['deal_manage']) }

    permissions :show?, :update?, :move?, :destroy?, :assign? do
      it { expect(deal_policy).to permit(agent_context, stranger_deal) }
    end

    it 'scopes to every deal in the account' do
      [own_deal, unassigned_deal, teammate_deal, stranger_deal]
      resolved = DealPolicy::Scope.new(agent_context, Deal).resolve
      expect(resolved).to contain_exactly(own_deal, unassigned_deal, teammate_deal, stranger_deal)
    end
  end

  describe 'deal_team_manage' do
    let(:agent_context) { context_for(['deal_team_manage']) }

    permissions :show?, :update? do
      it { expect(deal_policy).to permit(agent_context, own_deal) }
      it { expect(deal_policy).to permit(agent_context, unassigned_deal) }
      it { expect(deal_policy).to permit(agent_context, teammate_deal) }
      it { expect(deal_policy).not_to permit(agent_context, stranger_deal) }
    end

    permissions :destroy? do
      it { expect(deal_policy).not_to permit(agent_context, own_deal) }
    end

    it 'scopes to own, unassigned and teammates deals' do
      [own_deal, unassigned_deal, teammate_deal, stranger_deal]
      resolved = DealPolicy::Scope.new(agent_context, Deal).resolve
      expect(resolved).to contain_exactly(own_deal, unassigned_deal, teammate_deal)
    end
  end

  describe 'deal_unassigned_manage' do
    let(:agent_context) { context_for(['deal_unassigned_manage']) }

    permissions :show?, :update? do
      it { expect(deal_policy).to permit(agent_context, own_deal) }
      it { expect(deal_policy).to permit(agent_context, unassigned_deal) }
      it { expect(deal_policy).not_to permit(agent_context, teammate_deal) }
    end

    it 'scopes to own and unassigned deals' do
      [own_deal, unassigned_deal, teammate_deal]
      resolved = DealPolicy::Scope.new(agent_context, Deal).resolve
      expect(resolved).to contain_exactly(own_deal, unassigned_deal)
    end
  end

  describe 'deal_own_manage' do
    let(:agent_context) { context_for(['deal_own_manage']) }

    permissions :show?, :update? do
      it { expect(deal_policy).to permit(agent_context, own_deal) }
      it { expect(deal_policy).not_to permit(agent_context, unassigned_deal) }
      it { expect(deal_policy).not_to permit(agent_context, teammate_deal) }
    end

    it 'scopes to own deals only' do
      [own_deal, unassigned_deal, teammate_deal]
      resolved = DealPolicy::Scope.new(agent_context, Deal).resolve
      expect(resolved).to contain_exactly(own_deal)
    end
  end

  describe 'a custom role without any deal permission' do
    let(:agent_context) { context_for(['contact_manage']) }

    permissions :show?, :update? do
      it { expect(deal_policy).not_to permit(agent_context, own_deal) }
      it { expect(deal_policy).not_to permit(agent_context, unassigned_deal) }
    end

    it 'scopes to nothing' do
      [own_deal, unassigned_deal]
      resolved = DealPolicy::Scope.new(agent_context, Deal).resolve
      expect(resolved).to be_empty
    end
  end
end
