# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Deals::StageAutomationJob do
  let(:account) { create(:account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:stages) { pipeline.stages.ordered.to_a }
  let(:contact) { create(:contact, account: account) }
  let(:deal) do
    create(:deal, account: account, pipeline: pipeline, stage: stages.first, contact: contact)
  end

  describe 'deal.stage_changed' do
    # win_probability voltou a ser apenas metrica de forecast; quem decide
    # ganho/perda e o stage_type.
    it 'does not win a deal just because the stage has 100% probability' do
      certain_stage = create(:stage, pipeline: pipeline, stage_type: 'active',
                                     position: 9, win_probability: 100)

      described_class.perform_now('deal.stage_changed',
                                  { 'deal_id' => deal.id,
                                    'from_stage_id' => stages.first.id,
                                    'to_stage_id' => certain_stage.id })

      expect(deal.reload.status).to eq('open')
    end

    it 'logs an activity for the move' do
      expect do
        described_class.perform_now('deal.stage_changed',
                                    { 'deal_id' => deal.id,
                                      'from_stage_id' => stages.first.id,
                                      'to_stage_id' => stages.second.id })
      end.to change { deal.deal_activities.count }.by(1)
    end

    it 'does nothing when the deal no longer exists' do
      expect do
        described_class.perform_now('deal.stage_changed',
                                    { 'deal_id' => 0, 'to_stage_id' => stages.second.id })
      end.not_to raise_error
    end
  end

  describe 'conversation.tagged' do
    it 'does not create a second deal when the contact already has an open one' do
      deal
      conversation = create(:conversation, account: account, contact: contact)

      expect do
        described_class.perform_now('conversation.tagged',
                                    { 'conversation_id' => conversation.id, 'tag' => 'venda' })
      end.not_to(change { account.deals.count })
    end
  end
end
