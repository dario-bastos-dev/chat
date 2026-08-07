# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DealPolicy, type: :policy do
  subject(:deal_policy) { described_class }

  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, account: account) }
  let(:stage) { create(:stage, pipeline: pipeline) }

  let(:administrator) { create(:user) }
  let(:agent) { create(:user) }
  let(:other_agent) { create(:user) }

  let(:administrator_account_user) { create(:account_user, user: administrator, account: account, role: :administrator) }
  let(:agent_account_user) { create(:account_user, user: agent, account: account, role: :agent) }

  let(:administrator_context) { { user: administrator, account: account, account_user: administrator_account_user } }
  let(:agent_context) { { user: agent, account: account, account_user: agent_account_user } }

  let(:own_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: agent) }
  let(:unassigned_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: nil) }
  let(:other_deal) { create(:deal, account: account, pipeline: pipeline, stage: stage, assignee: other_agent) }

  permissions :update?, :move?, :win?, :lose? do
    it { expect(deal_policy).to permit(administrator_context, other_deal) }
    it { expect(deal_policy).to permit(agent_context, own_deal) }
    it { expect(deal_policy).to permit(agent_context, unassigned_deal) }
    it { expect(deal_policy).not_to permit(agent_context, other_deal) }
  end

  permissions :destroy?, :assign? do
    it { expect(deal_policy).to permit(administrator_context, other_deal) }
    it { expect(deal_policy).not_to permit(agent_context, own_deal) }
    it { expect(deal_policy).not_to permit(agent_context, unassigned_deal) }
  end

  permissions :show? do
    it { expect(deal_policy).to permit(administrator_context, other_deal) }
    it { expect(deal_policy).to permit(agent_context, own_deal) }
    it { expect(deal_policy).to permit(agent_context, unassigned_deal) }
    it { expect(deal_policy).not_to permit(agent_context, other_deal) }
  end

  describe 'Scope' do
    before { [own_deal, unassigned_deal, other_deal] }

    it 'returns every deal of the account for administrators' do
      resolved = described_class::Scope.new(administrator_context, Deal).resolve
      expect(resolved).to contain_exactly(own_deal, unassigned_deal, other_deal)
    end

    it 'returns own and unassigned deals for agents' do
      resolved = described_class::Scope.new(agent_context, Deal).resolve
      expect(resolved).to contain_exactly(own_deal, unassigned_deal)
    end

    it 'never leaks deals from another account' do
      other_account_deal = create(:deal)
      resolved = described_class::Scope.new(administrator_context, Deal).resolve
      expect(resolved).not_to include(other_account_deal)
    end
  end
end
