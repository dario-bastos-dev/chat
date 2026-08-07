# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Deals::AutoAssignmentJob do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stage) { pipeline.stages.ordered.first }
  let(:contact) { create(:contact, account: account) }

  let(:idle_agent) { create(:user) }
  let(:busy_agent) { create(:user) }

  before do
    create(:account_user, user: idle_agent, account: account, role: :agent)
    create(:account_user, user: busy_agent, account: account, role: :agent)
  end

  def unassigned_deal
    create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: nil)
  end

  it 'assigns the agent with the lightest open pipeline' do
    create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: busy_agent)
    deal = unassigned_deal

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
    create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: busy_agent)

    deal = unassigned_deal
    described_class.perform_now(deal.id)

    expect(deal.reload.assignee).to eq(idle_agent)
  end

  it 'leaves an already assigned deal untouched' do
    deal = create(:deal, account: account, pipeline: pipeline, stage: stage, contact: contact, assignee: busy_agent)

    expect { described_class.perform_now(deal.id) }.not_to(change { deal.reload.assignee_id })
  end

  it 'records an activity for the assignment' do
    deal = unassigned_deal

    expect { described_class.perform_now(deal.id) }
      .to change { deal.deal_activities.count }.by(1)
  end
end
